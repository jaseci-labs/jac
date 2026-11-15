impl SyncExecutor.install(loop: any) -> ThreadPoolExecutor {
    if self._pool is None {
        self._pool = ThreadPoolExecutor(
            max_workers=max(1, self.threads), thread_name_prefix='jac-sync'
        );
    }
    loop.set_default_executor(self._pool);
    return self._pool;
}

impl SyncExecutor.shutdown(`wait: bool = False) {
    pool = self._pool;
    self._pool = None;
    if pool is not None {
        pool.shutdown(`wait=`wait, cancel_futures=not `wait);
    }
}

impl run_sync(fn: Callable[..., any], *args: any) -> any {
    return await asyncio.to_thread(fn, *args);
}

impl iterate_sync(source: any) -> AsyncIterator[any] {
    iterator = await run_sync(iter, source);
    while True {
        item = await run_sync(next, iterator, _STREAM_STOP);
        if item is _STREAM_STOP {
            return;
        }
        yield item;
    }
}
