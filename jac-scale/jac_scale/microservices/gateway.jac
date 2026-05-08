"""API Gateway - path-based reverse proxy for microservices."""

import logging;
import mimetypes;
import uvicorn;
import from pathlib { Path }
import from fastapi { FastAPI, Request }
import from fastapi.responses { HTMLResponse, JSONResponse, Response }
import from jac_scale.microservices.service_registry {
    ServiceRegistry,
    ServiceEntry,
    ServiceStatus
}
import from jac_scale.microservices.impl.http_forward { raw_forward }
import from jac_scale.microservices._util {
    DEFAULT_GATEWAY_PORT,
    DEFAULT_GATEWAY_HOST,
    DEFAULT_CLIENT_DIST_DIR
}
import from typing { Any }

glob logger = logging.getLogger(__name__),
     HOP_BY_HOP_HEADERS: set[str] = {"host","transfer-encoding","connection","keep-alive"};

"""API Gateway that routes requests to microservices by path prefix.

Request handling is split into named handlers so each responsibility is
independently testable. `setup()` wires them into a single middleware
dispatcher.
"""
obj MicroserviceGateway {
    has registry: ServiceRegistry,
        app: FastAPI | None = None,
        port: int = DEFAULT_GATEWAY_PORT,
        host: str = DEFAULT_GATEWAY_HOST,
        client_dist_dir: str = DEFAULT_CLIENT_DIST_DIR,
        admin_dist_dir: str = ".jac/admin",
        # Optional declarative static mounts: each entry is
        # {"url_prefix": "/foo", "local_path": "/abs/or/rel/path"}.
        # Configured via [[plugins.scale.microservices.client.static_mounts]]
        # in jac.toml; consulted by handle_static BEFORE falling back to
        # client_dist_dir so projects can serve repo-root assets without
        # restructuring the build output. Default empty list = behavior
        # unchanged from before the feature.
        static_mounts: list[dict[str, str]] = [],
        # Prometheus metrics registry + collectors. None when
        # prometheus_client isn't installed; the dispatcher no-ops
        # instrumentation in that case.
        _metrics_registry: Any = None,
        _metrics_requests: Any = None,
        _metrics_duration: Any = None;

    """Create the FastAPI app and register routes."""
    def setup -> FastAPI;

    """Build the target URL by stripping prefix and resolving walker/function path."""
    def resolve_target_url(service_entry: ServiceEntry, path: str, query: str) -> str;

    # --- request handlers (each returns a Response or None to defer) ---
    """Return the health summary response (registry view, human-facing)."""
    def handle_health -> Response;

    """Liveness response - always 200 if the dispatcher runs (for K8s
       livenessProbe; dependency state is intentionally NOT checked here)."""
    def handle_health_live -> Response;

    """Readiness response - 200 normally, 503 when drain is in progress
       (for K8s readinessProbe; gates Endpoints membership)."""
    def handle_health_ready -> Response;

    """Forward built-in jac-scale routes (/user/*, /walker/*, /function/* etc)
       to any healthy service; returns None if path isn't a built-in."""
    async def handle_builtin_passthrough(
        request: Request, path: str
    ) -> Response | None;

    """Handle admin UI routes; returns None if not an admin path."""
    def handle_admin(path: str) -> Response | None;

    """Proxy to the microservice matched by prefix; returns None if no match."""
    async def handle_proxy(request: Request, path: str) -> Response | None;

    """Serve static files or SPA fallback for GET requests; returns None if nothing found."""
    def handle_static(request: Request, path: str) -> Response | None;

    """Serve the Prometheus exposition for this gateway's metrics registry.
       Returns 503 if prometheus_client isn't available."""
    def handle_metrics -> Response;

    """Return the aggregated OpenAPI schema across all healthy services."""
    async def handle_openapi -> Response;

    """Render the Swagger UI page pointing at our aggregated /openapi.json."""
    def handle_docs -> Response;

    # --- helpers used by handlers ---
    """Forward selected request headers to a target, stripping hop-by-hop headers."""
    def build_forward_headers(request: Request) -> dict[str, str];

    """Serve a static file from the client dist directory. Returns None if not found."""
    def serve_static(file_path: str) -> Response | None;

    """Serve a static file from a configured `static_mounts` entry's local
    directory. Path-jails to that directory (rejects ../ escapes). Returns
    None if not found."""
    def serve_extra_static(local_dir: str, file_path: str) -> Response | None;

    """Serve index.html for SPA fallback. Returns None if no index.html exists."""
    def serve_spa_fallback -> Response | None;

    """Bootstrap admin UI - copy pre-built bundle to admin_dist_dir if needed."""
    def bootstrap_admin -> None;

    """Serve an admin asset by path. Returns None if not found."""
    def serve_admin_asset(asset_path: str) -> Response | None;

    """Start the gateway server (blocking)."""
    def start -> None;
}
