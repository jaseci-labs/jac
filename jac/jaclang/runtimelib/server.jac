import asyncio;
import dataclasses;
import hashlib;
import inspect;
import json;
import os;
import secrets;
import sqlite3;
import threading;
import from collections.abc { Callable }
import from http.server { BaseHTTPRequestHandler, HTTPServer }
import from inspect { iscoroutine, isgenerator }
import from pathlib { Path }
import from typing {
    Any,
    AsyncGenerator,
    Generator,
    Literal,
    TypeAlias,
    get_type_hints
}
import from urllib.parse { parse_qs, urlparse }
import from jaclang.runtimelib.client_bundle { ClientBundleError }
import from jaclang.runtimelib.context { CallState, ExecutionContext }
import from jaclang.runtimelib.transport { TransportResponse, HTTPTransport, Meta }
import from jaclang { JacRuntime as Jac }
import from jaclang.project.config { get_config }
import from jaclang.runtimelib.scheduler { Scheduler }
import from jaclang.jac0core.constant { Constants as Con }
import type from jaclang.jac0core.constructs { Archetype, WalkerArchetype }

glob JsonValue: TypeAlias = None | str | int | float | bool | list['JsonValue'] | dict[
         (str, 'JsonValue')
     ],
     StatusCode: TypeAlias = Literal[(200, 201, 400, 401, 404, 500, 503)];

obj UserManager {
    has base_path: str,
        _db_path: str postinit,
        _conn: (sqlite3.Connection | None) postinit,
        _lock: threading.RLock postinit;

    def postinit -> None;
    def _ensure_connection -> None;
    def create_user(username: str, password: str) -> dict[str, str];
    def authenticate(username: str, password: str) -> (dict[(str, str)] | None);
    def validate_token(token: str) -> (str | None);
    def get_root_id(username: str) -> (str | None);
    def reset_root(username: str) -> (str | None);
    def get_user(username: str) -> (dict[(str, str)] | None);
    def user_exists(username: str) -> bool;
    def update_username(current_username: str, new_username: str) -> dict[str, str];
    def update_password(
        username: str, current_password: str, new_password: str
    ) -> dict[str, str];

    def close -> None;
    async def aget_root_id(username: str) -> (str | None);
}

obj ExecutionManager {
    has base_path: str,
        user_manager: UserManager;

    async def execute_function(
        func: Callable[(..., Any)], args: dict[(str, Any)], username: str
    ) -> dict[str, JsonValue] | Generator | AsyncGenerator;

    async def execute_function_sync(
        func: Callable[(..., Any)], args: dict[(str, Any)], username: str
    ) -> dict[str, JsonValue] | Generator | AsyncGenerator;

    async def execute_function_async(
        func: Callable[(..., Any)], args: dict[(str, Any)], username: str
    ) -> dict[str, JsonValue] | Generator | AsyncGenerator;

    async def spawn_walker(
        walker_cls: type[WalkerArchetype], fields: dict[(str, Any)], username: str
    ) -> dict[str, JsonValue] | Generator | AsyncGenerator;

    async def spawn_walker_sync(
        walker_cls: type[WalkerArchetype], fields: dict[(str, Any)], username: str
    ) -> dict[str, JsonValue] | Generator | AsyncGenerator;

    async def spawn_walker_async(
        walker_cls: type[WalkerArchetype], fields: dict[(str, Any)], username: str
    ) -> dict[str, JsonValue] | Generator | AsyncGenerator;

    async def report_collector(call_state: CallState) -> dict[str, JsonValue];
    async def _finalize_call_response(
        call_state: CallState, result: any
    ) -> dict[str, JsonValue] | Generator | AsyncGenerator;
}

obj ModuleIntrospector {
    has module_name: str,
        base_path: (str | None),
        _module: any = None,
        _functions: dict[(str, Callable[(..., Any)])] = {},
        _walkers: dict[(str, type[WalkerArchetype])] = {},
        _client_functions: dict[(str, Callable[(..., Any)])] = {},
        _client_manifest: dict[(str, Any)] = {},
        _bundle: any = None,
        _bundle_error: (str | None) = None,
        _bundle_builder: any postinit,
        _function_access: dict[(str, bool)] = {},
        _walker_access: dict[(str, bool)] = {},
        _spa_routes_loaded: bool = False,
        _spa_route_patterns: (list[str] | None) = None;

    def postinit -> None;
    def load(force_reload: bool = False) -> None;
    def _load_manifest -> None;
    def _extract_access_levels -> None;
    def _collect_cross_boundary_endpoints -> None;
    def _register_sealed_bindings(sm: dict[str, any], img_root: str) -> None;
    def _fill_endpoint_effect_defaults -> None;
    def _collect_functions -> dict[str, Callable[(..., Any)]];
    def _collect_walkers -> dict[str, type[WalkerArchetype]];
    def _check_module_freshness -> None;
    def get_functions -> dict[str, Callable[(..., Any)]];
    def get_walkers -> dict[str, type[WalkerArchetype]];
    def get_client_functions -> dict[str, Callable[(..., Any)]];
    def resolve_root_app(configured: str = "") -> str;
    def introspect_callable(func: Callable[(..., Any)]) -> dict[str, any];
    def introspect_walker(walker_cls: type[WalkerArchetype]) -> dict[str, any];
    def ensure_bundle -> str;
    def render_page(
        function_name: str, args: dict[(str, Any)], username: str
    ) -> dict[str, any];

    def spa_fallback_status(url_path: str) -> int;
    def _load_spa_routes -> (list[str] | None);
    def _spa_route_matches(pattern: str, segments: list[str]) -> bool;
    def is_auth_required_for_function(func_name: str) -> bool;
    def is_auth_required_for_walker(walker_name: str) -> bool;
}

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

obj IntrospectionHandler {
    has introspector: ModuleIntrospector,
        execution_manager: ExecutionManager,
        user_manager: UserManager;

    def list_functions -> TransportResponse;
    def list_walkers -> TransportResponse;
    def get_function_info(name: str) -> TransportResponse;
    def get_walker_info(name: str) -> TransportResponse;
}

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

obj JacAPIServer {
    has module_name: str,
        port: int = 8000,
        base_path: str = "",
        is_sv_sibling: bool = False,
        user_manager: UserManager postinit,
        execution_manager: ExecutionManager postinit,
        introspector: ModuleIntrospector postinit,
        auth_handler: AuthHandler postinit,
        introspection_handler: IntrospectionHandler postinit,
        execution_handler: ExecutionHandler postinit,
        server: (HTTPServer | None) postinit,
        scheduler: Scheduler postinit;

    obj RestSpecs {
        has method: str = "",
            path: str = "",
            protocol: APIProtocol = APIProtocol.HTTP,
            broadcast: bool = False;
    }

    def postinit -> None;
    def create_handler -> type[BaseHTTPRequestHandler];
    def load_module(force_reload: bool = False) -> None;

    has module: object { getter; }

    def get_functions -> dict[str, Callable[(..., Any)]];
    def get_walkers -> dict[str, type[WalkerArchetype]];
    def print_endpoint_docs -> None;
    def _ensure_sv_siblings -> None;
    def start(
        dev: bool = False,
        no_client: bool = False,
        on_ready: Callable[[int], None] | None = None
    ) -> None;
}

def print_endpoint_docs(server: JacAPIServer) -> None;
