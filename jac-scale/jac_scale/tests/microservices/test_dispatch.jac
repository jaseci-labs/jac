"""Test the gateway dispatch classifier's non-obvious decisions: longest-prefix
proxy match, admin precedence over a colliding service, and SPA fallthrough. The
common-case kinds are exercised by the runtime integration test."""

import from jac_scale.runtime.gateway.dispatch {
    classify_route,
    ROUTE_ADMIN,
    ROUTE_PROXY,
    ROUTE_STATIC
}


test "proxy uses the longest matching service prefix" {
    decision = classify_route("/api/orders/x", ["/api/o", "/api/orders"]);
    assert decision.kind == ROUTE_PROXY;
    assert decision.service == "/api/orders";
}


test "admin is dispatched before a service that would prefix-match it" {
    assert classify_route("/admin/settings", ["/admin"]).kind == ROUTE_ADMIN;
}


test "an unmatched path falls through to static instead of a service" {
    assert classify_route("/dashboard", ["/api/orders"]).kind == ROUTE_STATIC;
}
