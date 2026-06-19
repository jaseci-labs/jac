"""Client-runtime service-routing tests (run under bun via the cl test runner).

These exercise the real compiled `@jac/runtime` `__jacCallFunction` /
`__jacSpawn` with `fetch` mocked, locking in the import-path-provenance
routing contract:

  * with a service->prefix map present, a cross-module call (carrying its
    source-module stem) routes to `<prefix>/function/<name>` (or
    `<prefix>/walker/<name>`);
  * with no map - or a module the map doesn't know - the call falls back to
    the flat `/function/<name>` path, so monolith output is unchanged.

The map normally arrives in the `__jac_init__` JSON the host injects; here we
seed `globalThis.__jacServiceRoutes__` directly (the value `__getServiceRoutes`
caches) so the test needs no DOM.
"""

# `__jacSpawn` is auto-prepended as a runtime global by the cl test harness
# (the same bare global the compiler emits for `spawn`), so it is NOT imported
# here - only `__jacCallFunction` needs an explicit `@jac/runtime` import.
import from "@jac/runtime" { __jacCallFunction }

"""Mock `fetch` Response: `.ok` plus a `.json()` resolving to `body`."""
def _resp(body: dict) -> dict {
    return {
        "ok": True,
        "status": 200,
        "json": lambda -> any { return Promise.resolve(body); }
    };
}

"""Install a fetch mock that records every URL into `urls` and replies `body`."""
def _capture(urls: list, body: dict) -> None {
    globalThis.fetch = lambda url: any , opts: any -> any {
        urls.append(url);
        return Promise.resolve(_resp(body));
    };
}

test "function call routes to the service prefix when the map is present" {
    globalThis.__jacServiceRoutes__ = {"orders_app": "/api/orders"};
    globalThis.__jacEndpointEffects__ = {};
    urls = [];
    _capture(urls, {"ok": True, "data": {"result": {"id": "ord_1"}}});

    res = await __jacCallFunction("create_order", {}, "orders_app");

    assert len(urls) == 1;
    assert urls[0] == "/api/orders/function/create_order" , urls[0];
    assert res["id"] == "ord_1";

    globalThis.fetch = undefined;
}

test "function call falls back to the flat path without a usable map" {
    globalThis.__jacServiceRoutes__ = {};
    globalThis.__jacEndpointEffects__ = {};
    urls = [];
    _capture(urls, {"ok": True, "data": {"result": []}});

    # No module arg at all (the monolith shape) -> flat path.
    await __jacCallFunction("list_products", {});
    # A module arg the empty map cannot resolve -> still flat (graceful).
    await __jacCallFunction("list_products", {}, "products_app");

    assert urls[0] == "/function/list_products" , urls[0];
    assert urls[1] == "/function/list_products" , urls[1];

    globalThis.fetch = undefined;
}

test "walker spawn routes to the service prefix when the map is present" {
    globalThis.__jacServiceRoutes__ = {"orders_app": "/api/orders"};
    globalThis.__jacEndpointEffects__ = {};
    urls = [];
    _capture(urls, {"data": {"reports": []}});

    # Cross-module spawn carries its source-module stem as the 4th arg.
    await __jacSpawn("CreateOrder", "", {}, "orders_app");
    # Same-runtime spawn with no module -> flat walker path.
    await __jacSpawn("Ping", "", {});

    assert urls[0] == "/api/orders/walker/CreateOrder" , urls[0];
    assert urls[1] == "/walker/Ping" , urls[1];

    globalThis.fetch = undefined;
}
