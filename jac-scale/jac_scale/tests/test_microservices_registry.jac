"""Tests for microservices ServiceRegistry."""

import from jac_scale.microservices.service_registry {
    ServiceRegistry,
    ServiceEntry,
    ServiceStatus
}

# =============================================================================
# ServiceEntry
# =============================================================================

test "service entry has correct defaults" {
    entry = ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders");
    assert entry.port == 0;
    assert entry.url == "";
    assert entry.pid is None;
    assert entry.status == ServiceStatus.REGISTERED;
    assert entry.replicas == 1;
    assert entry.env == {};
}

test "service entry accepts custom fields" {
    entry = ServiceEntry(
        name="payments", file="payments.jac", prefix="/api/payments",
        port=8002, replicas=3, env={"STRIPE_KEY": "sk_test"}
    );
    assert entry.port == 8002;
    assert entry.replicas == 3;
    assert entry.env["STRIPE_KEY"] == "sk_test";
}

# =============================================================================
# Register and lookup
# =============================================================================

test "register and lookup by path" {
    reg = ServiceRegistry();
    reg.register(ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders", port=8001));
    found = reg.match_route("/api/orders/list");
    assert found is not None;
    assert found.name == "orders";
}

test "exact prefix matches" {
    reg = ServiceRegistry();
    reg.register(ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders", port=8001));
    found = reg.match_route("/api/orders");
    assert found is not None;
    assert found.name == "orders";
}

test "no match returns none" {
    reg = ServiceRegistry();
    reg.register(ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders", port=8001));
    assert reg.match_route("/api/unknown") is None;
    assert reg.match_route("/health") is None;
    assert reg.match_route("/") is None;
}

test "prefix boundary does not match partial names" {
    reg = ServiceRegistry();
    reg.register(ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders", port=8001));
    assert reg.match_route("/api/ordershistory") is None;
}

test "empty registry returns none" {
    reg = ServiceRegistry();
    assert reg.match_route("/api/anything") is None;
    assert reg.health_summary() == {};
}

# =============================================================================
# Longest prefix matching
# =============================================================================

test "longest prefix wins" {
    reg = ServiceRegistry();
    reg.register(ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders", port=8001));
    reg.register(ServiceEntry(name="orders_v2", file="orders_v2.jac", prefix="/api/orders/v2", port=8002));
    assert reg.match_route("/api/orders/v2/list").name == "orders_v2";
    assert reg.match_route("/api/orders/list").name == "orders";
}

# =============================================================================
# Multiple services
# =============================================================================

test "multiple services route correctly" {
    reg = ServiceRegistry();
    reg.register(ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders", port=8001));
    reg.register(ServiceEntry(name="payments", file="payments.jac", prefix="/api/payments", port=8002));
    reg.register(ServiceEntry(name="users", file="users.jac", prefix="/api/users", port=8003));
    assert reg.match_route("/api/orders/list").name == "orders";
    assert reg.match_route("/api/payments/charge").name == "payments";
    assert reg.match_route("/api/users/me").name == "users";
}

# =============================================================================
# Deregister
# =============================================================================

test "deregister removes service" {
    reg = ServiceRegistry();
    reg.register(ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders", port=8001));
    assert reg.deregister("orders");
    assert reg.match_route("/api/orders/list") is None;
    assert len(reg.entries) == 0;
}

test "deregister nonexistent returns false" {
    reg = ServiceRegistry();
    assert not reg.deregister("nonexistent");
}

test "deregister preserves other services" {
    reg = ServiceRegistry();
    reg.register(ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders", port=8001));
    reg.register(ServiceEntry(name="payments", file="payments.jac", prefix="/api/payments", port=8002));
    reg.deregister("orders");
    assert reg.match_route("/api/orders/list") is None;
    assert reg.match_route("/api/payments/charge").name == "payments";
}

# =============================================================================
# Health summary
# =============================================================================

test "health summary returns all fields" {
    reg = ServiceRegistry();
    reg.register(ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders", port=8001));
    summary = reg.health_summary();
    assert "orders" in summary;
    assert summary["orders"]["port"] == 8001;
    assert summary["orders"]["status"] == "registered";
    assert summary["orders"]["file"] == "orders.jac";
    assert summary["orders"]["prefix"] == "/api/orders";
    assert summary["orders"]["pid"] is None;
}

# =============================================================================
# Re-register (overwrite)
# =============================================================================

test "register same name overwrites entry" {
    reg = ServiceRegistry();
    reg.register(ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders", port=8001));
    reg.register(ServiceEntry(name="orders", file="orders_new.jac", prefix="/api/orders", port=9001));
    assert len(reg.entries) == 1;
    assert reg.entries["orders"].port == 9001;
    assert reg.entries["orders"].file == "orders_new.jac";
}
