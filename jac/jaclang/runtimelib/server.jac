"""REST API Server for Jac Programs."""
import hashlib;
import html;
import inspect;
import json;
import os;
import secrets;
import from collections.abc { Callable }
import from contextlib { suppress }
import from dataclasses { dataclass, field }
import from http.server { BaseHTTPRequestHandler, HTTPServer }
import from pathlib { Path }
import from typing { TYPE_CHECKING, Any, Literal, TypeAlias, get_type_hints }
import from urllib.parse { parse_qs, urlparse }
import from jaclang.runtimelib.client_bundle { ClientBundleError }
import from jaclang { JacRuntime as Jac }

with entry {
    if TYPE_CHECKING {
        import from jaclang.runtimelib.constructs { Archetype, WalkerArchetype }
    }
}

glob
    JsonValue: TypeAlias = None | str | int | float | bool | <>list['JsonValue'] | <>dict[
        (str, 'JsonValue')
    ],
    StatusCode: TypeAlias = Literal[(200, 201, 400, 401, 404, 500, 503)];

"""Base response container."""
@dataclass(frozen=True, slots=True)
class Response {
    with entry {
        status: StatusCode;
        body: JsonValue;
        content_type: str = 'application/json';
    }
}

"""User authentication data."""
@dataclass(frozen=True, slots=True)
class UserData {
    with entry {
        username: str;
        token: str;
        root_id: str;
    }
}

"""Type-safe serializer for Jac objects."""
class JacSerializer {
    static def serialize(<>obj: object) -> JsonValue;
    static def _serialize_archetype(arch: Archetype) -> dict[str, JsonValue];
}

"""Manage users and their persistent roots."""
@dataclass(slots=True)
class UserManager {
    with entry {
        session_path: str;
        _users: dict[(str, dict[(str, str)])] = field(
            default_factory=<>dict, <>init=False
        );
        _tokens: dict[(str, str)] = field(default_factory=<>dict, <>init=False);
        _db_path: str = field(<>init=False);
    }

    def postinit(self: UserManager) -> None;
    def _load_db(self: UserManager) -> None;
    def _persist(self: UserManager) -> None;
    def create_user(self: UserManager, username: str, password: str) -> dict[str, str];
    def authenticate(
        self: UserManager, username: str, password: str
    ) -> (dict[(str, str)] | None);

    def validate_token(self: UserManager, token: str) -> (str | None);
    def get_root_id(self: UserManager, username: str) -> (str | None);
    def close(self: UserManager) -> None;
}

"""Manages execution contexts for user operations."""
class ExecutionManager {
    def init(
        self: ExecutionManager, session_path: str, user_manager: UserManager
    ) -> None;

    def execute_function(
        self: ExecutionManager,
        func: Callable[(..., Any)],
        args: dict[(str, Any)],
        username: str
    ) -> dict[str, JsonValue];

    def spawn_walker(
        self: ExecutionManager,
        walker_cls: type[WalkerArchetype],
        fields: dict[(str, Any)],
        username: str
    ) -> dict[str, JsonValue];
}

"""Introspects and caches module metadata."""
@dataclass(slots=True)
class ModuleIntrospector {
    with entry {
        module_name: str;
        base_path: (str | None);
        _module: Any = field(<>default=None, <>init=False);
        _functions: dict[(str, Callable[(..., Any)])] = field(
            default_factory=<>dict, <>init=False
        );
        _walkers: dict[(str, type[WalkerArchetype])] = field(
            default_factory=<>dict, <>init=False
        );
        _client_functions: dict[(str, Callable[(..., Any)])] = field(
            default_factory=<>dict, <>init=False
        );
        _client_manifest: dict[(str, Any)] = field(
            default_factory=<>dict, <>init=False
        );
        _bundle: Any = field(<>default=None, <>init=False);
        _bundle_error: (str | None) = field(<>default=None, <>init=False);
        _bundle_builder: Any = field(<>default=None, <>init=False);
        _function_access: dict[(str, bool)] = field(
            default_factory=<>dict, <>init=False
        );
        _walker_access: dict[(str, bool)] = field(default_factory=<>dict, <>init=False);
    }

    def postinit(self: ModuleIntrospector) -> None;
    def load(self: ModuleIntrospector, force_reload: bool = False) -> None;
    def _load_manifest(self: ModuleIntrospector) -> None;
    def _extract_access_levels(self: ModuleIntrospector) -> None;
    def _collect_functions(self: ModuleIntrospector) -> dict[str, Callable[(..., Any)]];
    def _collect_walkers(self: ModuleIntrospector) -> dict[str, type[WalkerArchetype]];
    def get_functions(self: ModuleIntrospector) -> dict[str, Callable[(..., Any)]];
    def get_walkers(self: ModuleIntrospector) -> dict[str, type[WalkerArchetype]];
    def get_client_functions(
        self: ModuleIntrospector
    ) -> dict[str, Callable[(..., Any)]];

    def introspect_callable(
        self: ModuleIntrospector, func: Callable[(..., Any)]
    ) -> dict[str, Any];

    def introspect_walker(
        self: ModuleIntrospector, walker_cls: type[WalkerArchetype]
    ) -> dict[str, Any];

    def ensure_bundle(self: ModuleIntrospector) -> str;
    def render_page(
        self: ModuleIntrospector,
        function_name: str,
        args: dict[(str, Any)],
        username: str
    ) -> dict[str, Any];

    def is_auth_required_for_function(self: ModuleIntrospector, func_name: str) -> bool;
    def is_auth_required_for_walker(self: ModuleIntrospector, walker_name: str) -> bool;
    def _collect_client_globals(self: ModuleIntrospector) -> dict[str, Any];
}

"""Build and send HTTP responses."""
class ResponseBuilder {
    static def send_json(
        handler: BaseHTTPRequestHandler,
        status: StatusCode,
        data: dict[(str, JsonValue)]
    ) -> None;

    static def send_html(
        handler: BaseHTTPRequestHandler, status: StatusCode, body: str
    ) -> None;

    static def send_javascript(handler: BaseHTTPRequestHandler, code: str) -> None;
    static def send_css(handler: BaseHTTPRequestHandler, css: str) -> None;
    static def _add_cors_headers(handler: BaseHTTPRequestHandler) -> None;
}

"""Base route handler."""
class RouteHandler {
    def init(
        self: RouteHandler,
        introspector: ModuleIntrospector,
        execution_manager: ExecutionManager,
        user_manager: UserManager
    ) -> None;
}

"""Handle authentication routes."""
class AuthHandler(RouteHandler) {
    def create_user(self: AuthHandler, email: str, password: str) -> Response;
    def login(self: AuthHandler, email: str, password: str) -> Response;
}

"""Handle introspection routes."""
class IntrospectionHandler(RouteHandler) {
    def list_functions(self: IntrospectionHandler) -> Response;
    def list_walkers(self: IntrospectionHandler) -> Response;
    def get_function_info(self: IntrospectionHandler, name: str) -> Response;
    def get_walker_info(self: IntrospectionHandler, name: str) -> Response;
}

"""Handle execution routes."""
class ExecutionHandler(RouteHandler) {
    def call_function(
        self: ExecutionHandler, name: str, args: dict[(str, Any)], username: str
    ) -> Response;

    def spawn_walker(
        self: ExecutionHandler, name: str, fields: dict[(str, Any)], username: str
    ) -> Response;
}

"""REST API Server for Jac programs."""
class JacAPIServer {
    def init(
        self: JacAPIServer,
        module_name: str,
        session_path: str,
        port: int = 8000,
        base_path: (str | None) = None
    ) -> None;

    def create_handler(self: JacAPIServer) -> type[BaseHTTPRequestHandler];
    def load_module(self: JacAPIServer, force_reload: bool = False) -> None;
    @property
    def module(self: JacAPIServer) -> object;

    def get_functions(self: JacAPIServer) -> dict[str, Callable[(..., Any)]];
    def get_walkers(self: JacAPIServer) -> dict[str, type[WalkerArchetype]];
    def introspect_callable(
        self: JacAPIServer, func: Callable[(..., Any)]
    ) -> dict[str, Any];

    def introspect_walker(
        self: JacAPIServer, walker_cls: type[WalkerArchetype]
    ) -> dict[str, Any];

    def render_client_page(
        self: JacAPIServer, function_name: str, args: dict[(str, Any)], username: str
    ) -> dict[str, Any];

    def get_client_bundle_code(self: JacAPIServer) -> str;
    def print_endpoint_docs(self: JacAPIServer) -> None;
    def start(self: JacAPIServer) -> None;
}

"""Print comprehensive documentation for all endpoints that would be generated."""
def print_endpoint_docs(server: JacAPIServer) -> None;
