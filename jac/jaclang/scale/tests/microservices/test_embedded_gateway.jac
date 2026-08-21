import os;
import tempfile;
import from jaclang.runtimelib.serving.testing { ServingTestClient as TestClient }
import from jaclang.scale.runtime.gateway.embedded_gateway { EmbeddedGateway }
import from jaclang.scale.runtime.gateway.service_registry {
    ServiceRegistry,
    ServiceEntry
}
import from jaclang.scale.runtime.transport.transport { InProcessTransport }
import from jaclang.scale.runtime.middleware.middleware { Middleware }


def _make_gateway(
    dist: str = "/nonexistent-dist", base_path: str = "."
) -> EmbeddedGateway {
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

    gw = EmbeddedGateway(
        registry=reg, transport=transport, client_dist_dir=dist, base_path=base_path
    );
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


test "an embedded public/ asset is served at the web root (#8124 parity)" {
    import shutil;
    project_root = tempfile.mkdtemp();
    try {
        brand = os.path.join(project_root, "public", "brand");
        os.makedirs(brand, exist_ok=True);
        with open(os.path.join(brand, "logo.png"), "wb") as f {
            f.write(b"PNG_DATA");
        }

        gw = _make_gateway(base_path=project_root);
        client = TestClient(getattr(gw, "app"));
        resp = client.get("/brand/logo.png");
        assert resp.status_code == 200 , "public/brand/logo.png must resolve at /brand/logo.png";
        assert resp.content == b"PNG_DATA";
    } finally {
        shutil.rmtree(project_root, ignore_errors=True);
    }
}


test "resolution is split from the SPA fallback (resolve real files, index only for html navigations)" {
    import shutil;
    dist = tempfile.mkdtemp();
    try {
        with open(os.path.join(dist, "app.js"), "wb") as f {
            f.write(b"CONSOLE_LOG");
        }
        with open(os.path.join(dist, "index.html"), "w") as f {
            f.write("<!doctype html><title>spa-shell</title>");
        }

        gw = _make_gateway(dist=dist);
        client = TestClient(getattr(gw, "app"));

        # the resolver serves the physical dist file, not the SPA shell
        hit = client.get("/app.js");
        assert hit.status_code == 200;
        assert hit.content == b"CONSOLE_LOG";

        # an extensionless html navigation with no matching file falls through to index.html
        spa = client.get("/dashboard", headers={"accept": "text/html"});
        assert spa.status_code == 200;
        assert "spa-shell" in spa.text;

        # a non-html asset miss is an honest 404, never the SPA shell
        miss = client.get("/missing.png", headers={"accept": "image/png"});
        assert miss.status_code == 404;
        assert miss.json()["error"]["code"] == "NOT_FOUND";
    } finally {
        shutil.rmtree(dist, ignore_errors=True);
    }
}
