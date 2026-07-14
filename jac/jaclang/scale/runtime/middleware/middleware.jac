obj Middleware {
    has name: str = "middleware",
        priority: int = 100,
        fn: any = None;

    async def handle(request: any, call_next: any) -> any {
        if self.fn is not None {
            return await self.fn(request, call_next);
        }
        return await call_next(request);
    }
}


obj MiddlewareRegistry {
    has middlewares: list[Middleware] = [];

    def register(middleware: Middleware) {
        self.middlewares.append(middleware);
        self.middlewares.sort(key=lambda (item: Middleware) { item.priority; });
    }

    async def run(request: any, handler: any) -> any {
        return await self._invoke(0, request, handler);
    }

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

    def install(app: any) {
        import from starlette.middleware.base { BaseHTTPMiddleware }
        for middleware in reversed(self.middlewares) {
            app.add_middleware(BaseHTTPMiddleware, dispatch=middleware.handle);
        }
    }
}
