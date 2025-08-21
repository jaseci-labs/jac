"""Jaseci FastAPI."""

from contextlib import asynccontextmanager
from os import getenv
from ssl import CERT_NONE
from traceback import format_exception
from typing import Any, AsyncGenerator, TYPE_CHECKING

from anyio import create_task_group

from fastapi import FastAPI as _FaststAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import ORJSONResponse

if TYPE_CHECKING:
    from jaclang.runtimelib.machine import JacMachine


from uvicorn import run as _run
from uvicorn.config import (
    HTTPProtocolType,
    InterfaceType,
    LOGGING_CONFIG,
    LifespanType,
    LoopSetupType,
    SSL_PROTOCOL_VERSION,
    WSProtocolType,
)

from .utils import Emailer, logger, populate_yaml_specs


class FastAPI:
    """FastAPI Handler."""

    __app__ = None
    __is_enabled__: bool = False
    __jac_mach__: "JacMachine"

    @staticmethod
    def enable() -> None:
        """Tag Fastapi as enabled."""
        from jaclang.runtimelib.machine import JacMachineInterface

        FastAPI.__is_enabled__ = True
        JacMachineInterface.setup()

    @staticmethod
    def is_enabled() -> bool:
        """Check if FastAPI is already enabled."""
        return FastAPI.__is_enabled__

    @classmethod
    def get(cls) -> _FaststAPI:
        """Get or Create new instance of FastAPI."""
        if not isinstance(cls.__app__, _FaststAPI):
            from .routers import routers
            from ..plugin.implementation import (
                Routers,
                WEBSOCKET_MANAGER,
                scheduler,
                repopulate_tasks,
                websocket_router,
            )

            @asynccontextmanager
            async def lifespan(app: _FaststAPI) -> AsyncGenerator[None, _FaststAPI]:
                from .datasources import Collection

                Collection.apply_indexes()
                repopulate_tasks()
                scheduler.start()

                async with create_task_group() as task_group:
                    await WEBSOCKET_MANAGER.open_broadcaster(task_group)

                    yield

                    await WEBSOCKET_MANAGER.close_broadcaster(task_group)

                scheduler.shutdown()

            cls.__app__ = _FaststAPI(lifespan=lifespan)

            cls.__app__.add_middleware(
                CORSMiddleware,
                allow_origins=getenv("ALLOW_ORIGINS", "*").split(","),
                allow_credentials=True,
                allow_methods=getenv("ALLOW_METHODS", "*").split(","),
                allow_headers=getenv("ALLOW_HEADERS", "*").split(","),
            )

            populate_yaml_specs(cls.__app__)

            for router in [
                *routers,
                Routers.walker_router,
                websocket_router,
            ]:
                cls.__app__.include_router(router)

            @cls.__app__.exception_handler(Exception)
            async def uncatched_exception_handler(
                request: Request, exc: Exception
            ) -> ORJSONResponse:
                """Catched uncatched exceptions."""
                response = {"errors": format_exception(exc)}

                log: dict[str, Any] = {"request_url": str(request.url)}
                log["extra_fields"] = list(log.keys())
                logger.error(
                    f"Call from to {log["request_url"]} returns unexpected errors: {response["errors"]}",
                    extra=log,
                )

                return ORJSONResponse(response, status_code=500)

            Routers.main_router = cls.__app__

        return cls.__app__

    @classmethod
    def start(
        cls,
        host: str | None = None,
        port: int | None = None,
        emailer: type[Emailer] | None = None,
        **kwargs: Any,  # noqa ANN401
    ) -> None:
        """Run FastAPI Handler via Uvicorn."""
        if emailer:
            emailer.start()
        _run(
            cls.get(),
            host=host or getenv("UV_HOST") or "127.0.0.1",
            port=port or int(getenv("UV_PORT") or "8000"),
            uds=getenv("UV_UDS"),
            fd=int(v) if (v := getenv("UV_FD")) else None,
            loop=(
                v  # type: ignore[arg-type]
                if (v := getenv("UV_LOOP")) and v in LoopSetupType.__args__  # type: ignore[attr-defined]
                else "auto"
            ),
            http=(
                v  # type: ignore[arg-type]
                if (v := getenv("UV_HTTP")) and v in HTTPProtocolType.__args__  # type: ignore[attr-defined]
                else "auto"
            ),
            ws=(
                v  # type: ignore[arg-type]
                if (v := getenv("UV_WS")) and v in WSProtocolType.__args__  # type: ignore[attr-defined]
                else "auto"
            ),
            ws_max_size=int(v) if (v := getenv("UV_WS_MAX_SIZE")) else 16777216,
            ws_max_queue=int(v) if (v := getenv("UV_WS_MAX_QUEUE")) else 32,
            ws_ping_interval=float(v) if (v := getenv("UV_WS_PING_INTERVAL")) else 20.0,
            ws_ping_timeout=float(v) if (v := getenv("UV_WS_PING_TIMEOUT")) else 20.0,
            ws_per_message_deflate=getenv("UV_WS_PER_MESSAGE_DEFLATE", "true").lower()
            != "false",
            lifespan=(
                v  # type: ignore[arg-type]
                if (v := getenv("UV_LIFESPAN")) and v in LifespanType.__args__  # type: ignore[attr-defined]
                else "auto"
            ),
            interface=(
                v  # type: ignore[arg-type]
                if (v := getenv("UV_INTERFACE")) and v in InterfaceType.__args__  # type: ignore[attr-defined]
                else "auto"
            ),
            reload=getenv("UV_RELOAD", "false").lower() != "false",
            reload_dirs=(
                vl if (v := getenv("UV_RELOAD_DIRS")) and (vl := v.split(",")) else None
            ),
            reload_includes=(
                vl
                if (v := getenv("UV_RELOAD_INCLUDES")) and (vl := v.split(","))
                else None
            ),
            reload_excludes=(
                vl
                if (v := getenv("UV_RELOAD_EXCLUDES")) and (vl := v.split(","))
                else None
            ),
            reload_delay=float(v) if (v := getenv("UV_RELOAD_DELAY")) else 0.25,
            workers=int(v) if (v := getenv("UV_WORKERS")) else None,
            env_file=getenv("UV_ENV_FILE"),
            log_config=getenv("UV_LOG_CONFIG") or LOGGING_CONFIG,
            log_level=getenv("UV_LOG_LEVEL"),
            access_log=getenv("UV_ACCESS_LOG", "true").lower() != "false",
            proxy_headers=getenv("UV_PROXY_HEADERS", "true").lower() != "false",
            server_header=getenv("UV_SERVER_HEADER", "true").lower() != "false",
            date_header=getenv("UV_DATE_HEADER", "true").lower() != "false",
            forwarded_allow_ips=(
                vl
                if (v := getenv("UV_FORWARDED_ALLOW_IPS")) and (vl := v.split(","))
                else None
            ),
            root_path=v if (v := getenv("UV_ROOT_PATH")) is not None else "",
            limit_concurrency=int(v) if (v := getenv("UV_LIMIT_CONCURRENCY")) else None,
            backlog=int(v) if (v := getenv("UV_BACKLOG")) else 2048,
            limit_max_requests=(
                int(v) if (v := getenv("UV_LIMIT_MAX_REQUESTS")) else None
            ),
            timeout_keep_alive=int(v) if (v := getenv("UV_TIMEOUT_KEEP_ALIVE")) else 5,
            timeout_graceful_shutdown=(
                int(v) if (v := getenv("UV_TIMEOUT_GRACEFUL_SHUTDOWN")) else None
            ),
            ssl_keyfile=getenv("UV_SSL_KEYFILE"),
            ssl_certfile=getenv("UV_SSL_CERTFILE"),
            ssl_keyfile_password=getenv("UV_SSL_KEYFILE_PASSWORD"),
            ssl_version=(
                int(v) if (v := getenv("UV_SSL_VERSION")) else SSL_PROTOCOL_VERSION
            ),
            ssl_cert_reqs=(int(v) if (v := getenv("UV_SSL_CERT_REQS")) else CERT_NONE),
            ssl_ca_certs=getenv("UV_SSL_CA_CERTS"),
            ssl_ciphers=getenv("UV_SSL_CIPHERS") or "TLSv1",
            headers=(
                [tuple(_v.split(":", maxsplit=1)) for _v in vl if _v]  # type: ignore[misc]
                if (v := getenv("UV_HEADERS")) and (vl := v.split(","))
                else None
            ),
            use_colors=v != "false" if (v := getenv("UV_USE_COLORS")) else None,
            app_dir=getenv("UV_APP_DIR"),
            factory=getenv("UV_FACTORY", "false").lower() != "false",
            h11_max_incomplete_event_size=(
                int(v) if (v := getenv("UV_H11_MAX_INCOMPLETE_EVENT_SIZE")) else None
            ),
        )
