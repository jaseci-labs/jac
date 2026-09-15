import from jaclang.scale.runtime.routing {
    guard_route_prefix,
    is_gateway_owned_segment,
    is_learnable_prefix,
    GATEWAY_API_SEGMENTS,
    GATEWAY_WELLKNOWN_SEGMENTS,
    GATEWAY_CLIENT_SEGMENT,
    GATEWAY_BUILTIN_PREFIXES,
    GATEWAY_DISCOVERY_SEGMENTS,
    GATEWAY_LISTING_SEGMENTS,
    GATEWAY_REPLICATED_SEGMENTS,
    GATEWAY_SERVICE_OWNED_SEGMENTS
}


test "an app route under a gateway segment is rejected" {
    caught = "";
    try {
        guard_route_prefix("myapp", "/admin");
    } except ValueError as e {
        caught = str(e);
    }
    assert "owned by the gateway" in caught , caught;
    assert "[apps.myapp] route" in caught , caught;
}


test "a nested route under a gateway segment is rejected" {
    caught = False;
    try {
        guard_route_prefix("myapp", "/user/panel");
    } except ValueError {
        caught = True;
    }
    assert caught;
}


test "every gateway-owned segment refuses to be an app route" {
    for seg in list(GATEWAY_API_SEGMENTS) + list(GATEWAY_WELLKNOWN_SEGMENTS) {
        assert is_gateway_owned_segment(seg) , seg;
    }
    assert is_gateway_owned_segment(GATEWAY_CLIENT_SEGMENT);
    assert is_gateway_owned_segment("admin");
    assert not is_gateway_owned_segment("api");
}


test "the default /api/<name> route never shadows a builtin path" {
    guard_route_prefix("orders", "/api/orders");
    guard_route_prefix("cart", "/shop/cart");
}


test "every builtin gateway prefix is gateway-owned" {
    for prefix in GATEWAY_BUILTIN_PREFIXES {
        assert is_gateway_owned_segment(prefix.strip("/"));
    }
}


test "builtin families partition the API segments the guard reserves" {
    discovery = set(GATEWAY_DISCOVERY_SEGMENTS);
    replicated = set(GATEWAY_REPLICATED_SEGMENTS);
    owned = set(GATEWAY_SERVICE_OWNED_SEGMENTS);
    assert not (discovery & replicated);
    assert not (owned & (discovery | replicated));
    assert owned | replicated | (discovery - {GATEWAY_CLIENT_SEGMENT})
        == set(GATEWAY_API_SEGMENTS);
    assert GATEWAY_CLIENT_SEGMENT in discovery;
    for seg in ["walker", "function", "webhook"] {
        assert seg in owned;
    }
    assert set(GATEWAY_LISTING_SEGMENTS) == {"walkers", "functions"};
}


test "only concrete members of service-owned families are learnable" {
    assert is_learnable_prefix("/walker/create_user");
    assert is_learnable_prefix("/api/orders");
    for prefix in [
        "/walker",
        "/function",
        "/webhook",
        "/cl",
        "/cl/dashboard",
        "/user/login",
        "/sso/firebase/token",
        "/api-key/create",
        "/jobs",
        "/graph/data",
        "/healthz/live",
        "/admin/users"
    ] {
        assert not is_learnable_prefix(prefix) , (
            f"{prefix} must never be handed to a single app"
        );
    }
}
