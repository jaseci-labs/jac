impl DrainState.start(reason: str = 'shutdown') -> bool {
    if self.draining {
        return False;
    }
    self.draining = True;
    self.started_at = time.monotonic();
    self.reason = reason;
    logger.warning(f"drain: started ({reason}, budget {self.timeout:.1f}s)");
    self.hooks_thread = _start_drain_hooks();
    return True;
}

impl _start_drain_hooks -> threading.Thread {
    thread = threading.Thread(
        target=_run_drain_hooks, name='jac-drain-hooks', daemon=True
    );
    thread.start();
    return thread;
}

impl _run_drain_hooks {
    hooks = list(DRAIN_HOOKS);
    DRAIN_HOOKS.clear();
    asyncio.run(run_hooks(hooks, "drain hook"));
}

impl run_hooks(hooks: list[Callable[..., any]], what: str) {
    for hook in hooks {
        try {
            result = hook();
            if inspect.isawaitable(result) {
                await result;
            }
        } except BaseException {
            logger.exception(f"{what} failed");
        }
    }
}

impl DrainState.wait_for_hooks {
    if self.hooks_thread is not None {
        self.hooks_thread.join(timeout=self.remaining());
    }
    if DRAIN_HOOKS {
        _start_drain_hooks().join(timeout=self.remaining());
    }
}

impl DrainState.remaining -> float {
    if not self.draining {
        return self.timeout;
    }
    return max(0.0, self.timeout - (time.monotonic() - self.started_at));
}

impl DrainState.reset {
    self.draining = False;
    self.started_at = 0.0;
    self.reason = '';
}

impl draining_response(service: str = 'service') -> Response {
    resp = JSONResponse(
        status_code=503,
        content={
            'ok': False,
            'error': {
                'code': 'SERVICE_UNAVAILABLE',
                'message': f"{service} is draining; retry against another instance"
            }
        }
    );
    resp.headers.set('Retry-After', '1');
    resp.headers.set('Connection', 'close');
    return resp;
}

impl drain_middleware(
    state: DrainState, service: str = 'service'
) -> Callable[..., any] {
    async def _middleware(request: Request, call_next: any) -> Response {
        next_fn: any = call_next;
        if request.url.path in HEALTH_PATHS or not state.draining {
            return await next_fn(request);
        }
        return draining_response(service);
    }
    return _middleware;
}
