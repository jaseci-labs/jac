"""The gateway in a local fleet run must still serve the web app.

The served app is a fleet member like any other -- it just happens to be
the root member, the one that answers at the project root: the landing page,
`/cl/<page>`, the SPA shell for a client route, and
the generated `/static/client.js`. Before this, the gateway had no idea any
service played that role: `/` and `/docs/...` 404'd, and `/cl/app` was raced
across every service in registration order. These tests pin that the root
member owns the project root, and that no page request fans out.
"""

import shutil;
import tempfile;
import from pathlib { Path }
import from jaclang.server.serving.app { ServingApp }
import from jaclang.server.serving.datatypes { JSONResponse, Request, Response }
import from jaclang.server.serving.server { ServingServer }
import from jaclang.scale.runtime.gateway.microservice_gateway { MicroserviceGateway }
import from jaclang.scale.runtime.gateway.service_registry {
    ServiceEntry,
    ServiceRegistry,
    ServiceStatus
}
import from jaclang.testing.testkit { ServingTestClient }


"""Serve a marker backend that names itself in every response body."""
def _spawn_stub(
    name: str,
    spec_paths: list[str],
    seen: list[str],
    ready: list[bool],
    pages: list[str] | None = None
) -> tuple[Callable[[], None], int] {
    app = ServingApp(title=name);
    owned: list[str] = list(pages) if pages is not None else [];

    async def marker(request: Request, call_next: object) -> Response {
        path: str = request.url.path;
        seen.append(f"{name} {path}");
        if pages is not None and path.startswith("/cl/") {
            if path[len("/cl/"):] not in owned {
                return Response(content="no such page", status_code=404);
            }
        }
        if path == "/openapi.json" {
            if not ready[0] {
                return Response(content="not ready", status_code=404);
            }
            return JSONResponse(
                content={
                    "openapi": "3.0.2",
                    "paths": {p: {"get": {"responses": {}}} for p in spec_paths}
                }
            );
        }
        if path in ("/healthz", "/health") {
            return JSONResponse(content={"status": "healthy"});
        }
        return Response(content=f"{name} {path}", media_type="text/plain");
    }
    app.add_middleware(marker);
    server = ServingServer(app=app, host="127.0.0.1", port=0);
    srv_stop = server.serve_background();
    assert server.bound_port , f"stub service {name} did not bind a port";
    return (srv_stop, server.bound_port);
}


obj Fleet {
    has gateway: MicroserviceGateway,
        client: ServingTestClient,
        app_seen: list[str],
        peer_seen: list[str],
        peer: ServiceEntry,
        peer_ready: list[bool],
        _stops: list[Callable[[], None]],
        _dirs: list[str] = [];

    def close {
        for srv_stop in self._stops {
            srv_stop();
        }
        for d in self._dirs {
            shutil.rmtree(d, ignore_errors=True);
        }
    }
}


"""A two-service fleet: a peer service and the project's app service.

The peer registers first on purpose -- a gateway that guesses by asking
services in order would hand it the app's pages.
"""
def _fleet(
    peer_ready: bool = True, peer_status: ServiceStatus = ServiceStatus.HEALTHY
) -> Fleet {
    app_seen: list[str] = [];
    peer_seen: list[str] = [];
    peer_flag: list[bool] = [peer_ready];
    (peer_stop, peer_port) = _spawn_stub(
        "social_graph",
        ["/api/orders", "/static/{file_path}"],
        peer_seen,
        peer_flag,
        pages=["orders"]
    );
    (app_stop, app_port) = _spawn_stub(
        "main", ["/walker/ping", "/static/{file_path}"], app_seen, [True], pages=["app"]
    );

    dist_dir: str = tempfile.mkdtemp();
    base_dir: str = tempfile.mkdtemp();
    reg = ServiceRegistry();
    peer = ServiceEntry(
        name="social_graph",
        file="socialize/social_graph.jac",
        prefix="/social_graph",
        port=peer_port,
        url=f"http://127.0.0.1:{peer_port}",
        status=peer_status
    );
    reg.register(peer);
    reg.register(
        ServiceEntry(
            name="main",
            file="main.jac",
            prefix="/",
            port=app_port,
            url=f"http://127.0.0.1:{app_port}",
            status=ServiceStatus.HEALTHY,
            is_root=True,
            serves_client=True
        )
    );

    gw = MicroserviceGateway(
        registry=reg, client_dist_dir=dist_dir, base_path=base_dir
    );
    gw.setup();
    return Fleet(
        gateway=gw,
        client=ServingTestClient(gw.app),
        app_seen=app_seen,
        peer_seen=peer_seen,
        peer=peer,
        peer_ready=peer_flag,
        _stops=[peer_stop, app_stop]
    );
}


test "the landing page reaches the app service instead of 404ing" {
    fleet = _fleet();
    try {
        resp = fleet.client.get("/", headers={"Accept": "text/html"});
        assert resp.status_code == 200 , (
            "a web-app in microservice mode must still have a landing page; "
            f"got {resp.status_code}"
        );
        assert resp.text == "main /" , (
            f"the root app answers the project root; got {resp.text!r}"
        );
    } finally {
        fleet.close();
    }
}


test "a client page goes to the app service, not to whichever service answers first" {
    fleet = _fleet();
    try {
        resp = fleet.client.get("/cl/app");
        assert resp.status_code == 200;
        assert resp.text == "main /cl/app" , (
            f"/cl/<page> belongs to the app service; got {resp.text!r}"
        );
        assert "/cl/app" not in " ".join(fleet.peer_seen) , (
            "page requests must not be raced across every service - a service "
            "that is still compiling hangs the page"
        );
    } finally {
        fleet.close();
    }
}


test "a client-side route falls back to the app service's SPA shell" {
    fleet = _fleet();
    try {
        resp = fleet.client.get(
            "/docs/getting-started", headers={"Accept": "text/html"}
        );
        assert resp.status_code == 200;
        assert resp.text == "main /docs/getting-started" , (
            f"an unclaimed page path is the app's client route; got {resp.text!r}"
        );
    } finally {
        fleet.close();
    }
}


test "the generated client bundle is served by the app service" {
    fleet = _fleet();
    try {
        resp = fleet.client.get("/static/client.js");
        assert resp.status_code == 200;
        assert resp.text == "main /static/client.js" , (
            "/static/client.js is generated by the server, not a file on "
            f"disk, so the gateway must forward it; got {resp.text!r}"
        );
    } finally {
        fleet.close();
    }
}


test "the server-generated /static surface belongs to the app, not to whoever answers" {
    fleet = _fleet();
    try {
        assert fleet.gateway.route_table.owner("/static/client.js") == "" , (
            "every jac service publishes /static/{file_path}; letting one own "
            "the prefix hands the app's generated client.js to a headless peer"
        );
    } finally {
        fleet.close();
    }
}


test "a peer service still owns the routes it declares" {
    fleet = _fleet();
    try {
        resp = fleet.client.get("/api/orders");
        assert resp.status_code == 200;
        assert resp.text == "social_graph /api/orders" , (
            f"a declared root route beats the app fallback; got {resp.text!r}"
        );
        prefixed = fleet.client.get("/social_graph/walker/ping");
        assert prefixed.status_code == 200;
        assert prefixed.text == "social_graph /walker/ping" , (
            "a service's own prefix still reaches it with the prefix "
            f"stripped; got {prefixed.text!r}"
        );
    } finally {
        fleet.close();
    }
}


test "routes of a service that was still starting are learned once it is healthy" {
    fleet = _fleet(peer_ready=False, peer_status=ServiceStatus.STARTING);
    try {
        first = fleet.client.get("/api/orders");
        assert first.text == "main /api/orders" , (
            "while the peer cannot publish a spec its routes are unknown, so "
            "the app service answers"
        );

        fleet.peer_ready[0] = True;
        fleet.peer.status = ServiceStatus.HEALTHY;

        second = fleet.client.get("/api/orders");
        assert second.text == "social_graph /api/orders" , (
            "the gateway must re-ask a service that was still starting when "
            f"it first answered; got {second.text!r}"
        );
    } finally {
        fleet.close();
    }
}


test "in dev the pages come from the client dev server, the API from the service" {
    api_seen: list[str] = [];
    page_seen: list[str] = [];
    (api_stop, api_port) = _spawn_stub("main", ["/walker/ping"], api_seen, [True]);
    (page_stop, page_port) = _spawn_stub("vite", [], page_seen, [True]);

    dist_dir: str = tempfile.mkdtemp();
    base_dir: str = tempfile.mkdtemp();
    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(
            name="main",
            file="main.jac",
            prefix="/",
            port=api_port,
            page_port=page_port,
            url=f"http://127.0.0.1:{api_port}",
            page_url=f"http://127.0.0.1:{page_port}",
            status=ServiceStatus.HEALTHY,
            is_root=True,
            serves_client=True
        )
    );
    gw = MicroserviceGateway(
        registry=reg, client_dist_dir=dist_dir, base_path=base_dir
    );
    gw.setup();
    client = ServingTestClient(gw.app);
    page_stopped: bool = False;
    try {
        landing = client.get("/", headers={"Accept": "text/html"});
        assert landing.text == "vite /" , (
            "the dev client server owns the page, so HMR works; got "
            f"{landing.text!r}"
        );
        assert client.get("/cl/app").text == "vite /cl/app";

        api_call = client.post("/walker/ping");
        assert api_call.text == "main /walker/ping" , (
            "walker traffic goes straight to the service, not through the "
            f"page server; got {api_call.text!r}"
        );

        page_stop();
        page_stopped = True;
        fallen_back = client.get("/", headers={"Accept": "text/html"});
        assert fallen_back.text == "main /" , (
            "a dead client dev server costs HMR, not the site: the service "
            f"renders the page itself; got {fallen_back.text!r}"
        );
    } finally {
        api_stop();
        if not page_stopped {
            page_stop();
        }
        shutil.rmtree(dist_dir, ignore_errors=True);
        shutil.rmtree(base_dir, ignore_errors=True);
    }
}


test "a deployed gateway keeps its own shell: is_root alone does not own the root" {
    app_seen: list[str] = [];
    (srv_stop, port) = _spawn_stub("main", ["/walker/ping"], app_seen, [True]);
    dist_dir: str = tempfile.mkdtemp();
    base_dir: str = tempfile.mkdtemp();
    (Path(dist_dir) / "index.html").write_text("<html>staged-shell</html>");

    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(
            name="main",
            file="main.jac",
            prefix="/",
            port=port,
            url=f"http://127.0.0.1:{port}",
            status=ServiceStatus.HEALTHY,
            is_root=True,
            serves_client=False
        )
    );
    gw = MicroserviceGateway(
        registry=reg, client_dist_dir=dist_dir, base_path=base_dir
    );
    gw.setup();
    client = ServingTestClient(gw.app);
    try {
        landing = client.get("/", headers={"Accept": "text/html"});
        assert "staged-shell" in landing.text , (
            "a fleet pod serves the client bundle its image staged; only a "
            f"service that serves the client owns the root; got {landing.text!r}"
        );
        assert "main /" not in landing.text;
    } finally {
        srv_stop();
        shutil.rmtree(dist_dir, ignore_errors=True);
        shutil.rmtree(base_dir, ignore_errors=True);
    }
}


test "a client page the app does not have still reaches the service that does" {
    fleet = _fleet();
    try {
        resp = fleet.client.get("/cl/orders");
        assert resp.status_code == 200;
        assert resp.text == "social_graph /cl/orders" , (
            "/cl is a discovery family: the app is asked first, and a page it "
            "does not serve still falls through to the peer that does; got "
            f"{resp.text!r}"
        );
    } finally {
        fleet.close();
    }
}


test "an app service that cannot take traffic falls back to the shell, not a 503" {
    dist_dir: str = tempfile.mkdtemp();
    base_dir: str = tempfile.mkdtemp();
    (Path(dist_dir) / "index.html").write_text("<html>spa-shell</html>");

    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(
            name="main",
            file="main.jac",
            prefix="/",
            port=1,
            url="http://127.0.0.1:1",
            status=ServiceStatus.UNHEALTHY,
            is_root=True,
            serves_client=True
        )
    );
    gw = MicroserviceGateway(
        registry=reg, client_dist_dir=dist_dir, base_path=base_dir
    );
    gw.setup();
    client = ServingTestClient(gw.app);
    try {
        resp = client.get("/", headers={"Accept": "text/html"});
        assert resp.status_code == 200 , (
            "an app that is not accepting traffic must not cost the gateway "
            f"the static shell it can still serve; got {resp.status_code}"
        );
        assert "spa-shell" in resp.text;
    } finally {
        shutil.rmtree(dist_dir, ignore_errors=True);
        shutil.rmtree(base_dir, ignore_errors=True);
    }
}

test "a static miss on a deployed gateway reaches the app service" {
    app_seen: list[str] = [];
    (srv_stop, port) = _spawn_stub(
        "main", ["/walker/ping", "/static/{file_path}"], app_seen, [True]
    );
    dist_dir: str = tempfile.mkdtemp();
    base_dir: str = tempfile.mkdtemp();
    (Path(dist_dir) / "index.html").write_text("<html>staged-shell</html>");

    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(
            name="main",
            file="main.jac",
            prefix="/",
            port=port,
            url=f"http://127.0.0.1:{port}",
            status=ServiceStatus.HEALTHY,
            is_root=True,
            serves_client=False
        )
    );
    gw = MicroserviceGateway(
        registry=reg, client_dist_dir=dist_dir, base_path=base_dir
    );
    gw.setup();
    client = ServingTestClient(gw.app);
    try {
        asset = client.get("/static/client.js");
        assert asset.text == "main /static/client.js" , (
            "an asset the image did not stage comes from the app service, "
            f"which publishes /static; got {asset.status_code} {asset.text!r}"
        );
        assert "main /static/client.js" in app_seen;
        landing = client.get("/", headers={"Accept": "text/html"});
        assert "staged-shell" in landing.text , (
            "the static fallback does not hand the root to a service that "
            f"does not serve the client; got {landing.text!r}"
        );
    } finally {
        srv_stop();
        shutil.rmtree(dist_dir, ignore_errors=True);
        shutil.rmtree(base_dir, ignore_errors=True);
    }
}
