import logging;
import time;

glob logger: logging.Logger = logging.getLogger('jaclang.serve');


def bearer_token(request: Request) -> (str | None);


def presented_token(request: Request) -> tuple[(str | None), bool];


def jwt_middleware(user_manager: UserManager) -> Callable[..., any];


def _service_unavailable(detail: str) -> JSONResponse;


def request_context_middleware(
    open_scope: Callable[[], RequestScope], public_origin: str = ''
) -> Callable[..., any];


def metrics_middleware(metrics: any, exempt_path: str = '') -> Callable[..., any];


def unauthorized(message: str = 'Unauthorized') -> TransportResponse;


def require_user(request: Request) -> tuple[(str | None), (TransportResponse | None)];
