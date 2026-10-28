import logging;
import time;

glob logger: logging.Logger = logging.getLogger(__name__),
     HEALTH_PATHS: set[str] = {'/healthz', '/healthz/live', '/healthz/ready'},
     LIVENESS_PATHS: set[str] = {'/healthz', '/healthz/live'};


obj DrainState {
    has draining: bool = False,
        started_at: float = 0.0,
        timeout: float = 10.0,
        reason: str = '';

    def start(reason: str = 'shutdown') -> bool;
    def remaining -> float;
    def reset;
}


def draining_response(service: str = 'service') -> Response;


def drain_middleware(
    state: DrainState, service: str = 'service'
) -> Callable[..., any];
