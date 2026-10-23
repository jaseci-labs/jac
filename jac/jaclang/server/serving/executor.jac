import asyncio;
import inspect;
import logging;
import from concurrent.futures { ThreadPoolExecutor }

glob logger: logging.Logger = logging.getLogger(__name__),
     _STREAM_STOP: any = object(),
     _CLOSE_POLL_SECONDS: float = 0.01;


obj SyncExecutor {
    has threads: int = 8,
        _pool: (ThreadPoolExecutor | None) = None;

    def install(loop: any) -> ThreadPoolExecutor;
    def shutdown(`wait: bool = False);
}


async def run_sync(fn: Callable[..., any], *args: any) -> any;


async def iterate_sync(source: any) -> AsyncIterator[any];


async def close_stream(source: any);
