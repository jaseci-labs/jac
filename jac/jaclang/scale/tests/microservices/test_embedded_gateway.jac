import os;
import tempfile;


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
        lambda (payload: dict[str, any]) { {"order_id": payload.get("n", 0) * 10}; }
    );
    transport.register_walker(
        "products",
        "List",
        lambda (payload: dict[str, any]) { {
            "result": {"limit": 2},
            "reports": [{"items": ["a", "b"]}]
        }; }
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
    assert resp.json()["data"]
        == {"result": {"limit": 2}, "reports": [{"items": ["a", "b"]}]};
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


test "embedded gateway resolves dist and public/ files, and the SPA shell only for html navigations" {
    import shutil;
    project_root = tempfile.mkdtemp();
    dist = tempfile.mkdtemp();
    try {
        for (base, rel, data) in [
            (project_root, "public/brand/logo.png", b"PNG"),
            (dist, "app.js", b"BUNDLE"),
            (dist, "index.html", b"<title>spa-shell</title>")
        ] {
            os.makedirs(os.path.dirname(os.path.join(base, rel)), exist_ok=True);
            with open(os.path.join(base, rel), "wb") as f {
                f.write(data);
            }
        }
        client = TestClient(
            getattr(_make_gateway(dist=dist, base_path=project_root), "app")
        );
        # (path, accept, expected status, expected body fragment)
        for (path, accept, status, fragment) in [
            ("/app.js", "*/*", 200, b"BUNDLE"),
            ("/brand/logo.png", "image/png", 200, b"PNG"),
            ("/dashboard", "text/html", 200, b"spa-shell"),
            ("/missing.png", "image/png", 404, b"NOT_FOUND")
        ] {
            resp = client.get(path, headers={"accept": accept});
            assert resp.status_code == status and fragment in resp.content , (
                path,
                resp.status_code
            );
        }
    } finally {
        shutil.rmtree(project_root, ignore_errors=True);
        shutil.rmtree(dist, ignore_errors=True);
    }
}
