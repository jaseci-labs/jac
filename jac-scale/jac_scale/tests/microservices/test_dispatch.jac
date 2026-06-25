"""Test the gateway dispatch classifier's non-obvious decisions: longest-prefix
proxy match, admin precedence over a colliding service, and SPA fallthrough. The
common-case kinds are exercised by the runtime integration test."""

import from jac_scale.runtime.gateway.dispatch {
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
    # `/orders` with no member subpath is an SPA route; it must render the SPA
    # (static) rather than proxy to the orders service. This is what lets the
    # no-/api/ scheme host a service and a same-named SPA route together.
    assert classify_route("/orders", ["/orders"]).kind == ROUTE_STATIC;
}


test "a non-member subpath under a service prefix is the SPA's" {
    # `/orders/42` is an SPA deep-link (e.g. order detail), not a service member
    # path; only `/orders/<walker|function|...>` belongs to the service.
    assert classify_route("/orders/42", ["/orders"]).kind == ROUTE_STATIC;
}


test "a member subpath proxies even when an SPA owns the bare prefix" {
    assert classify_route("/orders/walker/Place", ["/orders"]).kind == ROUTE_PROXY;
}
