import logging;
import mimetypes;
import from pathlib { Path }

glob _logger = logging.getLogger(__name__);


obj EmbeddedGateway(Gateway) {
    has registry: ServiceRegistry,
        transport: ServiceTransport,
        port: int = DEFAULT_GATEWAY_PORT,
        host: str = DEFAULT_GATEWAY_HOST,
        client_dist_dir: str = DEFAULT_CLIENT_DIST_DIR,
        port_pinned: bool = False,
        app: any = None;

    def setup -> None;
    def _service_prefixes -> list[str];
    def _service_for_prefix(prefix: str) -> str;
    async def dispatch(request: Request) -> Response;
    async def _call_member(
        service: str, remainder: str, payload: dict[str, any]
    ) -> Response | None;

    def _serve_static(path: str, accept: str) -> Response;
    def serve(on_ready: any = None) -> None;
}
