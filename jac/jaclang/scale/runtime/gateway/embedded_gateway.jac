import logging;
import from pathlib { Path }
import from jaclang.runtimelib.serving.app { ServingApp }
import from jaclang.runtimelib.serving.datatypes { JSONResponse, Request, Response }
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
import from jaclang.runtimelib.serving.static_assets { AssetRoot }

glob _logger = logging.getLogger(__name__);


obj EmbeddedGateway(Gateway) {
    has registry: ServiceRegistry,
        transport: ServiceTransport,
        port: int = DEFAULT_GATEWAY_PORT,
        host: str = DEFAULT_GATEWAY_HOST,
        client_dist_dir: str = DEFAULT_CLIENT_DIST_DIR,
        base_path: str = ".",
        static_mounts: list[dict[str, str]] = [],
        app: any = None,
        _asset_table: list[AssetRoot] | None = None;

    def setup -> None;
    def _get_asset_table -> list[AssetRoot];
    def _service_prefixes -> list[str];
    def _service_for_prefix(prefix: str) -> str;
    async def dispatch(request: Request) -> Response;
    async def _call_member(
        service: str, remainder: str, payload: dict[str, any]
    ) -> Response | None;

    def _serve_static(path: str, accept: str) -> Response;
    def serve -> None;
}
