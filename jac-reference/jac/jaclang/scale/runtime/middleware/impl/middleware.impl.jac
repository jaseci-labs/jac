impl Middleware.handle(request: any, call_next: any) -> any {
    if self.fn is not None {
        return await self.fn(request, call_next);
    }
    return await call_next(request);
}

impl MiddlewareRegistry.register(middleware: Middleware) {
    self.middlewares.append(middleware);
    self.middlewares.sort(key=lambda (item: Middleware) { item.priority; });
}

impl MiddlewareRegistry.run(request: any, handler: any) -> any {
    return await self._invoke(0, request, handler);
}

impl MiddlewareRegistry._invoke(index: int, request: any, handler: any) -> any {
    if index >= len(self.middlewares) {
        return await handler(request);
    }
    current = self.middlewares[index];

    async def call_next(next_request: any) -> any {
        return await self._invoke(index + 1, next_request, handler);
    }

    return await current.handle(request, call_next);
}

impl MiddlewareRegistry.install(app: any) {
    for middleware in reversed(self.middlewares) {
        app.add_middleware(middleware.handle);
    }
}
