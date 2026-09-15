import from jaclang.scale.runtime.gateway.dispatch {
    classify_route,
    ROUTE_ADMIN,
    ROUTE_PROXY,
    ROUTE_STATIC
}


test "proxy uses the longest matching service prefix on a member subpath" {
    decision = classify_route("/orders/function/create", ["/o", "/orders"]);
    assert decision.kind == ROUTE_PROXY;
    assert decision.service == "/orders";
}


test "admin is dispatched before a service that would prefix-match it" {
    assert classify_route("/admin/settings", ["/admin"]).kind == ROUTE_ADMIN;
}


test "an unmatched path falls through to static instead of a service" {
    assert classify_route("/dashboard", ["/orders"]).kind == ROUTE_STATIC;
}


test "the bare service prefix is the SPA's, not the proxy's" {
    assert classify_route("/orders", ["/orders"]).kind == ROUTE_STATIC;
}


test "a non-member subpath under a service prefix is the SPA's" {
    assert classify_route("/orders/42", ["/orders"]).kind == ROUTE_STATIC;
}


test "a member subpath proxies even when an SPA owns the bare prefix" {
    assert classify_route("/orders/walker/Place", ["/orders"]).kind == ROUTE_PROXY;
}
