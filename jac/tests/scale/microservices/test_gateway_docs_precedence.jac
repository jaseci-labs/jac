"""When a fleet ships a client bundle, the client owns `/docs`.

The single server has always let client routes shadow its own convenience
pages: an extension-less, non-API path renders the SPA whether or not the
API docs page also answers there. The gateway classified `/docs` as a
wellknown builtin first, so a fleet with a client bundle served Swagger
where the app's docs reader was supposed to be, and a headless service
behind the gateway could leak its own Swagger through the app-route probe.
These tests pin the contract: with a client bundle `/docs` is a client
page (SPA on GET, nothing else on other methods, Swagger unreachable);
without one it stays the gateway's API docs page.
"""

import tempfile;
import from pathlib { Path }
import from jaclang.scale.runtime.gateway.service_registry { ServiceRegistry }
import from jaclang.scale.runtime.gateway.microservice_gateway { MicroserviceGateway }
import from jaclang.scale.runtime.gateway.dispatch {
    classify_route,
    ROUTE_BUILTIN,
    ROUTE_CLIENT_PAGE
}
import from jaclang.testing.testkit { ServingTestClient }


def _dist(with_index: bool) -> str {
    dist = Path(tempfile.mkdtemp()) / "dist";
    dist.mkdir(parents=True);
    if with_index {
        (dist / "index.html").write_text("<html><body>spa-shell</body></html>");
    }
    return str(dist);
}


def _client(with_index: bool) -> ServingTestClient {
    gw = MicroserviceGateway(
        registry=ServiceRegistry(), client_dist_dir=_dist(with_index)
    );
    gw.setup();
    return ServingTestClient(gw.app);
}


test "gateway docs: a shipped client bundle owns GET /docs without an Accept header" {
    resp = _client(True).get("/docs");
    assert resp.status_code == 200 , f"expected the SPA shell, got {resp.status_code}";
    assert "spa-shell" in resp.text , "GET /docs must serve the client index";
    assert "swagger" not in resp.text.lower() , (
        "the API docs page must be unreachable at /docs once a client ships"
    );
}


test "gateway docs: a browser page load of /docs gets the SPA when the client ships" {
    resp = _client(True).get("/docs", headers={"Accept": "text/html"});
    assert resp.status_code == 200;
    assert "spa-shell" in resp.text;
    assert "swagger" not in resp.text.lower();
}


test "gateway docs: a headless fleet keeps the API docs page at /docs" {
    resp = _client(False).get("/docs", headers={"Accept": "text/html"});
    assert resp.status_code == 200;
    assert "swagger" in resp.text.lower() , (
        "with no client bundle the gateway must keep serving its API docs page"
    );
    assert "spa-shell" not in resp.text;
}


test "gateway docs: a non-GET /docs serves neither the SPA nor the API docs page" {
    resp = _client(True).post("/docs");
    assert resp.status_code in (404, 405) , (
        f"a client-owned page has no non-GET behavior, got {resp.status_code}"
    );
    assert "spa-shell" not in resp.text;
    assert "swagger" not in resp.text.lower();
}


test "gateway docs: the classifier hands /docs to the client page when a client ships" {
    assert classify_route("/docs", [], client_pages=True).kind == ROUTE_CLIENT_PAGE;
    assert classify_route("/docs/", ["/orders"], client_pages=True).kind
        == ROUTE_CLIENT_PAGE;
}


test "gateway docs: without a client /docs stays a builtin, and machine endpoints always do" {
    assert classify_route("/docs", []).kind == ROUTE_BUILTIN;
    for path in ("/health", "/healthz", "/metrics", "/openapi.json") {
        assert classify_route(path, [], client_pages=True).kind == ROUTE_BUILTIN , (
            f"{path} is a machine endpoint; a client bundle must not shadow it"
        );
    }
}
