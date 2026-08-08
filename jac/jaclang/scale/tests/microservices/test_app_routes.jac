"""Gateway dispatch of app-declared routes (`@restspec(path=...)`) at the root.

The backend in these tests is a real jac API server (the restspec fixture app
served over a real socket), so the gateway learns routes from the exact
/openapi.json a deployed service publishes - nothing is stubbed.
"""

import tempfile;
import from pathlib { Path }
import from jaclang.scale.tests.scale_test_client { ScaleTestClient, make_client }
import from jaclang.scale.runtime.gateway.service_registry {
    ServiceRegistry,
    ServiceEntry,
    ServiceStatus
}
import from jaclang.scale.runtime.gateway.microservice_gateway { MicroserviceGateway }
import from jaclang.scale.runtime.gateway.route_table {
    ServiceRouteTable,
    literal_prefix
}


"""Serve the in-process jac app over a real socket; returns (server, port)."""
def _expose_backend(client: ScaleTestClient) -> tuple {
    import from jaclang.runtimelib.serving.server { ServingServer }
    server = ServingServer(app=client._server.server.app, host="127.0.0.1", port=0);
    server.serve_background();
    assert server.bound_port , "backend server did not start in time";
    return (server, server.bound_port);
}


def _gateway_for(port: int, dist_dir: str = "") -> MicroserviceGateway {
    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(
            name="main",
            file="main.jac",
            prefix="/main",
            port=port,
            url=f"http://127.0.0.1:{port}",
            status=ServiceStatus.HEALTHY
        )
    );
    kwargs: dict = {"registry": reg};
    if dist_dir {
        kwargs["client_dist_dir"] = dist_dir;
    }
    gw = MicroserviceGateway(**kwargs);
    gw.setup();
    return gw;
}


test "a root-level @restspec route reaches the real backend that declares it" {
    backend = make_client("restspec_fixtures.jac");
    (srv, port) = _expose_backend(backend);
    gw = _gateway_for(port);

    import from jaclang.runtimelib.serving.testing { ServingTestClient as TestClient }
    client = TestClient(gw.app);
    try {
        resp = client.get("/custom/walker");
        assert resp.status_code == 200 , (
            f"the backend declares GET /custom/walker via @restspec, so the "
            f"gateway must forward it instead of treating it as a missing "
            f"static asset; got {resp.status_code}"
        );
        body = resp.json();
        assert body["data"]["reports"][0]["path"] == "/custom/walker";

        assert gw.route_table.owner("/custom/walker") == "main";
    } finally {
        srv.request_stop();
        backend.close();
    }
}


test "a declared route wins over the SPA shell for a browser navigation" {
    backend = make_client("restspec_fixtures.jac");
    (srv, port) = _expose_backend(backend);

    tmp = tempfile.mkdtemp();
    (Path(tmp) / "index.html").write_text("<html>spa-shell</html>");
    gw = _gateway_for(port, dist_dir=tmp);

    import from jaclang.runtimelib.serving.testing { ServingTestClient as TestClient }
    client = TestClient(gw.app);
    try {
        resp = client.get("/custom/walker", headers={"Accept": "text/html"});
        assert resp.status_code == 200;
        assert "spa-shell" not in resp.text , (
            "a path a service declares belongs to that service, even when the "
            "browser would accept the SPA shell"
        );

        spa = client.get("/dashboard", headers={"Accept": "text/html"});
        assert spa.status_code == 200;
        assert "spa-shell" in spa.text , (
            "client-side routes no service declares still fall back to the SPA"
        );
    } finally {
        srv.request_stop();
        backend.close();
        import shutil;
        shutil.rmtree(tmp);
    }
}


test "static assets keep winning over a service's declared routes" {
    backend = make_client("restspec_fixtures.jac");
    (srv, port) = _expose_backend(backend);

    tmp = tempfile.mkdtemp();
    custom_dir = Path(tmp) / "custom";
    custom_dir.mkdir();
    (custom_dir / "walker").write_text("from-disk");
    gw = _gateway_for(port, dist_dir=tmp);

    import from jaclang.runtimelib.serving.testing { ServingTestClient as TestClient }
    client = TestClient(gw.app);
    try {
        resp = client.get("/custom/walker");
        assert resp.status_code == 200;
        assert resp.text == "from-disk" , (
            "a real file in the client bundle is the gateway's to serve, even "
            "when a service declares the same path"
        );
    } finally {
        srv.request_stop();
        backend.close();
        import shutil;
        shutil.rmtree(tmp);
    }
}


test "a path no service declares still 404s instead of fanning out" {
    backend = make_client("restspec_fixtures.jac");
    (srv, port) = _expose_backend(backend);
    gw = _gateway_for(port);

    import from jaclang.runtimelib.serving.testing { ServingTestClient as TestClient }
    client = TestClient(gw.app);
    try {
        resp = client.get("/custom/nope");
        assert resp.status_code == 404;
        assert resp.json()["error"]["code"] == "NOT_FOUND";
    } finally {
        srv.request_stop();
        backend.close();
    }
}


test "learning a real backend's spec keeps gateway-owned paths out of the table" {
    backend = make_client("restspec_fixtures.jac");
    (srv, port) = _expose_backend(backend);
    gw = _gateway_for(port);

    import from jaclang.runtimelib.serving.testing { ServingTestClient as TestClient }
    client = TestClient(gw.app);
    try {
        assert client.get("/custom/walker").status_code == 200;

        for owned in ["/user/login", "/user/me", "/healthz"] {
            assert gw.route_table.owner(owned) == "" , (
                f"the real backend publishes {owned} in its own OpenAPI - the "
                f"gateway must not hand its own surface to a service"
            );
        }
    } finally {
        srv.request_stop();
        backend.close();
    }
}


test "the route table matches templated paths on their literal head" {
    table = ServiceRouteTable();
    table.learn("orders", ["/api/orders/{order_id}", "/api/orders"]);

    assert table.owner("/api/orders") == "orders";
    assert table.owner("/api/orders/42") == "orders";
    assert table.owner("/api/ordersXX") == "" , (
        "prefix matching must respect segment boundaries"
    );
    assert table.owner("/api") == "";

    assert literal_prefix("/api/items/{item_id}/tags") == "/api/items";
    assert literal_prefix("/{full_path:path}") == "" , (
        "a catch-all template must not let a service claim every path"
    );
}


test "relearning a service replaces the routes it previously claimed" {
    table = ServiceRouteTable();
    table.learn("main", ["/api/old"]);
    assert table.owner("/api/old") == "main";

    table.learn("main", ["/api/new"]);
    assert table.owner("/api/new") == "main";
    assert table.owner("/api/old") == "" , (
        "a redeployed service must not keep owning routes it dropped"
    );
}


test "the first service to claim a path keeps it, and the clash is reported" {
    table = ServiceRouteTable();
    table.learn("orders", ["/api/shared"]);
    clashes = table.learn("cart", ["/api/shared", "/api/cart"]);

    assert table.owner("/api/shared") == "orders";
    assert table.owner("/api/cart") == "cart";
    assert clashes == ["/api/shared"];
}
