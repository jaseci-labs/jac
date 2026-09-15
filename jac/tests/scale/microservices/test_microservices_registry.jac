import from jaclang.scale.runtime.gateway.service_registry {
    ServiceRegistry,
    ServiceEntry,
    ServiceStatus
}

test "service entry has correct defaults" {
    `entry = ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders");
    assert `entry.port == 0;
    assert `entry.url == "";
    assert `entry.pid is None;
    assert `entry.status == ServiceStatus.REGISTERED;
    assert `entry.replicas == 1;
    assert `entry.env == {};
}

test "service entry accepts custom fields" {
    `entry = ServiceEntry(
        name="payments",
        file="payments.jac",
        prefix="/api/payments",
        port=8002,
        replicas=3,
        env={"STRIPE_KEY": "sk_test"}
    );
    assert `entry.port == 8002;
    assert `entry.replicas == 3;
    assert `entry.env["STRIPE_KEY"] == "sk_test";
}

test "register and lookup by path" {
    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders", port=8001)
    );
    found = reg.match_route("/api/orders/list");
    assert found is not None;
    assert found.name == "orders";
}

test "exact prefix matches" {
    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders", port=8001)
    );
    found = reg.match_route("/api/orders");
    assert found is not None;
    assert found.name == "orders";
}

test "no match returns none" {
    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders", port=8001)
    );
    assert reg.match_route("/api/unknown") is None;
    assert reg.match_route("/health") is None;
    assert reg.match_route("/") is None;
}

test "prefix boundary does not match partial names" {
    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders", port=8001)
    );
    assert reg.match_route("/api/ordershistory") is None;
}

test "empty registry returns none" {
    reg = ServiceRegistry();
    assert reg.match_route("/api/anything") is None;
    assert reg.health_summary() == {};
}

test "longest prefix wins" {
    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders", port=8001)
    );
    reg.register(
        ServiceEntry(
            name="orders_v2", file="orders_v2.jac", prefix="/api/orders/v2", port=8002
        )
    );
    matched_v2 = reg.match_route("/api/orders/v2/list");
    assert matched_v2 is not None;
    assert matched_v2.name == "orders_v2";
    matched_v1 = reg.match_route("/api/orders/list");
    assert matched_v1 is not None;
    assert matched_v1.name == "orders";
}

test "multiple services route correctly" {
    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders", port=8001)
    );
    reg.register(
        ServiceEntry(
            name="payments", file="payments.jac", prefix="/api/payments", port=8002
        )
    );
    reg.register(
        ServiceEntry(name="users", file="users.jac", prefix="/api/users", port=8003)
    );
    matched_orders = reg.match_route("/api/orders/list");
    assert matched_orders is not None;
    assert matched_orders.name == "orders";
    matched_payments = reg.match_route("/api/payments/charge");
    assert matched_payments is not None;
    assert matched_payments.name == "payments";
    matched_users = reg.match_route("/api/users/me");
    assert matched_users is not None;
    assert matched_users.name == "users";
}

test "deregister removes service" {
    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders", port=8001)
    );
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
    reg.register(
        ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders", port=8001)
    );
    reg.register(
        ServiceEntry(
            name="payments", file="payments.jac", prefix="/api/payments", port=8002
        )
    );
    reg.deregister("orders");
    assert reg.match_route("/api/orders/list") is None;
    matched_payments = reg.match_route("/api/payments/charge");
    assert matched_payments is not None;
    assert matched_payments.name == "payments";
}

test "health summary returns all fields" {
    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders", port=8001)
    );
    summary = reg.health_summary();
    assert "orders" in summary;
    assert summary["orders"]["port"] == 8001;
    assert summary["orders"]["status"] == "registered";
    assert summary["orders"]["file"] == "orders.jac";
    assert summary["orders"]["prefix"] == "/api/orders";
    assert summary["orders"]["pid"] is None;
}

test "register same name overwrites entry" {
    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders", port=8001)
    );
    reg.register(
        ServiceEntry(
            name="orders", file="orders_new.jac", prefix="/api/orders", port=9001
        )
    );
    assert len(reg.entries) == 1;
    assert reg.entries["orders"].port == 9001;
    assert reg.entries["orders"].file == "orders_new.jac";
}
