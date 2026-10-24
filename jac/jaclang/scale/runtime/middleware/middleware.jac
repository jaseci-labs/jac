obj Middleware {
    has name: str = "middleware",
        priority: int = 100,
        fn: any = None;

    async def handle(request: any, call_next: any) -> any;
}


obj MiddlewareRegistry {
    has middlewares: list[Middleware] = [];

    def register(middleware: Middleware);
    async def run(request: any, handler: any) -> any;
    async def _invoke(index: int, request: any, handler: any) -> any;
    def install(app: any);
}
