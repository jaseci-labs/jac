import asyncio;
import inspect;
import logging;
import traceback;


glob _logger: logging.Logger = logging.getLogger("jaclang.server.serving.app");


def transport_to_response(tr: TransportResponse) -> JSONResponse;

def _slash_alternate(path: str) -> (str | None);


def _declares_body(ep: JEndPoint) -> bool;

def _parse_request_body(request: Request, ep: JEndPoint, spool_bytes: int) -> any;

obj ServingApp {
    has title: str = 'Jac API',
        version: str = '0.1.0',
        router: Router = Router(),
        middlewares: list[Callable[..., any]] = [],
        on_shutdown: list[Callable[..., any]] = [],
        docs_url: (str | None) = '/docs',
        openapi_url: (str | None) = '/openapi.json',
        openapi_security: dict[str, any] = {},
        openapi_cache: (dict[str, any] | None) = None,
        state: dict[str, any] = {},
        multipart_spool_bytes: int = 1048576;

    def add_endpoint(ep: JEndPoint);
    def add_ws_endpoint(ep: WSEndPoint);
    def add_middleware(fn: Callable[..., any]);
    def add_shutdown_hook(fn: Callable[..., any]);
    def clear_routes;
    def openapi -> dict[str, any];
    async def shutdown;
    async def dispatch(request: Request) -> Response;
    def _wrap_middleware(
        mw: Callable[..., any], next_handler: Callable[..., any]
    ) -> Callable[..., any];

    async def _route_and_call(request: Request) -> Response;
    def _to_response(result: any, ep: JEndPoint) -> Response;
}
