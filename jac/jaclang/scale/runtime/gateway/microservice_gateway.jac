import logging;
import mimetypes;
import uvicorn;
import from pathlib { Path }
import from fastapi { FastAPI, Request }
import from fastapi.responses { HTMLResponse, JSONResponse, Response }
import from jaclang.scale.runtime.gateway.service_registry {
    ServiceRegistry,
    ServiceEntry,
    ServiceStatus
}
import from jaclang.scale.runtime.transport.http_forward { raw_forward }
import from jaclang.scale.runtime.context.util {
    DEFAULT_GATEWAY_PORT,
    DEFAULT_GATEWAY_HOST,
    DEFAULT_CLIENT_DIST_DIR
}

import from jaclang.scale.admin.admin_portal { JacAPIServerAdmin }
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

obj MicroserviceGateway(JacAPIServerAdmin, JacAPIServerLogs, JacAPIServerTraces, JacAPIServerOps, JacAPIServerDeployHealth, JacAPIServerNetwork, JacAPIServerPodEnv, JacAPIServerLLMTelemetry) {
    has registry: ServiceRegistry,
        app: FastAPI | None = None,
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
        _api_key_manager: any = None,
        _metrics: any = None,
        base_path: str = ".";

    def setup -> FastAPI;
    def resolve_target_url(service_entry: ServiceEntry, path: str, query: str) -> str;
    def handle_health -> Response;
    def handle_health_live -> Response;
    def handle_health_ready -> Response;
    async def handle_builtin_passthrough(
        request: Request, path: str
    ) -> Response | None;

    def handle_admin(path: str) -> Response | None;
    async def handle_proxy(request: Request, path: str) -> Response | None;
    def handle_static(request: Request, path: str) -> Response | None;
    def handle_metrics -> Response;
    async def handle_openapi -> Response;
    def handle_docs -> Response;
    def build_forward_headers(request: Request) -> dict[str, str];
    def serve_static(file_path: str) -> Response | None;
    def serve_extra_static(local_dir: str, file_path: str) -> Response | None;
    def serve_project_static(rest: str) -> Response | None;
    def serve_spa_fallback -> Response | None;
    def bootstrap_admin_ui -> None;
    def _install_admin_api -> None;
    def serve_admin_asset(asset_path: str) -> Response | None;
    def start -> None;
}
