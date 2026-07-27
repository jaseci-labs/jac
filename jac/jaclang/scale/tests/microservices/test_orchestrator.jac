import unittest.mock as mock;
import from jaclang.scale.runtime.orchestrator.orchestrator {
    build_registry,
    _mark_all_healthy_k8s,
    _populate_k8s_urls
}
import from jaclang.scale.runtime.gateway.service_registry { ServiceStatus }

test "build_registry creates entries from routes map" {
    ms_config = {"routes": {"orders_app": "/api/orders", "cart_app": "/api/cart"}};

    registry = build_registry(ms_config);

    assert len(registry.entries) == 2;
    assert "orders_app" in registry.entries;
    assert "cart_app" in registry.entries;
    assert registry.entries["orders_app"].prefix == "/api/orders";
    assert registry.entries["cart_app"].prefix == "/api/cart";

    assert registry.entries["orders_app"].file == "orders_app.jac";
    assert registry.entries["cart_app"].file == "cart_app.jac";
}

test "build_registry file for a discovered subdir service exists on disk" {
    import tempfile;
    import shutil;
    import from pathlib { Path }
    import from jaclang.scale.runtime.discovery.discovery {
        resolve_routes,
        resolve_service_files
    }

    tmp = Path(tempfile.mkdtemp());
    (tmp / "jac.toml").write_text("[project]\nname = \"app\"\n");
    (tmp / "main.jac").write_text("with entry { print(1); }\n");
    sub = tmp / "littlex";
    sub.mkdir();
    (sub / "social_graph.jac").write_text(
        "sv {\ndef:pub setup_profile -> int { return 1; }\n}\n"
    );
    try {
        entry_file = str(tmp / "main.jac");
        routes = resolve_routes(entry_file, {});
        files = resolve_service_files(entry_file, routes);
        registry = build_registry({"routes": routes, "service_files": files});

        svc = registry.entries["social_graph"];
        assert (tmp / svc.file).is_file() , (
            f"registry file '{svc.file}' does not exist relative to the "
            f"project root; the spawned `jac start {svc.file}` would crash"
        );
    } finally {
        shutil.rmtree(str(tmp), ignore_errors=True);
    }
}

test "build_registry handles empty config" {
    registry = build_registry({});
    assert len(registry.entries) == 0;
}

test "build_registry route entries have port 0" {
    ms_config = {"routes": {"orders_app": "/api/orders"}};
    registry = build_registry(ms_config);
    assert registry.entries["orders_app"].port == 0;
}

test "build_registry routes work after build" {
    ms_config = {"routes": {"orders_app": "/api/orders", "cart_app": "/api/cart"}};

    registry = build_registry(ms_config);
    assert registry.match_route("/api/orders/function/create_order").name == "orders_app";
    assert registry.match_route("/api/cart/function/view_cart").name == "cart_app";
    assert registry.match_route("/api/unknown") is None;
}

test "build_registry default status is REGISTERED (local-mode invariant)" {
    registry = build_registry({"routes": {"orders_app": "/api/orders"}});
    assert registry.entries["orders_app"].status == ServiceStatus.REGISTERED;
}

test "_wait_for_health does not burn the boot budget on a dead child" {
    import time;
    import from jaclang.scale.runtime.orchestrator.orchestrator {
        MicroserviceOrchestrator
    }
    import from jaclang.scale.runtime.orchestrator.process_manager {
        ServiceProcessManager
    }
    import from jaclang.scale.runtime.gateway.service_registry {
        ServiceRegistry,
        ServiceEntry
    }

    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(
            name="alive",
            file="alive.jac",
            prefix="/alive",
            port=8001,
            url="http://127.0.0.1:8001",
            status=ServiceStatus.STARTING
        )
    );
    reg.register(
        ServiceEntry(
            name="dead",
            file="dead.jac",
            prefix="/dead",
            port=8002,
            url="http://127.0.0.1:8002",
            status=ServiceStatus.STARTING
        )
    );
    pm = ServiceProcessManager(registry=reg);

    alive_proc = mock.MagicMock();
    alive_proc.poll = mock.MagicMock(return_value=None);
    dead_proc = mock.MagicMock();
    dead_proc.poll = mock.MagicMock(return_value=1);
    pm.processes["alive"] = alive_proc;
    pm.processes["dead"] = dead_proc;

    orch = MicroserviceOrchestrator(ms_config={});
    with mock.patch.object(
        pm, "check_health", side_effect=(lambda (name) { name == "alive"; })
    ) {
        start = time.time();
        orch._wait_for_health(pm, reg, 6);
        elapsed = time.time() - start;
    }

    assert elapsed < 3.0 , (
        f"a dead child can never become healthy; the boot wait must treat it "
        f"as terminal instead of polling for {elapsed:.1f}s"
    );
}

test "_mark_all_healthy_k8s flips every entry to HEALTHY (regression)" {
    registry = build_registry(
        {
            "routes": {
                "orders_app": "/api/orders",
                "cart_app": "/api/cart",
                "products_app": "/api/products"
            }
        }
    );
    for (_name, _entry) in registry.entries.items() {
        assert _entry.status == ServiceStatus.REGISTERED;
    }

    _mark_all_healthy_k8s(registry);

    for (_name, _entry) in registry.entries.items() {
        assert _entry.status == ServiceStatus.HEALTHY , (
            f"K8s gateway pre-mark must flip every entry to HEALTHY, "
            f"{_name} is {_entry.status}"
        );
    }
}

test "_mark_all_healthy_k8s is idempotent on empty registry" {
    registry = build_registry({});
    _mark_all_healthy_k8s(registry);
    assert len(registry.entries) == 0;
}


test "_populate_k8s_urls writes DNS map onto svc_entry.url (regression)" {
    import jaclang;

    registry = build_registry(
        {"routes": {"products_app": "/api/products", "orders_app": "/api/orders"}}
    );

    for (_n, _e) in registry.entries.items() {
        assert _e.url == "";
    }

    fake_dns: dict[str, str] = {
        "products_app": "http://products-app-service.default.svc.cluster.local:8000",
        "orders_app": "http://orders-app-service.default.svc.cluster.local:8000"
    };
    with mock.patch.object(
        jaclang.JacRuntime, "get_sv_registry", return_value=fake_dns
    ) {
        _populate_k8s_urls(registry);
    }

    assert (
        registry.entries["products_app"].url == "http://products-app-service.default.svc.cluster.local:8000"
    );
    assert (
        registry.entries["orders_app"].url == "http://orders-app-service.default.svc.cluster.local:8000"
    );
}


test "_populate_k8s_urls fails-soft when hookspec raises (entries stay empty)" {
    import jaclang;

    registry = build_registry({"routes": {"orders_app": "/api/orders"}});
    with mock.patch.object(
        jaclang.JacRuntime,
        "get_sv_registry",
        side_effect=RuntimeError("hookspec broken")
    ) {
        _populate_k8s_urls(registry);
    }

    assert registry.entries["orders_app"].url == "";
}


test "_populate_k8s_urls handles partial DNS map (only sets known URLs)" {
    import jaclang;

    registry = build_registry(
        {"routes": {"products_app": "/api/products", "missing_app": "/api/missing"}}
    );
    fake_dns: dict[str, str] = {"products_app": "http://products-app-service:8000"};
    with mock.patch.object(
        jaclang.JacRuntime, "get_sv_registry", return_value=fake_dns
    ) {
        _populate_k8s_urls(registry);
    }
    assert registry.entries["products_app"].url == "http://products-app-service:8000";
    assert registry.entries["missing_app"].url == "";
}
