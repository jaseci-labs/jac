import asyncio;
import inspect;
import logging;
import threading;
import time;

glob logger: logging.Logger = logging.getLogger(__name__),
     HEALTH_PATHS: set[str] = {'/healthz', '/healthz/live', '/healthz/ready'},
     LIVENESS_PATHS: set[str] = {'/healthz', '/healthz/live'},
     DRAIN_HOOKS: list[Callable[[], any]] = [],
     DRAIN_TAKEN: set[int] = set();


obj DrainState {
    has draining: bool = False,
        started_at: float = 0.0,
        timeout: float = 10.0,
        reason: str = '',
        hooks_thread: (threading.Thread | None) = None;

    def start(reason: str = 'shutdown') -> bool;
    def wait_for_hooks;
    async def await_hooks;
    def remaining -> float;
    def reset;
}


async def run_hooks(hooks: list[Callable[..., any]], what: str);


def _start_drain_hooks -> threading.Thread;


def _run_drain_hooks;


def draining_response(service: str = 'service') -> Response;


def drain_middleware(
    state: DrainState, service: str = 'service'
) -> Callable[..., any];
