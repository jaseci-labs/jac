"""The Middleware port and the registry that composes them.

Writing a middleware is one method: subclass `Middleware` and implement `handle`,
calling `call_next(request)` to continue the chain (or returning early to
short-circuit, e.g. a 429 from a rate limiter). Registering it is one call:
`registry.register(MyMiddleware())`. Lower `priority` runs further out (sees the
request first, the response last); equal priorities keep registration order.

The registry exposes a pure async `run()` for the chain so it is unit-testable
without a web server, and an `install()` that wires the same chain onto a FastAPI
app for the live gateway.
"""


"""One cross-cutting concern. Override `handle`; the default is a pass-through.

To adopt an existing `async (request, call_next)` middleware callable without
rewriting it, pass it as `fn`: the default `handle` delegates straight to it.
This lets the live gateway register its already-built drain / rate-limit
callables through the registry without changing their logic."""
obj Middleware {
    has name: str = "middleware",
        priority: int = 100,
        fn: any = None;

    """Process `request`, calling `call_next(request)` to continue the chain.
    Return a response directly to short-circuit without calling the rest.
    When wrapping an existing callable (`fn` set), delegate to it; the callable
    already has the `(request, call_next)` signature."""
    async def handle(request: any, call_next: any) -> any {
        if self.fn is not None {
            return await self.fn(request, call_next);
        }
        return await call_next(request);
    }
}


"""An ordered set of middlewares that compose into a single request pipeline."""
obj MiddlewareRegistry {
    has middlewares: list[Middleware] = [];

    """Register a middleware. Kept sorted by ascending priority (outermost first),
    with registration order preserved for equal priorities (stable sort)."""
    def register(middleware: Middleware) -> None {
        self.middlewares.append(middleware);
        self.middlewares.sort(key=lambda item: Middleware : item.priority);
    }

    """Run `request` through every registered middleware, then `handler`."""
    async def run(request: any, handler: any) -> any {
        return await self._invoke(0, request, handler);
    }

    """Invoke the middleware at `index`, giving it a call_next that advances to the
    next one (or to `handler` once the chain is exhausted)."""
    async def _invoke(index: int, request: any, handler: any) -> any {
        if index >= len(self.middlewares) {
            return await handler(request);
        }
        current = self.middlewares[index];

        async def call_next(next_request: any) -> any {
            return await self._invoke(index + 1, next_request, handler);
        }

        return await current.handle(request, call_next);
    }

    """Wire the same chain onto a FastAPI app. FastAPI runs the last-added
    middleware outermost, so we add in reverse priority order to keep the
    lowest-priority middleware outermost. Integration glue; covered by the e2e."""
    def install(app: any) -> None {
        import from starlette.middleware.base { BaseHTTPMiddleware }
        for middleware in reversed(self.middlewares) {
            app.add_middleware(BaseHTTPMiddleware, dispatch=middleware.handle);
        }
    }
}
