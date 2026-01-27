"""REST API Server for Jac Programs."""
import asyncio;
import hashlib;
import html;
import inspect;
import json;
import os;
import secrets;
import from collections.abc { Callable }
import from contextlib { suppress }
import from http.server { BaseHTTPRequestHandler, HTTPServer }
import from inspect { iscoroutine, isgenerator }
import from pathlib { Path }
import from typing {
    TYPE_CHECKING,
    Any,
    AsyncGenerator,
    Literal,
    TypeAlias,
    get_type_hints
}
import from urllib.parse { parse_qs, urlparse }
import from jaclang.runtimelib.client_bundle { ClientBundleError }
import from jaclang.runtimelib.context { CallState }
import from jaclang.runtimelib.transport {
    BaseTransport,
    TransportRequest,
    TransportResponse,
    HTTPTransport,
    Meta
}
import from jaclang { JacRuntime as Jac }
import from jaclang.project.config { get_config }

with entry {
    if TYPE_CHECKING {
        import from jaclang.pycore.constructs { Archetype, WalkerArchetype }
    }
}

glob JsonValue: TypeAlias = None | str | int | float | bool | <>list['JsonValue'] | <>dict[
         (str, 'JsonValue')
     ],
     StatusCode: TypeAlias = Literal[(200, 201, 400, 401, 404, 500, 503)];

"""Base response container (HTTP-specific, kept for backward compatibility)."""
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
obj JacSerializer {
    static def serialize(<>obj: object) -> JsonValue;
    static def _serialize_archetype(arch: Archetype) -> dict[str, JsonValue];
}

"""Manage users and their persistent roots (SQLite-backed)."""
obj UserManager {
    has base_path: str,
        _db_path: str = "",
        _conn: Any = None;

    def postinit -> None;
    def _ensure_connection -> None;
    def create_user(username: str, password: str) -> dict[str, str];
    def authenticate(username: str, password: str) -> (dict[(str, str)] | None);
    def validate_token(token: str) -> (str | None);
    def get_root_id(username: str) -> (str | None);
    def get_user(username: str) -> (dict[(str, str)] | None);
    def user_exists(username: str) -> bool;
    def update_username(current_username: str, new_username: str) -> dict[str, str];
    def update_password(
        username: str, current_password: str, new_password: str
    ) -> dict[str, str];

    def close -> None;
}

"""Manages execution contexts for user operations."""
obj ExecutionManager {
    has base_path: str,
        user_manager: UserManager;

    async def execute_function(
        func: Callable[(..., Any)], args: dict[(str, Any)], username: str
    ) -> dict[str, JsonValue];

    async def spawn_walker(
        walker_cls: type[WalkerArchetype], fields: dict[(str, Any)], username: str
    ) -> dict[str, JsonValue];

    async def report_collector(call_state: CallState) -> dict[str, JsonValue];
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
    def _check_module_freshness -> None;
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
obj ResponseBuilder {
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
    static def _add_custom_headers(handler: BaseHTTPRequestHandler) -> None;
}

"""Base route handler."""
obj RouteHandler {
    has introspector: ModuleIntrospector,
        execution_manager: ExecutionManager,
        user_manager: UserManager;
}

"""Handle authentication routes."""
obj AuthHandler {
    has introspector: ModuleIntrospector,
        execution_manager: ExecutionManager,
        user_manager: UserManager;

    def create_user(username: str, password: str) -> TransportResponse;
    def login(username: str, password: str) -> TransportResponse;
    def update_username(
        current_username: str, new_username: str, token: str
    ) -> TransportResponse;

    def update_password(
        username: str, current_password: str, new_password: str, token: str
    ) -> TransportResponse;

    def get_user_info(token: str) -> TransportResponse;
}

"""Handle introspection routes."""
obj IntrospectionHandler {
    has introspector: ModuleIntrospector,
        execution_manager: ExecutionManager,
        user_manager: UserManager;

    def list_functions -> TransportResponse;
    def list_walkers -> TransportResponse;
    def get_function_info(name: str) -> TransportResponse;
    def get_walker_info(name: str) -> TransportResponse;
}

"""Handle execution routes."""
obj ExecutionHandler {
    has introspector: ModuleIntrospector,
        execution_manager: ExecutionManager,
        user_manager: UserManager;

    async def call_function(
        name: str, args: dict[(str, Any)], username: str
    ) -> TransportResponse;

    async def spawn_walker(
        name: str, fields: dict[(str, Any)], username: str
    ) -> TransportResponse;
}

"""REST API Server for Jac programs."""
obj JacAPIServer {
    has module_name: str,
        port: int = 8000,
        base_path: str = "";

    obj RestSpecs {
        has method: str;
    }

    def postinit -> None;
    def create_handler -> type[BaseHTTPRequestHandler];
    def load_module(force_reload: bool = False) -> None;
    @property
    def module -> object;

    def get_functions -> dict[str, Callable[(..., Any)]];
    def get_walkers -> dict[str, type[WalkerArchetype]];
    def introspect_callable(func: Callable[(..., Any)]) -> dict[str, Any];
    def introspect_walker(walker_cls: type[WalkerArchetype]) -> dict[str, Any];
    def render_client_page(
        function_name: str, args: dict[(str, Any)], username: str
    ) -> dict[str, Any];

    def get_client_bundle_code -> str;
    def print_endpoint_docs -> None;
    def start(dev: bool = False) -> None;
}

"""Print comprehensive documentation for all endpoints that would be generated."""
def print_endpoint_docs(server: JacAPIServer) -> None;
