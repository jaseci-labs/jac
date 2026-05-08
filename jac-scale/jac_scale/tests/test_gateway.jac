"""Tests for microservices MicroserviceGateway."""

import os;
import tempfile;
import from pathlib { Path }
import from typing { Any }
import from jac_scale.microservices.service_registry {
    ServiceRegistry,
    ServiceEntry,
    ServiceStatus
}
import from jac_scale.microservices.gateway { MicroserviceGateway }

# =============================================================================
# resolve_target_url
# =============================================================================
test "resolve strips prefix and preserves walker path" {
    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(
            name="orders",
            file="orders.jac",
            prefix="/api/orders",
            port=8001,
            url="http://127.0.0.1:8001",
            status=ServiceStatus.HEALTHY
        )
    );
    gw = MicroserviceGateway(registry=reg);

    svc = reg.entries["orders"];
    url = gw.resolve_target_url(svc, "/api/orders/walker/list_orders", "");
    assert url == "http://127.0.0.1:8001/walker/list_orders";
}

test "resolve strips prefix and preserves function path" {
    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(
            name="orders",
            file="orders.jac",
            prefix="/api/orders",
            port=8001,
            url="http://127.0.0.1:8001",
            status=ServiceStatus.HEALTHY
        )
    );
    gw = MicroserviceGateway(registry=reg);

    svc = reg.entries["orders"];
    url = gw.resolve_target_url(svc, "/api/orders/function/get_total", "");
    assert url == "http://127.0.0.1:8001/function/get_total";
}

test "resolve appends query string" {
    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(
            name="orders",
            file="orders.jac",
            prefix="/api/orders",
            port=8001,
            url="http://127.0.0.1:8001",
            status=ServiceStatus.HEALTHY
        )
    );
    gw = MicroserviceGateway(registry=reg);

    svc = reg.entries["orders"];
    url = gw.resolve_target_url(svc, "/api/orders/walker/list", "limit=10");
    assert url == "http://127.0.0.1:8001/walker/list?limit=10";
}

test "resolve exact prefix returns root" {
    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(
            name="orders",
            file="orders.jac",
            prefix="/api/orders",
            port=8001,
            url="http://127.0.0.1:8001",
            status=ServiceStatus.HEALTHY
        )
    );
    gw = MicroserviceGateway(registry=reg);

    svc = reg.entries["orders"];
    url = gw.resolve_target_url(svc, "/api/orders", "");
    assert url == "http://127.0.0.1:8001/";
}

test "resolve no query string omits question mark" {
    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(
            name="orders",
            file="orders.jac",
            prefix="/api/orders",
            port=8001,
            url="http://127.0.0.1:8001",
            status=ServiceStatus.HEALTHY
        )
    );
    gw = MicroserviceGateway(registry=reg);

    svc = reg.entries["orders"];
    url = gw.resolve_target_url(svc, "/api/orders/walker/list", "");
    assert "?" not in url;
}

# =============================================================================
# get_sv_registry hookspec dispatch (ROADMAP P3)
# =============================================================================
test "resolve_target_url prefers the sv_registry URL over service_entry.url" {
    # Simulates KubernetesDeployer: the registry says the service lives
    # somewhere that differs from whatever our local ServiceEntry knows.
    # Gateway MUST honor the registry (the hookspec) - otherwise K8s DNS
    # URLs would be ignored and local loopback would win.
    import from jaclang.runtimelib { sv_client }

    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(
            name="orders",
            file="orders.jac",
            prefix="/api/orders",
            port=8001,
            url="http://127.0.0.1:8001",
            status=ServiceStatus.HEALTHY
        )
    );
    gw = MicroserviceGateway(registry=reg);

    sv_client.register("orders", "http://override.test.local:9999");
    try {
        svc = reg.entries["orders"];
        url = gw.resolve_target_url(svc, "/api/orders/walker/list", "");
        assert url == "http://override.test.local:9999/walker/list";
    } finally {
        sv_client.unregister("orders");
    }
}

test "resolve_target_url falls back to service_entry.url when sv_registry has no entry" {
    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(
            name="orders",
            file="orders.jac",
            prefix="/api/orders",
            port=8001,
            url="http://127.0.0.1:8001",
            status=ServiceStatus.HEALTHY
        )
    );
    gw = MicroserviceGateway(registry=reg);

    svc = reg.entries["orders"];
    # sv_client registry has nothing for "orders"; fallback must kick in
    url = gw.resolve_target_url(svc, "/api/orders/walker/list", "");
    assert url == "http://127.0.0.1:8001/walker/list";
}

test "JacRuntime.get_sv_registry returns a snapshot, not a live view" {
    # Default core impl returns dict(sv_client._registry). Mutating the
    # returned dict must not leak into the real registry, or future
    # KubernetesDeployer hookimpls that do expensive DNS lookups per call
    # would become a cache-coherency problem.
    import jaclang;
    import from jaclang.runtimelib { sv_client }

    sv_client.register("snapshot_test", "http://a.test:1");
    try {
        snap = jaclang.JacRuntime.get_sv_registry();
        assert snap.get("snapshot_test") == "http://a.test:1";
        snap["snapshot_test"] = "http://mutated.test:2";
        # Real registry unchanged
        fresh = jaclang.JacRuntime.get_sv_registry();
        assert fresh.get("snapshot_test") == "http://a.test:1";
    } finally {
        sv_client.unregister("snapshot_test");
    }
}

# =============================================================================
# Setup
# =============================================================================
test "setup creates fastapi app" {
    reg = ServiceRegistry();
    gw = MicroserviceGateway(registry=reg);
    app = gw.setup();
    assert app is not None;
    assert gw.app is not None;
}

# =============================================================================
# Routing via TestClient
# =============================================================================
test "health endpoint returns service summary" {
    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(
            name="orders",
            file="orders.jac",
            prefix="/api/orders",
            port=8001,
            url="http://127.0.0.1:8001",
            status=ServiceStatus.HEALTHY
        )
    );
    gw = MicroserviceGateway(registry=reg);
    gw.setup();

    import from fastapi.testclient { TestClient }
    client = TestClient(gw.app);
    resp = client.get("/health");
    assert resp.status_code == 200;
    data = resp.json();
    assert data["status"] == "healthy";
    assert "orders" in data["services"];
}

test "unmatched path returns 404" {
    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(
            name="orders",
            file="orders.jac",
            prefix="/api/orders",
            port=8001,
            url="http://127.0.0.1:8001",
            status=ServiceStatus.HEALTHY
        )
    );
    gw = MicroserviceGateway(registry=reg);
    gw.setup();

    import from fastapi.testclient { TestClient }
    client = TestClient(gw.app);
    resp = client.get("/api/unknown/walker/thing");
    assert resp.status_code == 404;
}

# =============================================================================
# Prometheus metrics (ROADMAP P8)
# =============================================================================
test "build_gateway_metrics returns a fresh registry with both collectors" {
    import from jac_scale.microservices._metrics { build_gateway_metrics }
    (registry, requests, duration) = build_gateway_metrics();
    assert registry is not None;
    assert requests is not None;
    assert duration is not None;
}

test "classify_outcome maps status codes to label values" {
    import from jac_scale.microservices._metrics { classify_outcome }
    assert classify_outcome(200) == "2xx";
    assert classify_outcome(302) == "3xx";
    assert classify_outcome(404) == "4xx";
    assert classify_outcome(503) == "5xx";
    assert classify_outcome(0) == "err";
}

test "gateway /metrics returns Prometheus exposition after a request" {
    reg = ServiceRegistry();
    gw = MicroserviceGateway(registry=reg);
    gw.setup();

    import from fastapi.testclient { TestClient }
    client = TestClient(gw.app);

    # Make one request so the counter observes a sample
    client.get("/health");

    resp = client.get("/metrics");
    assert resp.status_code == 200;
    body = resp.text;
    # Counter + Histogram should both appear in the exposition
    assert "jac_scale_gateway_requests_total" in body;
    assert "jac_scale_gateway_request_duration_seconds" in body;
    # /health request should have been recorded under the __health__ label
    assert "__health__" in body;
}

# =============================================================================
# Standardized error envelope + graceful degradation (ROADMAP P10)
# =============================================================================
test "service-down returns standardized envelope with SERVICE_UNAVAILABLE + Retry-After" {
    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(
            name="orders",
            file="orders.jac",
            prefix="/api/orders",
            port=8001,
            url="http://127.0.0.1:8001",
            status=ServiceStatus.STOPPED
        )
    );
    gw = MicroserviceGateway(registry=reg);
    gw.setup();

    import from fastapi.testclient { TestClient }
    client = TestClient(gw.app);
    resp = client.get("/api/orders/walker/list");

    assert resp.status_code == 503;
    body = resp.json();
    assert body["ok"] is False;
    assert body["error"]["code"] == "SERVICE_UNAVAILABLE";
    assert body["error"]["service"] == "orders";
    assert body["meta"]["http_status"] == 503;
    # Retry-After lets well-behaved clients back off
    assert resp.headers.get("retry-after") == "2";
}

test "service-timeout returns GATEWAY_TIMEOUT (502) without Retry-After" {
    # Healthy in our registry, but the port isn't actually listening -
    # raw_forward returns None so we emit a 502. Unlike 503, we do NOT
    # advertise Retry-After for 502s: a deterministic transport error
    # on the same request won't change on retry.
    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(
            name="orders",
            file="orders.jac",
            prefix="/api/orders",
            port=8001,
            url="http://127.0.0.1:8001",
            status=ServiceStatus.HEALTHY
        )
    );
    gw = MicroserviceGateway(registry=reg);
    gw.setup();

    import from fastapi.testclient { TestClient }
    client = TestClient(gw.app);
    resp = client.get("/api/orders/walker/list");

    assert resp.status_code == 502;
    body = resp.json();
    assert body["error"]["code"] == "GATEWAY_TIMEOUT";
    assert body["error"]["service"] == "orders";
    assert resp.headers.get("retry-after") is None;
}

test "unmatched path returns NOT_FOUND envelope" {
    reg = ServiceRegistry();
    gw = MicroserviceGateway(registry=reg);
    gw.setup();

    import from fastapi.testclient { TestClient }
    client = TestClient(gw.app);
    resp = client.get("/this/does/not/match");

    assert resp.status_code == 404;
    body = resp.json();
    assert body["ok"] is False;
    assert body["error"]["code"] == "NOT_FOUND";
    # The requested path appears in the message so operators can diagnose
    assert "/this/does/not/match" in body["error"]["message"];
}

test "error envelope carries the request's trace id for correlation" {
    reg = ServiceRegistry();
    gw = MicroserviceGateway(registry=reg);
    gw.setup();

    import from fastapi.testclient { TestClient }
    client = TestClient(gw.app);
    resp = client.get(
        "/this/does/not/match", headers={"X-Trace-Id": "trace-for-error-corr"}
    );
    assert resp.status_code == 404;
    body = resp.json();
    assert body["error"]["trace_id"] == "trace-for-error-corr";
}

# =============================================================================
# Unified /docs Swagger aggregation (ROADMAP P9)
# =============================================================================
test "_prefixed_paths prepends the service prefix to every key" {
    import from jac_scale.microservices._openapi_agg { _prefixed_paths }
    raw = {
        "/function/list_products": {"post": {"summary": "list"}},
        "/function/get_product": {"post": {"summary": "get"}}
    };
    out = _prefixed_paths(raw, "/api/products");
    assert "/api/products/function/list_products" in out;
    assert "/api/products/function/get_product" in out;
    # Originals gone
    assert "/function/list_products" not in out;
}

test "_prefixed_paths handles prefix with trailing slash" {
    import from jac_scale.microservices._openapi_agg { _prefixed_paths }
    out = _prefixed_paths(
        {"/function/x": {"post": {}}}, "/api/products/"  # trailing slash
    );
    # rstrip('/') normalizes -> no double slash in output
    assert "/api/products/function/x" in out;
}

test "gateway /docs returns Swagger HTML pointing at /openapi.json" {
    reg = ServiceRegistry();
    gw = MicroserviceGateway(registry=reg);
    gw.setup();

    import from fastapi.testclient { TestClient }
    client = TestClient(gw.app);
    resp = client.get("/docs");
    assert resp.status_code == 200;
    body = resp.text;
    assert "swagger-ui" in body.lower() or "Swagger" in body;
    assert "/openapi.json" in body;
}

test "gateway /openapi.json returns a minimal doc when no services reachable" {
    # Registry has a service entry but its URL points nowhere; the
    # aggregator skips it gracefully and we still get a document back
    # with the gateway's own /health + /metrics paths.
    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(
            name="unreachable",
            file="x.jac",
            prefix="/api/x",
            port=9,
            url="http://127.0.0.1:9",
            status=ServiceStatus.HEALTHY  # marked healthy, but not actually up
        )
    );
    gw = MicroserviceGateway(registry=reg);
    gw.setup();

    import from fastapi.testclient { TestClient }
    client = TestClient(gw.app);
    resp = client.get("/openapi.json");
    assert resp.status_code == 200;
    doc = resp.json();
    assert doc["openapi"].startswith("3.");
    # Gateway paths always present
    assert "/health" in doc["paths"];
    assert "/metrics" in doc["paths"];
}

test "gateway /openapi.json is its own route - not proxied to a service" {
    # Pre-P9 /openapi.json fell through to handle_builtin_passthrough.
    # With aggregation, /openapi.json is dispatched directly.
    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(
            name="orders",
            file="orders.jac",
            prefix="/api/orders",
            port=8001,
            url="http://127.0.0.1:8001",
            status=ServiceStatus.HEALTHY
        )
    );
    gw = MicroserviceGateway(registry=reg);
    gw.setup();

    import from fastapi.testclient { TestClient }
    client = TestClient(gw.app);
    resp = client.get("/openapi.json");
    # Must return 200 with a document, NOT 502/404 from trying to
    # passthrough to the (unreachable) orders service.
    assert resp.status_code == 200;
    assert resp.json().get("openapi", "").startswith("3.");
}

test "gateway /metrics is its own route - not proxied to a service" {
    # Before P8, /metrics fell through to handle_builtin_passthrough.
    # With gateway-level metrics, /metrics is dispatched directly.
    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(
            name="orders",
            file="orders.jac",
            prefix="/api/orders",
            port=8001,
            url="http://127.0.0.1:8001",
            status=ServiceStatus.HEALTHY
        )
    );
    gw = MicroserviceGateway(registry=reg);
    gw.setup();

    import from fastapi.testclient { TestClient }
    client = TestClient(gw.app);
    resp = client.get("/metrics");
    # Must succeed (200) without attempting a service passthrough;
    # a pre-P8 gateway would 502 here (orders service unreachable).
    assert resp.status_code == 200;
    assert "jac_scale_gateway_requests_total" in resp.text;
}

test "unhealthy service returns 503" {
    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(
            name="orders",
            file="orders.jac",
            prefix="/api/orders",
            port=8001,
            url="http://127.0.0.1:8001",
            status=ServiceStatus.UNHEALTHY
        )
    );
    gw = MicroserviceGateway(registry=reg);
    gw.setup();

    import from fastapi.testclient { TestClient }
    client = TestClient(gw.app);
    resp = client.get("/api/orders/walker/list");
    assert resp.status_code == 503;
}

test "stopped service returns 503" {
    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(
            name="orders",
            file="orders.jac",
            prefix="/api/orders",
            port=8001,
            url="http://127.0.0.1:8001",
            status=ServiceStatus.STOPPED
        )
    );
    gw = MicroserviceGateway(registry=reg);
    gw.setup();

    import from fastapi.testclient { TestClient }
    client = TestClient(gw.app);
    resp = client.get("/api/orders/walker/list");
    assert resp.status_code == 503;
}

test "empty registry returns 404" {
    reg = ServiceRegistry();
    gw = MicroserviceGateway(registry=reg);
    gw.setup();

    import from fastapi.testclient { TestClient }
    client = TestClient(gw.app);
    resp = client.get("/api/anything/walker/test");
    assert resp.status_code == 404;
}

# =============================================================================
# Static file serving
# =============================================================================
test "serve static returns file with correct mime type" {
    tmp = tempfile.mkdtemp();
    assets_dir = Path(tmp) / "assets";
    assets_dir.mkdir();
    js_file = assets_dir / "app.js";
    js_file.write_text("console.log('hello');");

    reg = ServiceRegistry();
    gw = MicroserviceGateway(registry=reg, client_dist_dir=tmp);

    resp = gw.serve_static("assets/app.js");
    assert resp is not None;
    assert "javascript" in resp.media_type;
    assert b"hello" in resp.body;

    # Cleanup
    import shutil;
    shutil.rmtree(tmp);
}

test "serve static returns none for missing file" {
    tmp = tempfile.mkdtemp();

    reg = ServiceRegistry();
    gw = MicroserviceGateway(registry=reg, client_dist_dir=tmp);

    resp = gw.serve_static("nonexistent.js");
    assert resp is None;

    import shutil;
    shutil.rmtree(tmp);
}

test "serve static blocks path traversal" {
    tmp = tempfile.mkdtemp();

    reg = ServiceRegistry();
    gw = MicroserviceGateway(registry=reg, client_dist_dir=tmp);

    resp = gw.serve_static("../../etc/passwd");
    assert resp is None;

    import shutil;
    shutil.rmtree(tmp);
}

test "serve static css file returns text content type" {
    tmp = tempfile.mkdtemp();
    css_file = Path(tmp) / "style.css";
    css_file.write_text("body { color: red; }");

    reg = ServiceRegistry();
    gw = MicroserviceGateway(registry=reg, client_dist_dir=tmp);

    resp = gw.serve_static("style.css");
    assert resp is not None;
    assert resp.media_type == "text/css";

    import shutil;
    shutil.rmtree(tmp);
}

# =============================================================================
# static_mounts — declarative extra static directories
# =============================================================================
test "serve_extra_static serves a file from a configured local dir" {
    tmp = tempfile.mkdtemp();
    assets = Path(tmp) / "assets";
    assets.mkdir();
    (assets / "logo.png").write_bytes(b"PNG_DATA");

    reg = ServiceRegistry();
    gw = MicroserviceGateway(registry=reg, client_dist_dir=tmp);

    resp = gw.serve_extra_static(str(assets), "logo.png");
    assert resp is not None;
    assert b"PNG_DATA" in resp.body;
    assert "image/png" in resp.media_type;

    import shutil;
    shutil.rmtree(tmp);
}

test "serve_extra_static returns None when local_dir is empty" {
    reg = ServiceRegistry();
    gw = MicroserviceGateway(registry=reg);

    resp = gw.serve_extra_static("", "anything.txt");
    assert resp is None;
}

test "serve_extra_static returns None for missing file" {
    tmp = tempfile.mkdtemp();
    reg = ServiceRegistry();
    gw = MicroserviceGateway(registry=reg);

    resp = gw.serve_extra_static(tmp, "nonexistent.png");
    assert resp is None;

    import shutil;
    shutil.rmtree(tmp);
}

test "serve_extra_static blocks path traversal escape" {
    tmp = tempfile.mkdtemp();
    assets = Path(tmp) / "assets";
    assets.mkdir();
    # Create a file outside the jail; the test should not be able to read it.
    secret = Path(tmp) / "secret.txt";
    secret.write_text("classified");

    reg = ServiceRegistry();
    gw = MicroserviceGateway(registry=reg);

    resp = gw.serve_extra_static(str(assets), "../secret.txt");
    assert resp is None;

    import shutil;
    shutil.rmtree(tmp);
}

test "static_mounts wins over dist_dir for matching URL" {
    tmp = tempfile.mkdtemp();
    dist = Path(tmp) / "dist";
    dist.mkdir();
    assets = Path(tmp) / "assets";
    assets.mkdir();
    (assets / "logo.png").write_bytes(b"FROM_MOUNT");
    # A same-named file under dist would only be reached if static_mounts
    # was ignored — the test asserts the mount wins.
    (dist / "static" / "assets").mkdir(parents=True);
    (dist / "static" / "assets" / "logo.png").write_bytes(b"FROM_DIST");

    reg = ServiceRegistry();
    gw = MicroserviceGateway(
        registry=reg,
        client_dist_dir=str(dist),
        static_mounts=[{"url_prefix": "/static/assets", "local_path": str(assets)}]
    );
    gw.setup();

    import from fastapi.testclient { TestClient }
    client = TestClient(gw.app);

    resp = client.get("/static/assets/logo.png");
    assert resp.status_code == 200;
    assert resp.content == b"FROM_MOUNT";

    import shutil;
    shutil.rmtree(tmp);
}

test "static_mounts dispatch falls through to dist_dir for non-matching URL" {
    tmp = tempfile.mkdtemp();
    dist = Path(tmp) / "dist";
    dist.mkdir();
    (dist / "vendor.js").write_text("/* vendor bundle */");

    reg = ServiceRegistry();
    gw = MicroserviceGateway(
        registry=reg,
        client_dist_dir=str(dist),
        static_mounts=[{"url_prefix": "/static/assets", "local_path": "/nonexistent"}]
    );
    gw.setup();

    import from fastapi.testclient { TestClient }
    client = TestClient(gw.app);

    # /vendor.js doesn't match the /static/assets mount prefix, so it
    # falls through to dist_dir.
    resp = client.get("/vendor.js");
    assert resp.status_code == 200;
    assert "javascript" in resp.headers.get("content-type", "");

    import shutil;
    shutil.rmtree(tmp);
}

test "matched static_mount with missing file does not fall back to dist" {
    tmp = tempfile.mkdtemp();
    dist = Path(tmp) / "dist";
    dist.mkdir();
    # If we DID fall back, the gateway would find this file at the same
    # URL — the test asserts mounts have canonical ownership of their
    # prefix, so a 404 is preferred over silently serving from dist.
    (dist / "static" / "assets").mkdir(parents=True);
    (dist / "static" / "assets" / "logo.png").write_bytes(b"FROM_DIST");
    assets = Path(tmp) / "assets";
    assets.mkdir();  # empty — no logo.png here

    reg = ServiceRegistry();
    gw = MicroserviceGateway(
        registry=reg,
        client_dist_dir=str(dist),
        static_mounts=[{"url_prefix": "/static/assets", "local_path": str(assets)}]
    );
    gw.setup();

    import from fastapi.testclient { TestClient }
    client = TestClient(gw.app);

    resp = client.get("/static/assets/logo.png");
    assert resp.status_code == 404;

    import shutil;
    shutil.rmtree(tmp);
}

# =============================================================================
# SPA fallback
# =============================================================================
test "spa fallback serves index.html" {
    tmp = tempfile.mkdtemp();
    index = Path(tmp) / "index.html";
    index.write_text("<html><body>SPA</body></html>");

    reg = ServiceRegistry();
    gw = MicroserviceGateway(registry=reg, client_dist_dir=tmp);

    resp = gw.serve_spa_fallback();
    assert resp is not None;
    assert b"SPA" in resp.body;

    import shutil;
    shutil.rmtree(tmp);
}

test "spa fallback returns none when no index.html" {
    tmp = tempfile.mkdtemp();

    reg = ServiceRegistry();
    gw = MicroserviceGateway(registry=reg, client_dist_dir=tmp);

    resp = gw.serve_spa_fallback();
    assert resp is None;

    import shutil;
    shutil.rmtree(tmp);
}

# =============================================================================
# Static + SPA via TestClient (integration)
# =============================================================================
test "gateway serves static files for unmatched paths" {
    tmp = tempfile.mkdtemp();
    assets_dir = Path(tmp) / "assets";
    assets_dir.mkdir();
    (assets_dir / "app.js").write_text("var x = 1;");

    reg = ServiceRegistry();
    gw = MicroserviceGateway(registry=reg, client_dist_dir=tmp);
    gw.setup();

    import from fastapi.testclient { TestClient }
    client = TestClient(gw.app);
    resp = client.get("/assets/app.js");
    assert resp.status_code == 200;
    assert "var x = 1" in resp.text;

    import shutil;
    shutil.rmtree(tmp);
}

test "gateway serves spa fallback for html navigation" {
    tmp = tempfile.mkdtemp();
    (Path(tmp) / "index.html").write_text("<html>SPA App</html>");

    reg = ServiceRegistry();
    gw = MicroserviceGateway(registry=reg, client_dist_dir=tmp);
    gw.setup();

    import from fastapi.testclient { TestClient }
    client = TestClient(gw.app);
    resp = client.get("/dashboard", headers={"Accept": "text/html"});
    assert resp.status_code == 200;
    assert "SPA App" in resp.text;

    import shutil;
    shutil.rmtree(tmp);
}

test "gateway returns 404 for missing static and no spa" {
    tmp = tempfile.mkdtemp();

    reg = ServiceRegistry();
    gw = MicroserviceGateway(registry=reg, client_dist_dir=tmp);
    gw.setup();

    import from fastapi.testclient { TestClient }
    client = TestClient(gw.app);
    resp = client.get("/nonexistent.js");
    assert resp.status_code == 404;

    import shutil;
    shutil.rmtree(tmp);
}

# =============================================================================
# Admin UI serving
# =============================================================================
test "serve admin asset returns index.html for root" {
    tmp = tempfile.mkdtemp();
    admin_dir = Path(tmp) / "admin";
    admin_dir.mkdir();
    (admin_dir / "index.html").write_text("<html>Admin Portal</html>");

    reg = ServiceRegistry();
    gw = MicroserviceGateway(registry=reg, admin_dist_dir=str(admin_dir));

    resp = gw.serve_admin_asset("");
    assert resp is not None;
    assert b"Admin Portal" in resp.body;

    import shutil;
    shutil.rmtree(tmp);
}

test "serve admin asset returns static file" {
    tmp = tempfile.mkdtemp();
    admin_dir = Path(tmp) / "admin";
    assets = admin_dir / "assets";
    assets.mkdir(parents=True);
    (assets / "admin.js").write_text("var admin = true;");

    reg = ServiceRegistry();
    gw = MicroserviceGateway(registry=reg, admin_dist_dir=str(admin_dir));

    resp = gw.serve_admin_asset("assets/admin.js");
    assert resp is not None;
    assert b"admin" in resp.body;

    import shutil;
    shutil.rmtree(tmp);
}

test "serve admin asset spa fallback for unknown route" {
    tmp = tempfile.mkdtemp();
    admin_dir = Path(tmp) / "admin";
    admin_dir.mkdir();
    (admin_dir / "index.html").write_text("<html>Admin SPA</html>");

    reg = ServiceRegistry();
    gw = MicroserviceGateway(registry=reg, admin_dist_dir=str(admin_dir));

    resp = gw.serve_admin_asset("users/list");
    assert resp is not None;
    assert b"Admin SPA" in resp.body;

    import shutil;
    shutil.rmtree(tmp);
}

test "serve admin asset blocks path traversal" {
    tmp = tempfile.mkdtemp();
    admin_dir = Path(tmp) / "admin";
    admin_dir.mkdir();

    reg = ServiceRegistry();
    gw = MicroserviceGateway(registry=reg, admin_dist_dir=str(admin_dir));

    resp = gw.serve_admin_asset("../../etc/passwd");
    assert resp is None;

    import shutil;
    shutil.rmtree(tmp);
}

test "admin redirect via testclient" {
    tmp = tempfile.mkdtemp();
    admin_dir = Path(tmp) / "admin";
    admin_dir.mkdir();
    (admin_dir / "index.html").write_text("<html>Admin</html>");

    reg = ServiceRegistry();
    gw = MicroserviceGateway(registry=reg, admin_dist_dir=str(admin_dir));
    gw.setup();

    import from fastapi.testclient { TestClient }
    client = TestClient(gw.app, follow_redirects=False);
    resp = client.get("/admin");
    assert resp.status_code == 302;
    assert resp.headers["location"] == "/admin/";

    import shutil;
    shutil.rmtree(tmp);
}

test "admin index served at /admin/" {
    tmp = tempfile.mkdtemp();
    admin_dir = Path(tmp) / "admin";
    admin_dir.mkdir();
    (admin_dir / "index.html").write_text("<html>Admin Dashboard</html>");

    reg = ServiceRegistry();
    gw = MicroserviceGateway(registry=reg, admin_dist_dir=str(admin_dir));
    gw.setup();

    import from fastapi.testclient { TestClient }
    client = TestClient(gw.app);
    resp = client.get("/admin/");
    assert resp.status_code == 200;
    assert "Admin Dashboard" in resp.text;

    import shutil;
    shutil.rmtree(tmp);
}

# =============================================================================
# Auth - gateway is a pure passthrough; services handle auth via /user/login
# =============================================================================
test "api request to unreachable service returns 502" {
    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(
            name="orders",
            file="orders.jac",
            prefix="/api/orders",
            port=8001,
            url="http://127.0.0.1:8001",
            status=ServiceStatus.HEALTHY
        )
    );
    gw = MicroserviceGateway(registry=reg);
    gw.setup();

    import from fastapi.testclient { TestClient }
    client = TestClient(gw.app);

    # Gateway proxies to service - service is not running so 502
    resp = client.get("/api/orders/walker/list");
    assert resp.status_code == 502;
}

test "health endpoint does not require auth" {
    reg = ServiceRegistry();
    gw = MicroserviceGateway(registry=reg);
    gw.setup();

    import from fastapi.testclient { TestClient }
    client = TestClient(gw.app);

    resp = client.get("/health");
    assert resp.status_code == 200;
}

test "gateway drain 503s new requests with Retry-After + envelope" {
    import from jac_scale.microservices._drain { reset_drain, start_drain, is_draining }
    reset_drain();

    reg = ServiceRegistry();
    gw = MicroserviceGateway(registry=reg);
    gw.setup();

    import from fastapi.testclient { TestClient }
    client = TestClient(gw.app);

    resp = client.get("/health");
    assert resp.status_code == 200;

    start_drain(10.0);
    assert is_draining();

    resp = client.get("/health");
    assert resp.status_code == 503;
    assert resp.headers.get("Retry-After") == "2";

    body = resp.json();
    assert body["ok"] == False;
    assert body["error"]["code"] == "SERVICE_UNAVAILABLE";
    assert body["error"]["service"] == "__gateway__";
    assert "draining" in body["error"]["message"];

    reset_drain();
    resp = client.get("/health");
    assert resp.status_code == 200;
}

# Drain runs before the dispatcher (outermost middleware), so 503d
# responses should not carry the X-Trace-Id header the dispatcher stamps.
test "gateway drain does not burn metrics labels on 503d requests" {
    import from jac_scale.microservices._drain { reset_drain, start_drain }
    reset_drain();

    reg = ServiceRegistry();
    gw = MicroserviceGateway(registry=reg);
    gw.setup();

    import from fastapi.testclient { TestClient }
    client = TestClient(gw.app);

    start_drain(5.0);
    resp = client.get("/health");
    assert resp.status_code == 503;
    assert "x-trace-id" not in {k.lower() for k in resp.headers.keys()};

    reset_drain();
}


# P16: CORS middleware. The gateway only installs CORSMiddleware when
# `allow_origins` is configured; these tests patch the config resolver
# so setup() sees the test config.
obj _FakeScaleConfig {
    has _cors: dict = {};

    def get_microservices_config -> dict {
        return {
            "enabled": True,
            "gateway_port": 8000,
            "gateway_host": "0.0.0.0",
            "drain_timeout_seconds": 10.0,
            "routes": {},
            "services": {},
            "cors": self._cors,
            "client": {"entry": "", "dist_dir": "", "base_route": "/"}
        };
    }

    def get_monitoring_config -> dict {
        return {"namespace": "jac_scale", "histogram_buckets": None};
    }
}


def _with_cors_config(cfg: dict, fn: object) -> object {
    import jac_scale.config_loader as config_loader;
    orig = config_loader.get_scale_config;
    fake = _FakeScaleConfig(_cors=cfg);
    def fake_factory(project_dir: object = None) -> object {
        return fake;
    }
    setattr(config_loader, "get_scale_config", fake_factory);
    try {
        return fn();
    } finally {
        setattr(config_loader, "get_scale_config", orig);
    }
}


test "CORS disabled when allow_origins is empty" {
    def build -> object {
        reg = ServiceRegistry();
        gw = MicroserviceGateway(registry=reg);
        gw.setup();
        return gw;
    }
    gw = _with_cors_config({"allow_origins": []}, build);

    import from fastapi.testclient { TestClient }
    client = TestClient(gw.app);
    resp = client.get("/health", headers={"Origin": "http://example.com"});
    assert resp.status_code == 200;
    # No CORS headers emitted -> disabled.
    assert "access-control-allow-origin" not in {
        k.lower() for k in resp.headers.keys()
    };
}


test "CORS preflight returns Allow-Origin + Allow-Methods when configured" {
    def build -> object {
        reg = ServiceRegistry();
        gw = MicroserviceGateway(registry=reg);
        gw.setup();
        return gw;
    }
    cors = {
        "allow_origins": ["http://app.example.com"],
        "allow_methods": ["GET", "POST"],
        "allow_headers": ["Authorization", "Content-Type"],
        "allow_credentials": True,
        "expose_headers": [],
        "max_age": 600
    };
    gw = _with_cors_config(cors, build);

    import from fastapi.testclient { TestClient }
    client = TestClient(gw.app);
    resp = client.options(
        "/health",
        headers={
            "Origin": "http://app.example.com",
            "Access-Control-Request-Method": "GET",
            "Access-Control-Request-Headers": "Authorization"
        }
    );
    assert resp.status_code == 200;
    assert resp.headers.get("access-control-allow-origin") == "http://app.example.com";
    assert "GET" in resp.headers.get("access-control-allow-methods", "");
    assert resp.headers.get("access-control-allow-credentials") == "true";
}


test "CORS simple request echoes Allow-Origin on the response" {
    def build -> object {
        reg = ServiceRegistry();
        gw = MicroserviceGateway(registry=reg);
        gw.setup();
        return gw;
    }
    cors = {
        "allow_origins": ["http://app.example.com"],
        "allow_methods": ["*"],
        "allow_headers": ["*"],
        "allow_credentials": False,
        "expose_headers": [],
        "max_age": 600
    };
    gw = _with_cors_config(cors, build);

    import from fastapi.testclient { TestClient }
    client = TestClient(gw.app);
    resp = client.get("/health", headers={"Origin": "http://app.example.com"});
    assert resp.status_code == 200;
    assert resp.headers.get("access-control-allow-origin") == "http://app.example.com";
}


test "CORS preflight still responds during drain (headers reachable on 503)" {
    import from jac_scale.microservices._drain { reset_drain, start_drain }
    def build -> object {
        reg = ServiceRegistry();
        gw = MicroserviceGateway(registry=reg);
        gw.setup();
        return gw;
    }
    cors = {
        "allow_origins": ["http://app.example.com"],
        "allow_methods": ["*"],
        "allow_headers": ["*"],
        "allow_credentials": False,
        "expose_headers": [],
        "max_age": 600
    };
    gw = _with_cors_config(cors, build);

    import from fastapi.testclient { TestClient }
    client = TestClient(gw.app);
    reset_drain();
    start_drain(5.0);
    try {
        # Preflight (OPTIONS) must succeed even mid-drain - the browser
        # needs the CORS headers before it will issue the real request
        # (which may then 503 with CORS headers set).
        resp = client.options(
            "/health",
            headers={
                "Origin": "http://app.example.com",
                "Access-Control-Request-Method": "GET"
            }
        );
        assert resp.status_code == 200;
        assert resp.headers.get("access-control-allow-origin") == "http://app.example.com";

        # Non-preflight during drain -> 503 with CORS headers set.
        resp2 = client.get("/health", headers={"Origin": "http://app.example.com"});
        assert resp2.status_code == 503;
        assert resp2.headers.get("access-control-allow-origin") == "http://app.example.com";
    } finally {
        reset_drain();
    }
}

# =============================================================================
# http_forward_timeout resolver (gateway-to-service forward; configurable)
# =============================================================================
test "http_forward_timeout falls back to 30s default when config read fails" {
    import from jac_scale.microservices._util { http_forward_timeout }
    # No working config -> the except branch in the resolver fires and
    # returns _DEFAULT_HTTP_FORWARD_TIMEOUT (30.0).
    t: float = http_forward_timeout("module_with_no_override");
    assert t == 30.0 , f"expected 30.0 default, got {t}";
}

test "http_forward_timeout precedence: per-service > global > default" {
    import from jac_scale.microservices._util { http_forward_timeout }
    import jac_scale.config_loader as cfg_mod;

    obj _StubCfg {
        has data: dict[str, Any];

        def get_microservices_config -> dict[str, Any] {
            return self.data;
        }
    }

    original = getattr(cfg_mod, "get_scale_config");
    try {
        # Case A: only global default set
        setattr(
            cfg_mod,
            "get_scale_config",
            lambda : _StubCfg(data={"http_forward_timeout": 45.0, "services": {}})
        );
        assert http_forward_timeout(None) == 45.0;
        assert http_forward_timeout("any_service") == 45.0;

        # Case B: per-service override beats the global default
        setattr(
            cfg_mod,
            "get_scale_config",
            lambda :
                _StubCfg(
                    data={
                        "http_forward_timeout": 45.0,
                        "services": {"llm_app": {"http_forward_timeout": 300.0}}
                    }
                )
        );
        assert http_forward_timeout("llm_app") == 300.0;
        assert http_forward_timeout("other_service") == 45.0;

        # Case C: only per-service override; other services fall to default
        setattr(
            cfg_mod,
            "get_scale_config",
            lambda :
                _StubCfg(
                    data={"services": {"llm_app": {"http_forward_timeout": 120.0}}}
                )
        );
        assert http_forward_timeout("llm_app") == 120.0;
        assert http_forward_timeout("other_service") == 30.0;

        # Case D: per-service entry has rpc_timeout but no http_forward_timeout
        # -> falls through to global default. Verifies the two knobs are
        # independent.
        setattr(
            cfg_mod,
            "get_scale_config",
            lambda :
                _StubCfg(
                    data={
                        "http_forward_timeout": 45.0,
                        "services": {"llm_app": {"rpc_timeout": 120.0}}
                    }
                )
        );
        assert http_forward_timeout("llm_app") == 45.0;
    } finally {
        setattr(cfg_mod, "get_scale_config", original);
    }
}
