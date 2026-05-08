"""Tests for microservices orchestrator."""

import unittest.mock as mock;
import from jac_scale.microservices.orchestrator {
    build_registry,
    _mark_all_healthy_k8s,
    _populate_k8s_urls
}
import from jac_scale.microservices.service_registry { ServiceStatus }

test "build_registry creates entries from routes map" {
    ms_config = {"routes": {"orders_app": "/api/orders", "cart_app": "/api/cart"}};

    registry = build_registry(ms_config);

    assert len(registry.entries) == 2;
    assert "orders_app" in registry.entries;
    assert "cart_app" in registry.entries;
    assert registry.entries["orders_app"].prefix == "/api/orders";
    assert registry.entries["cart_app"].prefix == "/api/cart";
    # file derived from module name
    assert registry.entries["orders_app"].file == "orders_app.jac";
    assert registry.entries["cart_app"].file == "cart_app.jac";
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
    # Companion to the K8s mark-healthy regression. Local mode relies on
    # LocalDeployer flipping REGISTERED -> HEALTHY after spawn; if this
    # default ever changes, callers (including K8s gateway-only mode)
    # need to know.
    registry = build_registry({"routes": {"orders_app": "/api/orders"}});
    assert registry.entries["orders_app"].status == ServiceStatus.REGISTERED;
}

test "_mark_all_healthy_k8s flips every entry to HEALTHY (regression)" {
    # Regression: K8s gateway-only mode skips LocalDeployer, so without
    # this helper entries stay REGISTERED forever. handle_proxy then
    # 503's every /api/<svc>/* request because its status check excludes
    # REGISTERED. K8s owns real health via kube-proxy + Endpoints, so
    # pre-marking is correct - failed services still surface as
    # transport errors from http_forward.
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
    # Real bug found during EC2 verification: handle_proxy
    # uses get_sv_registry() at request time, but
    # handle_builtin_passthrough (auth, walker, function fan-out)
    # reads svc_entry.url DIRECTLY and skips entries with empty url.
    # In K8s mode, build_registry constructs entries with url="" and
    # the only thing flipping them was _mark_all_healthy_k8s which
    # didn't touch URL. Result: every built-in route (`/user/login`,
    # etc) returned "Not found on any service" because every service
    # got skipped. Fix: at gateway startup, populate svc_entry.url
    # from the same DNS hookspec used by handle_proxy.
    import jaclang;

    registry = build_registry(
        {"routes": {"products_app": "/api/products", "orders_app": "/api/orders"}}
    );
    # Pre-condition: empty url
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
    # If get_sv_registry() throws (e.g. plugin not loaded yet), the
    # population should be a no-op rather than crash gateway startup.
    # Existing handle_builtin_passthrough's "skip empty url" check
    # then handles it - those routes won't work but the gateway still
    # starts and serves what it can.
    import jaclang;

    registry = build_registry({"routes": {"orders_app": "/api/orders"}});
    with mock.patch.object(
        jaclang.JacRuntime,
        "get_sv_registry",
        side_effect=RuntimeError("hookspec broken")
    ) {
        # Should not raise
        _populate_k8s_urls(registry);
    }
    # Entry's url stays empty
    assert registry.entries["orders_app"].url == "";
}


test "_populate_k8s_urls handles partial DNS map (only sets known URLs)" {
    # If the hookspec returns a map that's missing some services
    # (e.g. user added a service to jac.toml but DNS hasn't caught up),
    # only populate the ones that ARE in the map. Unknown ones stay
    # empty - their requests will fail naturally rather than route to
    # a wrong place.
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
