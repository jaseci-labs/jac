import logging;
import mimetypes;
import from pathlib { Path }
import from jaclang.server.serving.app { ServingApp }
import from jaclang.server.serving.datatypes { Request }
import from jaclang.server.serving.datatypes { HTMLResponse, JSONResponse, Response }
import from jaclang.scale.runtime.gateway.service_registry {
    ServiceRegistry,
    ServiceEntry,
    ServiceStatus
}
import from jaclang.scale.runtime.gateway.route_table { ServiceRouteTable }
import from jaclang.scale.runtime.transport.http_forward { raw_forward }
import from jaclang.scale.runtime.context.util {
    DEFAULT_GATEWAY_PORT,
    DEFAULT_GATEWAY_HOST,
    DEFAULT_CLIENT_DIST_DIR
}

import from jaclang.server.identity.user_manager { UserManager }
import from jaclang.server.server { EndpointHost }
import from jaclang.server.serving.drain { DrainState }
import from jaclang.server.serving.endpoint { JEndPoint }
import from jaclang.scale.admin.admin_portal { JacAPIServerAdmin }
import from jaclang.scale.admin.workloads { JacAPIServerWorkloads }
import from jaclang.scale.admin.logs { JacAPIServerLogs }
import from jaclang.scale.admin.traces { JacAPIServerTraces }
import from jaclang.scale.admin.ops { JacAPIServerOps }
import from jaclang.scale.admin.deploy_health { JacAPIServerDeployHealth }
import from jaclang.scale.admin.network { JacAPIServerNetwork }
import from jaclang.scale.admin.podenv { JacAPIServerPodEnv }
import from jaclang.scale.admin.llm_telemetry { JacAPIServerLLMTelemetry }

glob logger = logging.getLogger(__name__),
     HOP_BY_HOP_HEADERS: set[str] = {
         "host",
         "transfer-encoding",
         "connection",
         "keep-alive"
     };

obj MicroserviceGateway(EndpointHost, JacAPIServerAdmin, JacAPIServerWorkloads, JacAPIServerLogs, JacAPIServerTraces, JacAPIServerOps, JacAPIServerDeployHealth, JacAPIServerNetwork, JacAPIServerPodEnv, JacAPIServerLLMTelemetry) {
    has registry: ServiceRegistry,
        app: any = None,
        port: int = DEFAULT_GATEWAY_PORT,
        host: str = DEFAULT_GATEWAY_HOST,
        client_dist_dir: str = DEFAULT_CLIENT_DIST_DIR,
        admin_dist_dir: str = ".jac/admin",
        static_mounts: list[dict[str, str]] = [],
        _metrics_registry: any = None,
        _metrics_requests: any = None,
        _metrics_duration: any = None,
        server: any = None,
        user_manager: any = None,
        _metrics: any = None,
        base_path: str = ".",
        route_table: ServiceRouteTable = ServiceRouteTable(),
        _spec_crawl: any = None,
        port_pinned: bool = False,
        drain: DrainState = DrainState();

    def setup -> ServingApp;
    def add_endpoint(ep: JEndPoint) -> None;
    def identity -> UserManager;
    def resolve_target_url(service_entry: ServiceEntry, path: str, query: str) -> str;
    def handle_health -> Response;
    def handle_health_live -> Response;
    def handle_health_ready -> Response;
    async def aggregate_graph_data(request: Request) -> Response | None;
    async def handle_builtin_passthrough(
        request: Request, path: str
    ) -> Response | None;

    def eligible_services -> list[tuple[str, ServiceEntry]];
    def root_member -> ServiceEntry | None;
    def shell_answers(request: Request, path: str) -> bool;
    async def forward_to_root(request: Request, path: str) -> Response | None;
    async def forward_static_to_root(request: Request, path: str) -> Response | None;
    async def resolve_learned_owner(path: str) -> ServiceEntry | None;
    async def forward_root_path(
        request: Request, service_entry: ServiceEntry, path: str, base_url: str = ""
    ) -> Response | None;

    async def deliver_once(request: Request, path: str) -> Response | None;
    async def probe_services(
        request: Request, path: str, candidates: list[tuple[str, ServiceEntry]]
    ) -> Response;

    def handle_admin(path: str) -> Response | None;
    async def handle_proxy(request: Request, path: str) -> Response | None;
    async def handle_app_route(request: Request, path: str) -> Response | None;
    async def refresh_app_routes -> bool;
    async def forward_to(
        request: Request, service_entry: ServiceEntry, target_url: str
    ) -> Response | None;

    def service_base_url(service_entry: ServiceEntry) -> str;
    def handle_static(request: Request, path: str) -> Response | None;
    def handle_spa_fallback(request: Request, path: str) -> Response | None;
    def handle_metrics -> Response;
    async def handle_openapi -> Response;
    def handle_docs -> Response;
    def has_client_bundle -> bool;
    def build_forward_headers(request: Request) -> dict[str, str];
    def serve_static(file_path: str) -> Response | None;
    def serve_extra_static(local_dir: str, file_path: str) -> Response | None;
    def serve_project_static(rest: str) -> Response | None;
    def serve_spa_fallback -> Response | None;
    def bootstrap_admin_ui -> None;
    def _install_admin_api -> None;
    def serve_admin_asset(asset_path: str) -> Response | None;
    def start(on_ready: any = None) -> None;
}
