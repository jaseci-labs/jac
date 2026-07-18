import from fastapi.testclient { TestClient }
import from jaclang.scale.runtime.gateway.embedded_gateway { EmbeddedGateway }
import from jaclang.scale.runtime.gateway.service_registry {
    ServiceRegistry,
    ServiceEntry
}
import from jaclang.scale.runtime.transport.transport { InProcessTransport }
import from jaclang.scale.runtime.middleware.middleware { Middleware }


def _make_gateway(dist: str = "/nonexistent-dist") -> EmbeddedGateway {
    reg = ServiceRegistry();
    reg.register(ServiceEntry(name="orders", file="orders.jac", prefix="/orders"));
    reg.register(
        ServiceEntry(name="products", file="products.jac", prefix="/products")
    );

    transport = InProcessTransport();
    transport.register_function(
        "orders",
        "create",
        lambda (payload: dict) { {"order_id": payload.get("n", 0) * 10}; }
    );
    transport.register_walker(
        "products", "List", lambda (payload: dict) { {"items": ["a", "b"]}; }
    );

    gw = EmbeddedGateway(registry=reg, transport=transport, client_dist_dir=dist);
    gw.setup();
    return gw;
}


test "a function member subpath is served by an in-process transport call" {
    gw = _make_gateway();
    client = TestClient(getattr(gw, "app"));
    resp = client.post("/orders/function/create", json={"n": 4});
    assert resp.status_code == 200;
    body = resp.json();
    assert body["ok"] == True;
    assert body["data"]["result"] == {"order_id": 40};
}


test "a walker member subpath is served by an in-process transport call" {
    gw = _make_gateway();
    client = TestClient(getattr(gw, "app"));
    resp = client.post("/products/walker/List", json={});
    assert resp.status_code == 200;
    assert resp.json()["data"]["result"] == {"items": ["a", "b"]};
}


test "an unregistered member surfaces a 404 envelope" {
    gw = _make_gateway();
    client = TestClient(getattr(gw, "app"));
    resp = client.post("/orders/function/missing", json={});
    assert resp.status_code == 404;
    assert resp.json()["error"]["code"] == "NOT_FOUND";
}


test "a bare service prefix falls through to static, never the transport" {
    gw = _make_gateway();
    client = TestClient(getattr(gw, "app"));
    resp = client.get("/orders");
    assert resp.status_code == 404;

    assert "Not found" in resp.json()["error"]["message"];
}


test "the shared middleware chain runs in front of the dispatcher" {
    gw = _make_gateway();
    hits: list[str] = [];

    obj _Audit(Middleware) {
        async def handle(request: any, call_next: any) -> any {
            hits.append("seen");
            return await call_next(request);
        }
    }

    gw.middleware.register(_Audit(name="audit", priority=10));

    gw.setup();
    client = TestClient(getattr(gw, "app"));
    client.post("/orders/function/create", json={"n": 1});
    assert "seen" in hits;
}
