"""Jaseci API Implementations."""

from dataclasses import Field, MISSING, fields, is_dataclass
from enum import StrEnum
from os import getenv
from re import compile
from typing import Any, Callable, Type, cast, get_type_hints

from asyncer import syncify

from fastapi import (
    APIRouter,
    BackgroundTasks,
    Depends,
    FastAPI,
    File,
    HTTPException,
    Request,
    Response,
    UploadFile,
)
from fastapi.responses import JSONResponse, ORJSONResponse

from jaclang.runtimelib.machine import JacMachineInterface as Jac

from orjson import loads

from pydantic import BaseModel, Field as pyField, ValidationError, create_model

from starlette.datastructures import UploadFile as BaseUploadFile

from .scheduler import run_task, schedule_walker
from .websocket import websocket_events
from ...core.archetype import NodeAnchor, WalkerAnchor, WalkerArchetype
from ...core.context import ContextResponse, JaseciContext
from ...jaseci.security import authenticator, generate_webhook_auth, validate_request
from ...jaseci.utils import log_entry, log_exit

DISABLE_AUTO_ENDPOINT = getenv("DISABLE_AUTO_ENDPOINT") == "true"
REQUIRE_AUTH_BY_DEFAULT = getenv("REQUIRE_AUTH_BY_DEFAULT") != "false"
PATH_VARIABLE_REGEX = compile(r"{([^\}]+)}")
FILE_TYPES = {
    UploadFile,
    list[UploadFile],
    UploadFile | None,
    list[UploadFile] | None,
}


class Routers:
    """Router Handler."""

    main_router: FastAPI | None = None
    walker_router = APIRouter()


class EntryType(StrEnum):
    """Entry Type."""

    ROOT = "ROOT"
    NODE = "NODE"
    BOTH = "BOTH"


ROOT_ENTRIES = [EntryType.ROOT, EntryType.BOTH]
NODE_ENTRIES = [EntryType.NODE, EntryType.BOTH]


class DefaultSpecs:
    """Default API specs."""

    path: str = ""
    methods: list[str] = ["post"]
    as_query: str | list[str] = []
    excluded: str | list[str] = []
    auth: bool = REQUIRE_AUTH_BY_DEFAULT
    private: bool = False
    webhook: dict | None = None
    entry_type: EntryType = EntryType.BOTH
    response_model: Any = ContextResponse[Any]
    tags: list[str] | None = None
    status_code: int | None = None
    summary: str | None = None
    description: str | None = None
    response_description: str = "Successful Response"
    responses: dict[int | str, dict[str, Any]] | None = None
    deprecated: bool | None = None
    include_in_schema: bool = True
    response_class: type[Response] = JSONResponse
    name: str | None = None
    openapi_extra: dict[str, Any] | None = None
    schedule: dict[str, Any] | None = None


def get_specs(cls: type) -> Type["DefaultSpecs"] | None:
    """Get Specs and inherit from DefaultSpecs."""
    specs = getattr(cls, "__specs__", None)
    if specs is None:
        if DISABLE_AUTO_ENDPOINT:
            return None
        specs = DefaultSpecs

    if not issubclass(specs, DefaultSpecs):
        specs = type(specs.__name__, (specs, DefaultSpecs), {})

    return specs


def gen_model_field(cls: type, field: Field, is_file: bool = False) -> tuple[type, Any]:
    """Generate Specs for Model Field."""
    if field.default is not MISSING:
        consts = (cls, pyField(default=field.default))
    elif callable(field.default_factory):
        consts = (
            cls,
            (
                field.default_factory()
                if is_file
                else pyField(default_factory=field.default_factory)
            ),
        )
    else:
        consts = (cls, File(...) if is_file else ...)

    return consts


def populate_apis(cls: Type[WalkerArchetype]) -> None:
    """Generate FastAPI endpoint based on WalkerArchetype class."""
    if not (specs := get_specs(cls)):
        return

    if schedule := specs.schedule:
        schedule_walker(**schedule)(cls)

    if not specs.private:
        path: str = specs.path or ""
        methods: list = specs.methods or []
        as_query: str | list[str] = specs.as_query or []
        excluded: str | list[str] = specs.excluded or []
        auth: bool = specs.auth
        webhook: dict | None = specs.webhook
        entry_type: EntryType = specs.entry_type
        response_model: Any = specs.response_model
        tags: list[str] | None = specs.tags
        status_code: int | None = specs.status_code
        summary: str | None = specs.summary
        description: str | None = specs.description
        response_description: str = specs.response_description
        responses: dict[int | str, dict[str, Any]] | None = specs.responses
        deprecated: bool | None = specs.deprecated
        include_in_schema: bool = specs.include_in_schema
        response_class: type[Response] = specs.response_class
        name: str | None = specs.name
        openapi_extra: dict[str, Any] | None = specs.openapi_extra

        query: dict[str, Any] = {}
        body: dict[str, Any] = {}
        files: dict[str, Any] = {}
        message: dict[str, Any] = {}

        if webhook is None:
            target_authenticator = authenticator
            default_tags = ["Walker APIs"]
            base_path = "/walker"
        else:
            target_authenticator = generate_webhook_auth(webhook)
            default_tags = ["Webhook Walker APIs"]
            base_path = "/webhook/walker"

        if path:
            if not path.startswith("/"):
                path = f"{base_path}/{cls.__name__}/{path}"

            if isinstance(as_query, list):
                as_query += PATH_VARIABLE_REGEX.findall(path)
        else:
            path = f"{base_path}/{cls.__name__}"

        hintings = get_type_hints(cls)

        if is_dataclass(cls):
            if excluded != "*":
                if isinstance(excluded, str):
                    excluded = [excluded]

                for f in fields(cls):
                    if f.name in excluded:
                        if f.default is MISSING and not callable(f.default_factory):
                            raise AttributeError(
                                f"{cls.__name__} {f.name} should have default or default_factory."
                            )
                        continue

                    f_name = f.name
                    f_type = hintings[f_name]
                    if f_type in FILE_TYPES:
                        message[f_name] = files[f_name] = gen_model_field(
                            f_type, f, True
                        )
                    else:
                        consts = gen_model_field(f_type, f)
                        message[f_name] = consts

                        if as_query == "*" or f_name in as_query:
                            query[f_name] = consts
                        else:
                            body[f_name] = consts
            elif any(
                f.default is MISSING and not callable(f.default_factory)
                for f in fields(cls)
            ):
                raise AttributeError(
                    f"{cls.__name__} fields should all have default or default_factory."
                )

        payload: dict[str, Any] = {
            "query": (
                create_model(f"{cls.__name__.lower()}_query_model", **query),
                Depends(),
            ),
            "files": (
                create_model(f"{cls.__name__.lower()}_files_model", **files),
                Depends(),
            ),
        }

        body_model = None
        if body:
            body_model = create_model(f"{cls.__name__.lower()}_body_model", **body)

            if files:
                payload["body"] = (UploadFile, File(...))
            else:
                payload["body"] = (body_model, ...)

        payload_model = create_model(f"{cls.__name__.lower()}_request_model", **payload)

        def api_entry(
            request: Request,
            background_task: BackgroundTasks,
            node: str | None,
            payload: payload_model = Depends(),  # type: ignore # noqa: B008
        ) -> Response:
            log = log_entry(
                cls.__name__,
                user.email if (user := getattr(request, "_user", None)) else None,
                cast(BaseModel, payload).model_dump(),
                node,
            )

            query = payload.query.__dict__  # type: ignore[attr-defined]
            files = payload.files.__dict__  # type: ignore[attr-defined]

            if body := getattr(payload, "body", None):
                if isinstance(body, BaseUploadFile) and body_model:
                    body = loads(syncify(body.read)())
                    try:
                        body = body_model(**body).__dict__
                    except ValidationError as e:
                        return ORJSONResponse({"detail": e.errors()})
                else:
                    body = body.__dict__
            else:
                body = {}

            jctx = JaseciContext.create(request, NodeAnchor.ref(node) if node else None)

            validate_request(request, cls.__name__, jctx.entry_node.name or "root")

            if Jac.check_read_access(jctx.entry_node):
                warch = cls(**body, **query, **files)
                wanch: WalkerAnchor = warch.__jac__
                if warch.__jac_async__:
                    background_task.add_task(
                        run_task, wanch, jctx.root_state, jctx.entry_node
                    )
                    resp = {"walker_id": wanch.ref_id}
                    log_exit(resp, log)
                else:
                    Jac.spawn(warch, jctx.entry_node.archetype)
                    if jctx.custom is not MISSING:
                        log_exit(
                            (
                                {
                                    "response": getattr(
                                        jctx.custom,
                                        "body",
                                        jctx.custom.__class__.__name__,
                                    )
                                }
                                if isinstance(jctx.custom, Response)
                                else jctx.custom
                            ),
                            log,
                        )
                        return jctx.custom

                    resp = jctx.response()
                    log_exit(resp, log)

                jctx.close()
                return ORJSONResponse(resp, jctx.status)
            else:
                error = {
                    "error": f"You don't have access on target entry {jctx.entry_node.ref_id}!"
                }
                jctx.close()

                log_exit(error, log)
                raise HTTPException(403, error)

        def api_root(
            request: Request,
            background_task: BackgroundTasks,
            payload: payload_model = Depends(),  # type: ignore # noqa: B008
        ) -> Response:
            return api_entry(request, background_task, None, payload)

        for method in methods:
            method = method.lower()

            walker_method = getattr(
                Routers.main_router or Routers.walker_router, method
            )

            match method:
                case "websocket":
                    websocket_events[cls.__name__] = {
                        "type": cls,
                        "model": create_model(
                            f"{cls.__name__.lower()}_message_model", **message
                        ),
                        "auth": auth,
                    }
                case _:
                    settings: dict[str, Any] = {
                        "response_model": response_model,
                        "tags": default_tags if tags is None else tags,
                        "status_code": status_code,
                        "summary": summary,
                        "description": description,
                        "response_description": response_description,
                        "responses": responses,
                        "deprecated": deprecated,
                        "include_in_schema": include_in_schema,
                        "response_class": response_class,
                        "name": name,
                        "openapi_extra": openapi_extra,
                    }
                    if auth:
                        settings["dependencies"] = cast(list, target_authenticator)

                    if entry_type.upper() in ROOT_ENTRIES:
                        walker_method(f"{path}", **settings)(api_root)
                    if entry_type.upper() in NODE_ENTRIES:
                        walker_method(f"{path}/{{node}}", **settings)(api_entry)


def specs(
    cls: Type[WalkerArchetype] | None = None,
    *,
    path: str = "",
    methods: list[str] = ["post"],  # noqa: B006
    as_query: str | list[str] = [],  # noqa: B006
    excluded: str | list[str] = [],  # noqa: B006
    auth: bool = REQUIRE_AUTH_BY_DEFAULT,
    private: bool = False,
    webhook: dict | None = None,
    entry_type: EntryType = EntryType.BOTH,
    response_model: Any = ContextResponse[Any],  # noqa: ANN401
    tags: list[str] | None = None,
    status_code: int | None = None,
    summary: str | None = None,
    description: str | None = None,
    response_description: str = "Successful Response",
    responses: dict[int | str, dict[str, Any]] | None = None,
    deprecated: bool | None = None,
    include_in_schema: bool = True,
    response_class: type[Response] = Response,
    name: str | None = None,
    openapi_extra: dict[str, Any] | None = None,
    schedule: dict[str, Any] | None = None,
) -> Callable:
    """Walker Decorator."""

    def wrapper(cls: Type[WalkerArchetype]) -> Type[WalkerArchetype]:
        if get_specs(cls) is None:
            _path = path
            _methods = methods
            _as_query = as_query
            _excluded = excluded
            _auth = auth
            _private = private
            _webhook = webhook
            _entry_type = entry_type
            _response_model = response_model
            _tags = tags
            _status_code = status_code
            _summary = summary
            _description = description
            _response_description = response_description
            _responses = responses
            _deprecated = deprecated
            _include_in_schema = include_in_schema
            _response_class = response_class
            _name = name
            _openapi_extra = openapi_extra
            _schedule = schedule

            class __specs__(DefaultSpecs):  # noqa: N801
                path: str = _path
                methods: list[str] = _methods
                as_query: str | list[str] = _as_query
                excluded: str | list[str] = _excluded
                auth: bool = _auth
                private: bool = _private
                webhook: dict | None = _webhook
                entry_type: EntryType = _entry_type
                response_model: Any = _response_model
                tags: list[str] | None = _tags
                status_code: int | None = _status_code
                summary: str | None = _summary
                description: str | None = _description
                response_description: str = _response_description
                responses: dict[int | str, dict[str, Any]] | None = _responses
                deprecated: bool | None = _deprecated
                include_in_schema = _include_in_schema
                response_class = _response_class
                name: str | None = _name
                openapi_extra: dict[str, Any] | None = _openapi_extra
                schedule: dict[str, Any] | None = _schedule

            cls.__specs__ = __specs__  # type: ignore[attr-defined]

            populate_apis(cls)
        return cls

    if cls:
        return wrapper(cls)

    return wrapper
