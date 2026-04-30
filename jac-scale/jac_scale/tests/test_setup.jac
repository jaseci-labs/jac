"""Tests for microservices setup CLI utilities (v2 routes schema)."""

import os;
import tempfile;
import tomllib;
import from pathlib { Path }
import from jac_scale.microservices.setup {
    scan_jac_files,
    derive_module_name,
    derive_prefix,
    add_service,
    remove_service,
    list_services
}

# =============================================================================
# Utility functions
# =============================================================================

test "derive_module_name returns file stem" {
    assert derive_module_name("orders_app.jac") == "orders_app";
    assert derive_module_name("payments_app.jac") == "payments_app";
    assert derive_module_name("services/orders.jac") == "orders";
}

test "derive_prefix strips _app suffix" {
    assert derive_prefix("orders_app") == "/api/orders";
    assert derive_prefix("payments_app") == "/api/payments";
}

test "derive_prefix passes non-_app names through" {
    assert derive_prefix("orders") == "/api/orders";
    assert derive_prefix("cart") == "/api/cart";
}

# =============================================================================
# scan_jac_files
# =============================================================================

test "scan_jac_files finds jac files" {
    tmp = tempfile.mkdtemp();
    (Path(tmp) / "app.jac").write_text("# app");
    (Path(tmp) / "orders.jac").write_text("# orders");

    files = scan_jac_files(tmp);
    assert "app.jac" in files;
    assert "orders.jac" in files;

    import shutil;
    shutil.rmtree(tmp);
}

test "scan_jac_files excludes build dirs" {
    tmp = tempfile.mkdtemp();
    (Path(tmp) / "app.jac").write_text("# app");
    jac_dir = Path(tmp) / ".jac";
    jac_dir.mkdir();
    (jac_dir / "cache.jac").write_text("# cached");
    pycache_dir = Path(tmp) / "__pycache__";
    pycache_dir.mkdir();
    (pycache_dir / "mod.jac").write_text("# compiled");

    files = scan_jac_files(tmp);
    assert "app.jac" in files;
    assert len(files) == 1;

    import shutil;
    shutil.rmtree(tmp);
}

test "scan_jac_files finds nested files" {
    tmp = tempfile.mkdtemp();
    svc_dir = Path(tmp) / "services";
    svc_dir.mkdir();
    (svc_dir / "orders.jac").write_text("# orders");

    files = scan_jac_files(tmp);
    assert len(files) == 1;
    found_path: str = files[0];
    assert "services" in found_path;
    assert "orders.jac" in found_path;

    import shutil;
    shutil.rmtree(tmp);
}

# =============================================================================
# add_service / remove_service / list_services
# =============================================================================

test "add_service creates routes table and appends entry" {
    tmp = tempfile.mkdtemp();
    toml_path = Path(tmp) / "jac.toml";
    toml_path.write_text('[plugins.scale.microservices]\nenabled = true\n');

    add_service(tmp, "orders_app.jac");

    with open(str(toml_path), "rb") as f {
        doc = tomllib.load(f);
    }
    routes = doc["plugins"]["scale"]["microservices"]["routes"];
    assert routes["orders_app"] == "/api/orders";

    import shutil;
    shutil.rmtree(tmp);
}

test "add_service appends to existing routes table" {
    tmp = tempfile.mkdtemp();
    toml_content = '[plugins.scale.microservices]\nenabled = true\n\n[plugins.scale.microservices.routes]\ncart_app = "/api/cart"\n';
    (Path(tmp) / "jac.toml").write_text(toml_content);

    add_service(tmp, "orders_app.jac");

    with open(str(Path(tmp) / "jac.toml"), "rb") as f {
        doc = tomllib.load(f);
    }
    routes = doc["plugins"]["scale"]["microservices"]["routes"];
    assert routes["cart_app"] == "/api/cart";
    assert routes["orders_app"] == "/api/orders";

    import shutil;
    shutil.rmtree(tmp);
}

test "add_service rejects duplicate" {
    tmp = tempfile.mkdtemp();
    toml_content = '[plugins.scale.microservices]\nenabled = true\n\n[plugins.scale.microservices.routes]\norders_app = "/api/orders"\n';
    (Path(tmp) / "jac.toml").write_text(toml_content);

    # Should print error, not crash, and leave content intact
    add_service(tmp, "orders_app.jac");

    content = (Path(tmp) / "jac.toml").read_text();
    assert content.count("orders_app =") == 1;

    import shutil;
    shutil.rmtree(tmp);
}

test "remove_service removes a route" {
    tmp = tempfile.mkdtemp();
    toml_content = '[plugins.scale.microservices]\nenabled = true\n\n[plugins.scale.microservices.routes]\norders_app = "/api/orders"\ncart_app = "/api/cart"\n';
    (Path(tmp) / "jac.toml").write_text(toml_content);

    remove_service(tmp, "orders_app");

    with open(str(Path(tmp) / "jac.toml"), "rb") as f {
        doc = tomllib.load(f);
    }
    routes = doc["plugins"]["scale"]["microservices"]["routes"];
    assert "orders_app" not in routes;
    assert routes["cart_app"] == "/api/cart";

    import shutil;
    shutil.rmtree(tmp);
}

test "remove_service handles missing route" {
    tmp = tempfile.mkdtemp();
    (Path(tmp) / "jac.toml").write_text('[plugins.scale.microservices]\nenabled = true\n');

    # Should print error, not crash
    remove_service(tmp, "nonexistent");

    import shutil;
    shutil.rmtree(tmp);
}

test "list_services shows config" {
    tmp = tempfile.mkdtemp();
    toml_content = '[plugins.scale.microservices]\nenabled = true\ngateway_port = 8000\n\n[plugins.scale.microservices.routes]\norders_app = "/api/orders"\n';
    (Path(tmp) / "jac.toml").write_text(toml_content);

    # Should print without crashing
    list_services(tmp);

    import shutil;
    shutil.rmtree(tmp);
}

test "list_services handles missing toml" {
    tmp = tempfile.mkdtemp();

    # Should print error, not crash
    list_services(tmp);

    import shutil;
    shutil.rmtree(tmp);
}
