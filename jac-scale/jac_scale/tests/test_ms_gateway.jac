"""Tests for microservices MicroserviceGateway."""

import os;
import tempfile;
import from pathlib { Path }
import from jac_scale.microservices.gateway { MicroserviceGateway }

# =============================================================================
# build_target_url
# =============================================================================

test "build_target_url strips prefix and preserves remainder" {
    gw = MicroserviceGateway(routes={"products_app": "/api/products"});
    url = gw.build_target_url("http://127.0.0.1:18342", "/api/products", "/api/products/walker/ListProducts", "");
    assert url == "http://127.0.0.1:18342/walker/ListProducts";
}

test "build_target_url preserves function path" {
    gw = MicroserviceGateway(routes={});
    url = gw.build_target_url("http://127.0.0.1:18342", "/api/products", "/api/products/function/get_total", "");
    assert url == "http://127.0.0.1:18342/function/get_total";
}

test "build_target_url appends query string" {
    gw = MicroserviceGateway(routes={});
    url = gw.build_target_url("http://127.0.0.1:18342", "/api/products", "/api/products/walker/list", "limit=10");
    assert url == "http://127.0.0.1:18342/walker/list?limit=10";
}

test "build_target_url exact prefix returns root" {
    gw = MicroserviceGateway(routes={});
    url = gw.build_target_url("http://127.0.0.1:18342", "/api/products", "/api/products", "");
    assert url == "http://127.0.0.1:18342/";
}

test "build_target_url no query omits question mark" {
    gw = MicroserviceGateway(routes={});
    url = gw.build_target_url("http://127.0.0.1:18342", "/api/products", "/api/products/walker/list", "");
    assert "?" not in url;
}

# =============================================================================
# resolve_service_url
# =============================================================================

test "resolve_service_url returns none for unknown module" {
    gw = MicroserviceGateway(routes={});
    url = gw.resolve_service_url("nonexistent_module");
    assert url is None;
}

# =============================================================================
# setup creates app
# =============================================================================

test "setup creates fastapi app" {
    gw = MicroserviceGateway(routes={});
    app = gw.setup();
    assert app is not None;
    assert gw.app is not None;
}

# =============================================================================
# Static file serving
# =============================================================================

test "serve_static returns file with correct mime type" {
    tmp = tempfile.mkdtemp();
    assets_dir = Path(tmp) / "assets";
    assets_dir.mkdir();
    (assets_dir / "app.js").write_text("console.log('hello');");

    gw = MicroserviceGateway(routes={}, client_dist_dir=tmp);
    resp = gw.serve_static("assets/app.js");
    assert resp is not None;
    assert "javascript" in resp.media_type;
    assert b"hello" in resp.body;

    import shutil;
    shutil.rmtree(tmp);
}

test "serve_static returns none for missing file" {
    tmp = tempfile.mkdtemp();
    gw = MicroserviceGateway(routes={}, client_dist_dir=tmp);
    assert gw.serve_static("nonexistent.js") is None;
    import shutil;
    shutil.rmtree(tmp);
}

test "serve_static blocks path traversal" {
    tmp = tempfile.mkdtemp();
    gw = MicroserviceGateway(routes={}, client_dist_dir=tmp);
    assert gw.serve_static("../../etc/passwd") is None;
    import shutil;
    shutil.rmtree(tmp);
}

test "serve_static css returns text content type" {
    tmp = tempfile.mkdtemp();
    (Path(tmp) / "style.css").write_text("body { color: red; }");
    gw = MicroserviceGateway(routes={}, client_dist_dir=tmp);
    resp = gw.serve_static("style.css");
    assert resp is not None;
    assert resp.media_type == "text/css";
    import shutil;
    shutil.rmtree(tmp);
}

# =============================================================================
# SPA fallback
# =============================================================================

test "spa_fallback serves index.html" {
    tmp = tempfile.mkdtemp();
    (Path(tmp) / "index.html").write_text("<html>SPA</html>");
    gw = MicroserviceGateway(routes={}, client_dist_dir=tmp);
    resp = gw.serve_spa_fallback();
    assert resp is not None;
    assert b"SPA" in resp.body;
    import shutil;
    shutil.rmtree(tmp);
}

test "spa_fallback returns none when no index" {
    tmp = tempfile.mkdtemp();
    gw = MicroserviceGateway(routes={}, client_dist_dir=tmp);
    assert gw.serve_spa_fallback() is None;
    import shutil;
    shutil.rmtree(tmp);
}

# =============================================================================
# Admin serving
# =============================================================================

test "serve_admin_asset returns index for root" {
    tmp = tempfile.mkdtemp();
    admin_dir = Path(tmp) / "admin";
    admin_dir.mkdir();
    (admin_dir / "index.html").write_text("<html>Admin</html>");
    gw = MicroserviceGateway(routes={}, admin_dist_dir=str(admin_dir));
    resp = gw.serve_admin_asset("");
    assert resp is not None;
    assert b"Admin" in resp.body;
    import shutil;
    shutil.rmtree(tmp);
}

test "serve_admin_asset blocks path traversal" {
    tmp = tempfile.mkdtemp();
    admin_dir = Path(tmp) / "admin";
    admin_dir.mkdir();
    gw = MicroserviceGateway(routes={}, admin_dist_dir=str(admin_dir));
    assert gw.serve_admin_asset("../../etc/passwd") is None;
    import shutil;
    shutil.rmtree(tmp);
}

# =============================================================================
# TestClient integration
# =============================================================================

test "health endpoint returns service info" {
    gw = MicroserviceGateway(routes={"products_app": "/api/products"});
    gw.setup();
    import from fastapi.testclient { TestClient }
    client = TestClient(gw.app);
    resp = client.get("/health");
    assert resp.status_code == 200;
    data = resp.json();
    assert data["status"] == "healthy";
    assert "products_app" in data["services"];
}

test "unmatched api path returns 404" {
    gw = MicroserviceGateway(routes={"products_app": "/api/products"});
    gw.setup();
    import from fastapi.testclient { TestClient }
    client = TestClient(gw.app);
    resp = client.get("/api/unknown/walker/test");
    assert resp.status_code == 404;
}

test "matched api path without registered service returns 503" {
    gw = MicroserviceGateway(routes={"products_app": "/api/products"});
    gw.setup();
    import from fastapi.testclient { TestClient }
    client = TestClient(gw.app);
    resp = client.get("/api/products/walker/ListProducts");
    assert resp.status_code == 503;
}

test "admin redirect" {
    tmp = tempfile.mkdtemp();
    admin_dir = Path(tmp) / "admin";
    admin_dir.mkdir();
    (admin_dir / "index.html").write_text("<html>Admin</html>");
    gw = MicroserviceGateway(routes={}, admin_dist_dir=str(admin_dir));
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
    (admin_dir / "index.html").write_text("<html>Dashboard</html>");
    gw = MicroserviceGateway(routes={}, admin_dist_dir=str(admin_dir));
    gw.setup();
    import from fastapi.testclient { TestClient }
    client = TestClient(gw.app);
    resp = client.get("/admin/");
    assert resp.status_code == 200;
    assert "Dashboard" in resp.text;
    import shutil;
    shutil.rmtree(tmp);
}

test "static file served for unmatched get" {
    tmp = tempfile.mkdtemp();
    assets_dir = Path(tmp) / "assets";
    assets_dir.mkdir();
    (assets_dir / "app.js").write_text("var x = 1;");
    gw = MicroserviceGateway(routes={}, client_dist_dir=tmp);
    gw.setup();
    import from fastapi.testclient { TestClient }
    client = TestClient(gw.app);
    resp = client.get("/assets/app.js");
    assert resp.status_code == 200;
    assert "var x = 1" in resp.text;
    import shutil;
    shutil.rmtree(tmp);
}

test "spa fallback for html navigation" {
    tmp = tempfile.mkdtemp();
    (Path(tmp) / "index.html").write_text("<html>SPA App</html>");
    gw = MicroserviceGateway(routes={}, client_dist_dir=tmp);
    gw.setup();
    import from fastapi.testclient { TestClient }
    client = TestClient(gw.app);
    resp = client.get("/dashboard", headers={"Accept": "text/html"});
    assert resp.status_code == 200;
    assert "SPA App" in resp.text;
    import shutil;
    shutil.rmtree(tmp);
}

test "404 for missing static and no spa" {
    tmp = tempfile.mkdtemp();
    gw = MicroserviceGateway(routes={}, client_dist_dir=tmp);
    gw.setup();
    import from fastapi.testclient { TestClient }
    client = TestClient(gw.app);
    resp = client.get("/nonexistent.js");
    assert resp.status_code == 404;
    import shutil;
    shutil.rmtree(tmp);
}

test "empty routes returns 404 for api paths" {
    gw = MicroserviceGateway(routes={});
    gw.setup();
    import from fastapi.testclient { TestClient }
    client = TestClient(gw.app);
    resp = client.get("/api/anything/walker/test");
    assert resp.status_code == 404;
}
