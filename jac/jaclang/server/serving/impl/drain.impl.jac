impl DrainState.start(reason: str = 'shutdown') -> bool {
    if self.draining {
        return False;
    }
    self.draining = True;
    self.started_at = time.monotonic();
    self.reason = reason;
    logger.warning(f"drain: started ({reason}, budget {self.timeout:.1f}s)");
    return True;
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
