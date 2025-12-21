"""REST API Server for Jac Programs."""
import hashlib;
import html;
import inspect;
import json;
import os;
import secrets;
import from collections.abc { Callable }
import from contextlib { suppress }
import from http.server { BaseHTTPRequestHandler, HTTPServer }
import from pathlib { Path }
import from typing { TYPE_CHECKING, Any, Literal, TypeAlias, get_type_hints }
import from urllib.parse { parse_qs, urlparse }
import from jaclang.runtimelib.client_bundle { ClientBundleError }
import from jaclang { JacRuntime as Jac }

with entry {
    if TYPE_CHECKING {
        import from jaclang.pycore.constructs { Archetype, WalkerArchetype }
    }
}

glob JsonValue: TypeAlias = None | str | int | float | bool | <>list['JsonValue'] | <>dict[
         (str, 'JsonValue')
     ],
     StatusCode: TypeAlias = Literal[(200, 201, 400, 401, 404, 500, 503)];

"""Base response container."""
obj Response {
    has status: StatusCode,
        body: JsonValue,
        content_type: str = 'application/json';
}

"""User authentication data."""
obj UserData {
    has username: str,
        token: str,
        root_id: str;
}

"""Type-safe serializer for Jac objects."""
class JacSerializer {
    static def serialize(<>obj: object) -> JsonValue;
    static def _serialize_archetype(arch: Archetype) -> dict[str, JsonValue];
}

"""Manage users and their persistent roots."""
obj UserManager {
    has session_path: str,
        _users: dict[(str, dict[(str, str)])] = {},
        _tokens: dict[(str, str)] = {},
        _db_path: str = "";

    def postinit -> None;
    def _load_db -> None;
    def _persist -> None;
    def create_user(username: str, password: str) -> dict[str, str];
    def authenticate(username: str, password: str) -> (dict[(str, str)] | None);
    def validate_token(token: str) -> (str | None);
    def get_root_id(username: str) -> (str | None);
    def get_user(username: str) -> (dict[(str, str)] | None);
    def close -> None;
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
obj ModuleIntrospector {
    has module_name: str,
        base_path: (str | None),
        _module: Any = None,
        _functions: dict[(str, Callable[(..., Any)])] = {},
        _walkers: dict[(str, type[WalkerArchetype])] = {},
        _client_functions: dict[(str, Callable[(..., Any)])] = {},
        _client_manifest: dict[(str, Any)] = {},
        _bundle: Any = None,
        _bundle_error: (str | None) = None,
        _bundle_builder: Any = None,
        _function_access: dict[(str, bool)] = {},
        _walker_access: dict[(str, bool)] = {};

    def postinit -> None;
    def load(force_reload: bool = False) -> None;
    def _load_manifest -> None;
    def _extract_access_levels -> None;
    def _collect_functions -> dict[str, Callable[(..., Any)]];
    def _collect_walkers -> dict[str, type[WalkerArchetype]];
    def get_functions -> dict[str, Callable[(..., Any)]];
    def get_walkers -> dict[str, type[WalkerArchetype]];
    def get_client_functions -> dict[str, Callable[(..., Any)]];
    def introspect_callable(func: Callable[(..., Any)]) -> dict[str, Any];
    def introspect_walker(walker_cls: type[WalkerArchetype]) -> dict[str, Any];
    def ensure_bundle -> str;
    def render_page(
        function_name: str, args: dict[(str, Any)], username: str
    ) -> dict[str, Any];

    def is_auth_required_for_function(func_name: str) -> bool;
    def is_auth_required_for_walker(walker_name: str) -> bool;
    def _collect_client_globals -> dict[str, Any];
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
