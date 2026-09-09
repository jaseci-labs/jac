import asyncio;
import logging;
import from concurrent.futures { ThreadPoolExecutor }

glob logger: logging.Logger = logging.getLogger(__name__);


obj SyncExecutor {
    has threads: int = 8,
        _pool: (ThreadPoolExecutor | None) = None;

    def install(loop: any) -> ThreadPoolExecutor {
        if self._pool is None {
            self._pool = ThreadPoolExecutor(
                max_workers=max(1, self.threads), thread_name_prefix='jac-sync'
            );
        }
        loop.set_default_executor(self._pool);
        return self._pool;
    }

    def shutdown(`wait: bool = False) {
        pool = self._pool;
        self._pool = None;
        if pool is not None {
            pool.shutdown(`wait=`wait, cancel_futures=not `wait);
        }
    }
}


async def run_sync(fn: Callable[..., any], *args: any) -> any {
    return await asyncio.to_thread(fn, *args);
}
