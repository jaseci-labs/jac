import asyncio;
import from jac_scale.runtime.middleware.middleware { Middleware, MiddlewareRegistry }


obj RecordingMiddleware(Middleware) {
    has recorder: list[str] = [];

    async def handle(request: any, call_next: any) -> any {
        self.recorder.append(f"enter:{self.name}");
        result = await call_next(request);
        self.recorder.append(f"exit:{self.name}");
        return result;
    }
}


obj ShortCircuitMiddleware(Middleware) {
    has response: str = "blocked";

    async def handle(request: any, call_next: any) -> any {
        return self.response;
    }
}


async def _handler(request: any) -> any {
    return "handler";
}


test "middlewares wrap the handler in onion order (lowest priority outermost)" {
    registry = MiddlewareRegistry();
    log: list[str] = [];
    registry.register(RecordingMiddleware(name="b", priority=20, recorder=log));
    registry.register(RecordingMiddleware(name="a", priority=10, recorder=log));
    result = asyncio.run(registry.run("req", _handler));
    assert result == "handler";
    assert log == ["enter:a", "enter:b", "exit:b", "exit:a"];
}


test "a middleware can short-circuit without running inner middleware or handler" {
    registry = MiddlewareRegistry();
    log: list[str] = [];
    registry.register(ShortCircuitMiddleware(name="gate", priority=5));
    registry.register(RecordingMiddleware(name="inner", priority=10, recorder=log));
    result = asyncio.run(registry.run("req", _handler));
    assert result == "blocked";
    assert log == [];
}
