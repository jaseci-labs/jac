"""Tests for microservices orchestrator."""

import from jac_scale.microservices.orchestrator { build_registry, _mark_all_healthy_k8s }
import from jac_scale.microservices.service_registry { ServiceStatus }

test "build_registry creates entries from routes map" {
    ms_config = {
        "routes": {
            "orders_app": "/api/orders",
            "cart_app": "/api/cart"
        }
    };

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
    ms_config = {
        "routes": {
            "orders_app": "/api/orders",
            "cart_app": "/api/cart"
        }
    };

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
    registry = build_registry({
        "routes": {
            "orders_app": "/api/orders",
            "cart_app": "/api/cart",
            "products_app": "/api/products"
        }
    });
    for (_name, _entry) in registry.entries.items() {
        assert _entry.status == ServiceStatus.REGISTERED;
    }

    _mark_all_healthy_k8s(registry);

    for (_name, _entry) in registry.entries.items() {
        assert _entry.status == ServiceStatus.HEALTHY, (
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
