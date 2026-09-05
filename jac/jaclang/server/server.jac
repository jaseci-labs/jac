import asyncio;
import logging;
import threading;
import from inspect { isgenerator }
import from pathlib { Path }
import from typing { AsyncGenerator, Generator, TypeAlias }
import from jaclang.runtime.builtin { APIProtocol }
import from jaclang.runtime.context { CallState, ExecutionContext }
import from jaclang.server.identity.user_manager { UserManager }
import from jaclang.server.serving.app { ServingApp }
import from jaclang.server.serving.drain { DrainState }
import from jaclang.server.serving.endpoint { JEndPoint, WSEndPoint }
import from jaclang.server.serving.supervisor { WorkerHandle }
import from jaclang.server.settings { ServeSettings }
import from jaclang.server.task_scheduler { Scheduler }
import from jaclang { JacRuntime as Jac }
import type from jaclang.runtime.constructs { WalkerArchetype }

glob JsonValue: TypeAlias = None
         | str
         | int
         | float
         | bool
         | list['JsonValue']
         | dict[(str, 'JsonValue')],
     logger: logging.Logger = logging.getLogger('jaclang.serve');


obj ServerExtension {
    def validate(server: JacAPIServer) -> list[str] {
        return [];
    }

    def register(server: JacAPIServer) -> None abst;
    def on_worker_start(server: JacAPIServer) {}
}


obj EndpointHost {
    def add_endpoint(ep: JEndPoint) -> None abst;
    def identity -> UserManager abst;
}


obj RequestMetrics {
    def request_started -> None abst;
    def request_finished -> None abst;
    def record_request(
        method: str, path: str, status: int, duration: float
    ) -> None abst;

    def record_read_tier_retry(unit_key: str) -> None abst;
}


def observe_read_tier_retry(metrics: any, unit_key: str) -> None;


def target_restspec(target: any) -> any {
    return target.restspec if target?.restspec else None;
}


def target_schedule_spec(target: any) -> any {
    return target.schedule_spec if target?.schedule_spec else None;
}


obj ExecutionManager {
    has base_path: str,
        user_manager: UserManager,
        metrics: any = None;

    async def execute_function(
        func: Callable[(..., any)], args: dict[(str, any)], username: str
    ) -> dict[str, JsonValue] | Generator | AsyncGenerator;

    async def execute_function_sync(
        func: Callable[(..., any)], args: dict[(str, any)], username: str
    ) -> dict[str, JsonValue] | Generator | AsyncGenerator;

    async def execute_function_async(
        func: Callable[(..., any)], args: dict[(str, any)], username: str
    ) -> dict[str, JsonValue] | Generator | AsyncGenerator;

    async def spawn_walker(
        walker_cls: type[WalkerArchetype], fields: dict[(str, any)], username: str
    ) -> dict[str, JsonValue] | Generator | AsyncGenerator;

    async def spawn_walker_sync(
        walker_cls: type[WalkerArchetype], fields: dict[(str, any)], username: str
    ) -> dict[str, JsonValue] | Generator | AsyncGenerator;

    async def spawn_walker_async(
        walker_cls: type[WalkerArchetype], fields: dict[(str, any)], username: str
    ) -> dict[str, JsonValue] | Generator | AsyncGenerator;

    async def report_collector(
        call_state: CallState
    ) -> list[JsonValue] | Generator | AsyncGenerator;

    async def _finalize_call_response(
        call_state: CallState, result: any
    ) -> dict[str, JsonValue] | Generator | AsyncGenerator;
}

obj ModuleIntrospector {
    has module_name: str,
        base_path: (str | None),
        module_file: (str | None) = None,
        _module: any = None,
        _functions: dict[(str, Callable[(..., any)])] = {},
        _walkers: dict[(str, type[WalkerArchetype])] = {},
        _client_functions: dict[(str, Callable[(..., any)])] = {},
        _client_manifest: dict[(str, any)] = {},
        _bundle: any = None,
        _bundle_error: (str | None) = None,
        _bundle_epoch: int = 0,
        _bundle_builder: any postinit,
        _bundle_lock: threading.Lock postinit,
        _function_access: dict[(str, bool)] = {},
        _walker_access: dict[(str, bool)] = {},
        _spa_routes_loaded: bool = False,
        _spa_route_patterns: (list[str] | None) = None,
        dev_mode: bool = False;

    def postinit -> None;
    def load(force_reload: bool = False) -> None;
    def _load_manifest -> None;
    def _extract_access_levels -> None;
    def _collect_cross_boundary_endpoints -> None;
    def _register_sealed_bindings(sm: dict[str, any], img_root: str) -> None;
    def _fill_endpoint_effect_defaults -> None;
    def _collect_functions -> dict[str, Callable[(..., any)]];
    def _collect_walkers -> dict[str, type[WalkerArchetype]];
    def _check_module_freshness -> None;
    def get_functions -> dict[str, Callable[(..., any)]];
    def get_walkers -> dict[str, type[WalkerArchetype]];
    def get_client_functions -> dict[str, Callable[(..., any)]];
    def resolve_root_app(configured: str = "") -> str;
    def introspect_callable(func: Callable[(..., any)]) -> dict[str, any];
    def introspect_walker(walker_cls: type[WalkerArchetype]) -> dict[str, any];
    def ensure_bundle -> str;
    def _invalidate_bundle -> None;
    def render_page(
        function_name: str, args: dict[(str, any)], username: str
    ) -> dict[str, any];

    def spa_fallback_status(url_path: str) -> int;
    def has_client_route(url_path: str) -> bool;
    def _load_spa_routes -> (list[str] | None);
    def _spa_route_matches(pattern: str, segments: list[str]) -> bool;
    def is_auth_required_for_function(func_name: str) -> bool;
    def is_auth_required_for_walker(walker_name: str) -> bool;
    def restspec_routes -> list[tuple[str, str, any]];
    def declared_api_paths -> list[str];
    def client_claimed_paths(candidates: list[str]) -> list[str];
    def walker_protocol(walker_name: str) -> APIProtocol;
    def function_protocol(func_name: str) -> APIProtocol;
}

obj JacAPIServer(EndpointHost) {
    has module_name: str,
        base_path: str = "",
        module_file: (str | None) = None,
        port: int = 0,
        strict_port: bool = False,
        is_sv_sibling: bool = False,
        settings: (ServeSettings | None) = None,
        extensions: (list[ServerExtension] | None) = None,
        user_manager: UserManager postinit,
        execution_manager: ExecutionManager postinit,
        introspector: ModuleIntrospector postinit,
        scheduler: Scheduler postinit,
        drain: DrainState postinit,
        app: (ServingApp | None) = None,
        server: any = None,
        metrics: any = None,
        metrics_path: str = '',
        emailer: any = None,
        _endpoints: list[JEndPoint] = [],
        _hmr_pending: bool = False,
        _hot_reloader: any = None;

    obj RestSpecs {
        has method: str = "",
            path: str = "",
            protocol: APIProtocol = APIProtocol.HTTP,
            broadcast: bool = False,
            produces: str = "",
            envelope: bool = True;
    }

    def postinit -> None;
    def resolved_settings -> ServeSettings;
    def identity -> UserManager;
    def require_app -> ServingApp;
    def add_endpoint(ep: JEndPoint) -> None;
    def add_ws_endpoint(path: str, handler: Callable[..., any]) -> None;
    def add_middleware(fn: Callable[..., any]) -> None;
    def add_shutdown_hook(fn: Callable[..., any]) -> None;
    def build_app -> ServingApp;
    def register_endpoints -> None;
    def _install_middleware -> None;
    def _configure_openapi_security -> None;
    def enable_hmr(hot_reloader: any) -> None;
    def _refresh_dev_endpoints -> None;
    def load_module(force_reload: bool = False) -> None;

    has module: object { getter; }

    def get_functions -> dict[str, Callable[(..., any)]];
    def get_walkers -> dict[str, type[WalkerArchetype]];
    def print_endpoint_docs -> None;
    def _ensure_sv_siblings -> None;
    def _ensure_client_bundle -> None;
    def _ensure_internal_users -> None;
    def _register_scheduled_tasks -> None;
    def _validate_or_raise -> None;
    def _prepare_to_serve(dev: bool, no_client: bool) -> ServeSettings;
    def start(
        dev: bool = False,
        no_client: bool = False,
        on_ready: Callable[..., None] | None = None
    ) -> int;

    def serve_background(
        dev: bool = False,
        no_client: bool = False,
        on_ready: Callable[..., None] | None = None,
        port_retries: int = 0
    ) -> Callable[[], None];

    def _worker_main(
        handle: (WorkerHandle | None),
        on_ready: (Callable[[int], None] | None) = None,
        port_retries: int = 0
    ) -> int;

    def request_stop -> None;
}

def print_endpoint_docs(server: JacAPIServer) -> None;
