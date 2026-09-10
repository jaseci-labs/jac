"""The fleet is read from [apps]: service apps are members at their routes, the
served app hosts the gateway at /, providers boot before consumers, and the
gateway exposes the same URLs the colocated in-process server mounts."""

import json;
import os;
import shutil;
import tempfile;
import from pathlib { Path }
import from jaclang.project.config { JacConfig }
import from jaclang.server { sv_client }
import from jaclang.scale.runtime.fleet {
    FLEET_ENV,
    FleetSpec,
    ROOT_PREFIX,
    consumer_provider_edges,
    fleet_from_config,
    fleet_from_env,
    fleet_of,
    guard_fleet_routes,
    order_by_edges,
    solo_fleet
}
import from jaclang.scale.runtime.orchestrator.orchestrator { build_registry }
import from jaclang.scale.runtime.gateway.dispatch { classify_route, ROUTE_PROXY }
import from jaclang.scale.runtime.gateway.service_registry {
    ServiceRegistry,
    ServiceEntry,
    ServiceStatus
}
import from jaclang.scale.runtime.gateway.microservice_gateway { MicroserviceGateway }

glob _WORKSPACE_TOML: str = '[project]\nname = "shop"\ndefault-app = "web"\n\n[apps.web]\nkind = "web-app"\nentry-point = "web.main"\n\n[apps.orders]\nkind = "service"\nentry-point = "core.orders"\n\n[apps.cart]\nkind = "service"\nentry-point = "core.cart"\nroute = "/api/basket"\n\n[apps.tool]\nkind = "cli"\nentry-point = "tool.main"\n';


def _workspace -> str {
    d = tempfile.mkdtemp(prefix="jac-fleet-apps-");
    (Path(d) / "jac.toml").write_text(_WORKSPACE_TOML, encoding="utf-8");
    (Path(d) / "web").mkdir();
    (Path(d) / "web" / "main.jac").write_text("with entry {}\n", encoding="utf-8");
    (Path(d) / "core").mkdir();
    (Path(d) / "core" / "orders.jac").write_text("with entry {}\n", encoding="utf-8");
    (Path(d) / "core" / "cart.jac").write_text("with entry {}\n", encoding="utf-8");
    (Path(d) / "tool").mkdir();
    (Path(d) / "tool" / "main.jac").write_text("with entry {}\n", encoding="utf-8");
    return d;
}


def _config(d: str) -> JacConfig {
    return JacConfig.load(Path(d) / "jac.toml");
}


test "fleet membership comes from [apps]: service kinds only, served app hosts" {
    d = _workspace();
    try {
        fleet = fleet_from_config(_config(d), project_root=d);
        assert fleet.root_app == "web" , fleet.root_app;
        assert set(fleet.service_names()) == {"orders", "cart"} , fleet.names();
        assert "tool" not in fleet.members , "a cli app is never a fleet member";
        assert fleet.members["web"].is_root;
        assert not fleet.members["orders"].is_root;
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}


test "routes default to /api/<name> and honor [apps.<name>] route" {
    d = _workspace();
    try {
        fleet = fleet_from_config(_config(d), project_root=d);
        assert fleet.routes() == {"orders": "/api/orders", "cart": "/api/basket"} , (
            fleet.routes()
        );
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}


test "member files are absolute locally and bundle-relative for a deploy" {
    d = _workspace();
    try {
        local = fleet_from_config(_config(d), project_root=d);
        assert os.path.isabs(local.members["orders"].file);
        assert local.members["orders"].file.endswith(
            os.path.join("core", "orders.jac")
        );
        shipped = fleet_from_config(_config(d), project_root=d, relative_to=d);
        assert shipped.files()["orders"] == "core/orders.jac" , shipped.files();
        assert shipped.files()["web"] == "web/main.jac" , shipped.files();
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}


test "the served app is named explicitly or falls back to the default app" {
    d = _workspace();
    try {
        cfg = _config(d);
        assert fleet_from_config(cfg, "web", project_root=d).root_app == "web";
        by_default = fleet_from_config(cfg, project_root=d);
        assert by_default.root_app == "web";
        as_service = fleet_from_config(cfg, "orders", project_root=d);
        assert as_service.root_app == "orders";
        assert set(as_service.service_names()) == {"cart"};
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}


test "providers boot before consumers along the recorded app edges" {
    names = ["web", "orders", "cart", "stock"];
    edges = [("web", "orders"), ("orders", "cart"), ("orders", "stock")];
    order = order_by_edges(names, edges);
    assert order.index("cart") < order.index("orders") , order;
    assert order.index("stock") < order.index("orders") , order;
    assert order.index("orders") < order.index("web") , order;
}


test "with no edges the declaration order is the boot order" {
    assert order_by_edges(["a", "b", "c"], []) == ["a", "b", "c"];
}


test "a cycle falls back to declaration order instead of hanging" {
    order = order_by_edges(["a", "b"], [("a", "b"), ("b", "a")]);
    assert order == ["a", "b"] , order;
}


test "consumer edges declared by loaded modules order the fleet" {
    d = _workspace();
    sv_client.clear_consumer_providers();
    try {
        sv_client._declare_consumer_provider("web", "orders");
        sv_client._declare_consumer_provider("orders", "cart");
        fleet = fleet_from_config(_config(d), project_root=d);
        names = fleet.names();
        assert names.index("cart") < names.index("orders") , names;
        assert names.index("orders") < names.index("web") , names;
    } finally {
        sv_client.clear_consumer_providers();
        shutil.rmtree(d, ignore_errors=True);
    }
}


test "a route that shadows a gateway-owned segment is refused" {
    fleet = fleet_of({"svc": "/user"});
    caught = "";
    try {
        guard_fleet_routes(fleet);
    } except ValueError as e {
        caught = str(e);
    }
    assert "owned by the gateway" in caught , caught;
}


test "two apps on one route are refused" {
    fleet = fleet_of({"a": "/api/shared", "b": "/api/shared/"});
    caught = "";
    try {
        guard_fleet_routes(fleet);
    } except ValueError as e {
        caught = str(e);
    }
    assert "distinct route" in caught , caught;
}


test "the fleet round-trips through JAC_SV_FLEET" {
    fleet = fleet_of(
        {"orders": "/api/orders"}, root_app="web", root_file="web/main.jac"
    );
    saved = os.environ.get(FLEET_ENV);
    os.environ[FLEET_ENV] = fleet.to_env();
    try {
        back = fleet_from_env();
        assert back is not None;
        assert back.root_app == "web";
        assert back.routes() == {"orders": "/api/orders"};
        assert back.members["web"].file == "web/main.jac";
        assert json.loads(fleet.to_env())["root"] == "web";
    } finally {
        if saved is None {
            os.environ.pop(FLEET_ENV, None);
        } else {
            os.environ[FLEET_ENV] = saved;
        }
    }
}


test "a solo app is a fleet of one root member" {
    fleet = solo_fleet("shop", "main.jac");
    assert fleet.root_app == "shop";
    assert fleet.service_names() == [];
    assert fleet.members["shop"].file == "main.jac";
}


test "the gateway registry mounts services at their routes and the host at /" {
    fleet = fleet_of({"orders": "/api/orders", "cart": "/api/basket"}, root_app="web");
    registry = build_registry(fleet);
    assert registry.root_app == "web";
    assert registry.entries["web"].prefix == ROOT_PREFIX;
    assert registry.entries["orders"].prefix == "/api/orders";
    assert registry.entries["orders"].env["JAC_SV_NAME"] == "orders";
    orders = registry.match_route("/api/orders/walker/Create");
    cart = registry.match_route("/api/basket/function/view");
    assert orders is not None and orders.name == "orders";
    assert cart is not None and cart.name == "cart";
    assert registry.match_route("/walker/Home") is None , (
        "root paths belong to the host, not a prefix match"
    );
}


test "the gateway proxies every URL shape the colocated server mounts" {
    prefixes = ["/api/orders", "/api/basket"];
    for path in [
        "/api/orders/walker/Create",
        "/api/orders/walker/Create/n:abc",
        "/api/orders/function/total",
        "/api/orders/walkers",
        "/api/orders/functions"
    ] {
        decision = classify_route(path, prefixes);
        assert decision.kind == ROUTE_PROXY , f"{path}: {decision.kind}";
        assert decision.service == "/api/orders" , f"{path}: {decision.service}";
    }
}


test "root paths forward to the served app and 503 while it boots" {
    import from jaclang.testing.testkit { ServingTestClient as TestClient }
    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(
            name="web",
            file="web/main.jac",
            prefix=ROOT_PREFIX,
            port=1,
            url="http://127.0.0.1:1",
            status=ServiceStatus.STOPPED,
            is_root=True
        )
    );
    gw = MicroserviceGateway(registry=reg);
    gw.setup();
    client = TestClient(gw.app);
    resp = client.post("/walker/Home", json={});
    assert resp.status_code == 503 , resp.status_code;
    body = resp.json();
    assert body["error"]["code"] == "SERVICE_UNAVAILABLE" , body;
}


test "reading app edges compiles for analysis only, never codegen" {
    import unittest.mock;
    import from jaclang.compiler.driver.program { JacProgram }
    d = _workspace();
    sv_client.clear_consumer_providers();
    real_compile = JacProgram.compile;
    seen: list[tuple[str, bool]] = [];

    def _spy(self: any, file_path: str, *args: any, **kwargs: any) -> any {
        opts = kwargs.get("options");
        no_cgen = bool(kwargs.get("no_cgen", False))
            or bool(opts is not None and opts.no_cgen);
        seen.append((os.path.basename(str(file_path)), no_cgen));
        return real_compile(self, file_path, *args, **kwargs);
    }
    try {
        with unittest.mock.patch.object(JacProgram, "compile", _spy) {
            fleet = fleet_from_config(_config(d), project_root=d);
        }
        assert set(fleet.names()) == {"web", "orders", "cart"} , fleet.names();
        compiled = {name for (name, _) in seen};
        assert {"orders.jac", "cart.jac", "main.jac"} <= compiled , seen;
        assert all(no_cgen for (_, no_cgen) in seen) , (
            f"fleet ordering must not run codegen: {seen}"
        );
    } finally {
        sv_client.clear_consumer_providers();
        shutil.rmtree(d, ignore_errors=True);
    }
}


test "an app that does not compile stops the fleet loudly" {
    d = _workspace();
    sv_client.clear_consumer_providers();
    (Path(d) / "core" / "cart.jac").write_text(
        "walker:pub Add {\n    def run -> int {\n        return 1\n    }\n",
        encoding="utf-8"
    );
    try {
        caught = "";
        try {
            fleet_from_config(_config(d), project_root=d);
        } except ValueError as e {
            caught = str(e);
        }
        assert caught , "a broken app must not boot in declaration order silently";
        assert "cart" in caught , caught;
        assert "cart.jac" in caught , caught;
        assert "does not compile" in caught , caught;
        assert "line" in caught , f"the first error must be named: {caught}";
    } finally {
        sv_client.clear_consumer_providers();
        shutil.rmtree(d, ignore_errors=True);
    }
}


glob _BRIDGE_TOML: str = '[project]\nname = "bridged"\ndefault-app = "web"\n\n[apps.web]\nkind = "web-app"\nentry-point = "web.main"\n\n[apps.orders]\nkind = "service"\nentry-point = "core.orders"\n\n[apps.cart]\nkind = "service"\nentry-point = "core.cart"\n';


def _bridge_workspace -> str {
    d = tempfile.mkdtemp(prefix="jac-fleet-bridge-");
    (Path(d) / "jac.toml").write_text(_BRIDGE_TOML, encoding="utf-8");
    (Path(d) / "web").mkdir();
    (Path(d) / "web" / "main.jac").write_text("with entry {}\n", encoding="utf-8");
    (Path(d) / "core").mkdir();
    (Path(d) / "core" / "cart.jac").write_text(
        'def:pub view_cart -> dict {\n    return {"items": []};\n}\n', encoding="utf-8"
    );
    (Path(d) / "core" / "orders.jac").write_text(
        'import from cart { view_cart }\n'
        '\n'
        'async def:pub place_order -> dict {\n'
        '    return await view_cart();\n'
        '}\n',
        encoding="utf-8"
    );
    return d;
}


test "a compiled cross-app import is reported as a consumer/provider edge" {
    d = _bridge_workspace();
    try {
        cfg = _config(d);
        apps = [cfg.app("web"), cfg.app("orders"), cfg.app("cart")];
        edges = consumer_provider_edges(cfg, d, apps);
        assert ("orders", "cart") in edges , (
            f"a declared cross-app import produced no edge: {edges!r}"
        );
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}


test "edge analysis visits modules registered while analyzing either hub" {
    import from types { SimpleNamespace }
    import from unittest.mock { patch }
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.scale.runtime.fleet { _compiled_app_edges }
    def module(edges: list) -> any {
        return SimpleNamespace(
            gen=SimpleNamespace(
                interop_manifest=SimpleNamespace(
                    app_edges=edges, walker_access={}, func_access={}
                )
            )
        );
    }
    first = module([]);
    added = module([("web", "orders")]);
    internal = module([]);
    final = module([("orders", "db")]);
    user_hub = {"first": first};
    compiler_hub = {"internal": internal};
    def analyze(prog: any, mod: any, schedule: any) {
        if mod is first {
            user_hub["added"] = added;
        }
        if mod is internal {
            compiler_hub["final"] = final;
        }
    }
    with patch.object(JacProgram, "compile"), patch.object(
        JacProgram, "_search_hubs", return_value=[user_hub, compiler_hub]
    ), patch.object(JacProgram, "run_schedule", analyze) {
        edges = _compiled_app_edges("main.jac", "web", "web-app", "/tmp");
        assert set(edges) == {("web", "orders"), ("orders", "db")};
    }
}
