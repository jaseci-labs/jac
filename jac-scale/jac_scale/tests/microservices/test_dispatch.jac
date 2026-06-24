"""Tests for the gateway request-dispatch classifier."""

import from jac_scale.runtime.gateway.dispatch {
    classify_route,
    ROUTE_BUILTIN,
    ROUTE_ADMIN,
    ROUTE_PROXY,
    ROUTE_PASSTHROUGH,
    ROUTE_STATIC
}


test "builtin exact paths classify as builtin" {
    assert classify_route("/health", []).kind == ROUTE_BUILTIN;
    assert classify_route("/healthz/ready", []).kind == ROUTE_BUILTIN;
    assert classify_route("/metrics", []).kind == ROUTE_BUILTIN;
    assert classify_route("/openapi.json", []).kind == ROUTE_BUILTIN;
}


test "admin paths classify as admin" {
    assert classify_route("/admin", []).kind == ROUTE_ADMIN;
    assert classify_route("/admin/users", []).kind == ROUTE_ADMIN;
}


test "a path under a service prefix proxies to that service" {
    decision = classify_route("/api/orders/function/create", ["/api/orders"]);
    assert decision.kind == ROUTE_PROXY;
    assert decision.service == "/api/orders";
}


test "proxy uses the longest matching prefix" {
    decision = classify_route("/api/orders/x", ["/api/o", "/api/orders"]);
    assert decision.service == "/api/orders";
}


test "builtin verb segments fan out as passthrough" {
    assert classify_route("/walker/Foo", []).kind == ROUTE_PASSTHROUGH;
    assert classify_route("/function/bar", []).kind == ROUTE_PASSTHROUGH;
}


test "unmatched paths fall through to static (SPA)" {
    assert classify_route("/", []).kind == ROUTE_STATIC;
    assert classify_route("/dashboard", ["/api/orders"]).kind == ROUTE_STATIC;
}


test "admin wins over a service that would prefix-match it" {
    # /admin is dispatched before service proxy, so an /admin path is never
    # captured by a service even if a prefix could match.
    assert classify_route("/admin/settings", ["/admin"]).kind == ROUTE_ADMIN;
}
