import asyncio;
import logging;
import from concurrent.futures { ThreadPoolExecutor }

glob logger: logging.Logger = logging.getLogger(__name__),
     _STREAM_STOP: any = object();


obj SyncExecutor {
    has threads: int = 8,
        _pool: (ThreadPoolExecutor | None) = None;

    def install(loop: any) -> ThreadPoolExecutor;
    def shutdown(`wait: bool = False);
}


async def run_sync(fn: Callable[..., any], *args: any) -> any;


async def iterate_sync(source: any) -> AsyncIterator[any];
