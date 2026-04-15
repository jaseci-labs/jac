"""API Gateway — routes client traffic to sv-import services by URL prefix.

Works on top of the existing sv import infrastructure:
- Services register in sv_client._registry (via ensure_sv_service)
- Gateway reads those URLs and proxies /api/{service}/* to them
- Also serves static client assets, admin UI, and built-in jac-scale routes
"""

import logging;
import mimetypes;
import shutil;
import uvicorn;
import from pathlib { Path }
import from fastapi { FastAPI, Request }
import from fastapi.responses { HTMLResponse, JSONResponse, Response }
import from jac_scale.microservices.impl.http_forward { raw_forward }
import from jac_scale.config_loader { get_scale_config }
import from jaclang.cli.console { console }

glob logger = logging.getLogger(__name__),
     HOP_BY_HOP_HEADERS: set[str] = {"host","transfer-encoding","connection","keep-alive"};

"""API Gateway that routes client requests to microservices by path prefix."""
obj MicroserviceGateway {
    has routes: dict[str, str] = {},
        app: FastAPI | None = None,
        port: int = 8000,
        host: str = "0.0.0.0",
        client_dist_dir: str = ".jac/client/dist",
        admin_dist_dir: str = ".jac/admin";

    """Create the FastAPI app and register the middleware."""
    def setup -> FastAPI;

    """Resolve a service URL from sv_client registry for a given module name."""
    def resolve_service_url(module_name: str) -> str | None;

    """Build the target URL by stripping the API prefix."""
    def build_target_url(service_url: str, prefix: str, path: str, query: str) -> str;

    """Serve a static file from client dist. Returns None if not found."""
    def serve_static(file_path: str) -> Response | None;

    """Serve index.html for SPA fallback. Returns None if not found."""
    def serve_spa_fallback -> Response | None;

    """Bootstrap admin UI from pre-built bundle if needed."""
    def bootstrap_admin -> None;

    """Serve an admin asset. Returns None if not found."""
    def serve_admin_asset(asset_path: str) -> Response | None;

    """Start the gateway server (blocking)."""
    def start -> None;
}
