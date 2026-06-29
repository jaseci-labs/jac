import asyncio;
import from jaclang.scale.runtime.transport.transport { InProcessTransport }
import from jaclang.scale.runtime.middleware.middleware {
    Middleware,
    MiddlewareRegistry
}
import from jaclang.scale.runtime.gateway.dispatch {
    classify_route,
    ROUTE_PROXY,
    ROUTE_STATIC
}
import from jaclang.scale.runtime.planner.planner { plan_realization }


obj AuditMiddleware(Middleware) {
    has log: list[str] = [];

    async def handle(request: any, call_next: any) -> any {
        self.log.append(self.name);
        return await call_next(request);
    }
}


obj GateMiddleware(Middleware) {
    has blocked: dict[str, any] = {};

    async def handle(request: any, call_next: any) -> any {
        return self.blocked;
    }
}


def _make_handler(
    transport: InProcessTransport,
    prefix_to_service: dict[str, str],
    prefixes: list[str]
) -> any {
    async def handler(request: dict[str, any]) -> any {
        decision = classify_route(request["path"], prefixes);
        if decision.kind == ROUTE_PROXY {
            service = prefix_to_service[decision.service];
            return transport.call_function(
                service, request["function"], request["payload"]
            );
        }
        return {"served": "static"};
    }
    return handler;
}


test "request flows through middleware, classifies to a service, dispatches in-process" {
    transport = InProcessTransport();
    transport.register_function(
        "orders", "create", lambda payload: dict : {"order_id": payload["n"] * 10}
    );

    registry = MiddlewareRegistry();
    audit: list[str] = [];
    registry.register(AuditMiddleware(name="audit", priority=10, log=audit));

    handler = _make_handler(transport, {"/orders": "orders"}, ["/orders"]);
    request = {
        "path": "/orders/function/create",
        "function": "create",
        "payload": {"n": 4}
    };

    result = asyncio.run(registry.run(request, handler));
    assert result == {"order_id": 40};
    assert audit == ["audit"];
}


test "an unmatched path is served as static, never reaching the transport" {
    transport = InProcessTransport();
    reached: list[int] = [];
    transport.register_function(
        "orders", "create", lambda payload: dict : reached.append(1)
    );

    registry = MiddlewareRegistry();
    handler = _make_handler(transport, {"/orders": "orders"}, ["/orders"]);
    request = {"path": "/dashboard", "function": "create", "payload": {}};

    result = asyncio.run(registry.run(request, handler));
    assert result == {"served": "static"};
    assert reached == [];
}


test "a gate middleware short-circuits before the request reaches a service" {
    transport = InProcessTransport();
    reached: list[int] = [];
    transport.register_function(
        "orders", "create", lambda payload: dict : reached.append(1)
    );

    registry = MiddlewareRegistry();
    registry.register(
        GateMiddleware(name="ratelimit", priority=5, blocked={"error": "rate_limited"})
    );
    audit: list[str] = [];
    registry.register(AuditMiddleware(name="audit", priority=10, log=audit));

    handler = _make_handler(transport, {"/orders": "orders"}, ["/orders"]);
    request = {
        "path": "/orders/function/create",
        "function": "create",
        "payload": {"n": 1}
    };

    result = asyncio.run(registry.run(request, handler));
    assert result == {"error": "rate_limited"};
    assert reached == [];
    assert audit == [];
}


test "the plan for this monolith setup selects the in-process transport" {
    plan = plan_realization(False, 1);
    assert plan.transport == "in_process";
    assert plan.gateway_mode == "embedded";
}
