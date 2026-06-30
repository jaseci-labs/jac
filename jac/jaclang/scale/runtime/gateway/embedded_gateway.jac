import logging;
import mimetypes;
import from pathlib { Path }
import from fastapi { FastAPI, Request }
import from fastapi.responses { JSONResponse, Response }
import from jaclang.scale.runtime.gateway.gateway { Gateway }
import from jaclang.scale.runtime.gateway.service_registry { ServiceRegistry }
import from jaclang.scale.runtime.gateway.dispatch {
    classify_route,
    ROUTE_PROXY,
    ROUTE_STATIC
}
import from jaclang.scale.runtime.transport.transport { ServiceTransport }
import from jaclang.scale.runtime.context.util {
    DEFAULT_GATEWAY_PORT,
    DEFAULT_GATEWAY_HOST,
    DEFAULT_CLIENT_DIST_DIR
}

glob _logger = logging.getLogger(__name__);


obj EmbeddedGateway(Gateway) {
    has registry: ServiceRegistry,
        transport: ServiceTransport,
        port: int = DEFAULT_GATEWAY_PORT,
        host: str = DEFAULT_GATEWAY_HOST,
        client_dist_dir: str = DEFAULT_CLIENT_DIST_DIR,
        app: FastAPI | None = None;

    def setup -> None;
    def _service_prefixes -> list[str];
    def _service_for_prefix(prefix: str) -> str;
    async def dispatch(request: Request) -> Response;
    async def _call_member(
        service: str, remainder: str, payload: dict[str, any]
    ) -> Response | None;

    def _serve_static(path: str, accept: str) -> Response;
    def serve -> None;
}
