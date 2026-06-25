"""Client-runtime native-IPC bridge tests (run under bun via the cl test runner).

These exercise the real compiled `@jac/runtime` walker/function dispatch with
the Jac-native desktop host's globals mocked, so no webview, host, or backend is
needed. They lock in the native branch added to `__doWalkerFetch` /
`__doFuncFetch`: when `globalThis.__JAC_NATIVE__` is truthy and
`globalThis.__jac_invoke` exists, calls route over that bridge (with the frozen
`{kind, name, node, fields, token}` payload) instead of HTTP `fetch`. The reply
mirrors a fetch Response -- `{status, ok, body}` with `body` the `{ok, data,
error}` envelope -- so the runtime can replay the HTTP status logic (401 ->
re-login) and still unwrap `body` like the HTTP path.
"""

import from "@jac/runtime" { __jacCallFunction, __setLocalStorage, __getLocalStorage }

# Note: `__jacSpawn` is auto-imported by the cl test harness prelude, so it is
# already in scope here -- re-importing it would be a duplicate declaration.
"""Install a mock native host; returns the list that records each invoke payload
(the JSON string the runtime passes to `__jac_invoke`). `reply` is the full
bridge reply object `{status, ok, body}`."""
def _install_native(reply: dict) -> list {
    seen = [];
    globalThis.__JAC_NATIVE__ = True;
    # The host JSON-parses its reply before resolving, so the runtime receives
    # an already-decoded object -- the mock resolves one directly (no stringify).
    globalThis.__jac_invoke = lambda payload: any -> any {
        seen.append(payload);
        return Promise.resolve(reply);
    };
    return seen;
}

"""Tear the mock host down so later suites see a clean web environment."""
def _clear_native {
    globalThis.__JAC_NATIVE__ = False;
    globalThis.__jac_invoke = undefined;
}

"""Stub `window.location.reload` (the 401 path) and record each call."""
def _install_window_reload -> list {
    reloads = [];
    globalThis.window = {"location": {"reload": lambda { reloads.append(1); }}};
    return reloads;
}

def _clear_window_reload {
    globalThis.window = undefined;
}

test "walker call routes through the native bridge and unwraps data" {
    __setLocalStorage("jac_token", "tok-w");
    # `login` is an auth walker -> skips the cache layer, hits __doWalkerFetch.
    seen = _install_native(
        {"status": 200, "ok": True, "body": {"ok": True, "data": {"user": "ada"}}}
    );

    out = await __jacSpawn("login", "n-7", {"email": "ada@x.io"});

    # Returned data is the unwrapped envelope `data`.
    assert out["user"] == "ada";
    # Exactly one bridge call, carrying the frozen payload shape.
    assert len(seen) == 1;
    sent = JSON.parse(seen[0]);
    assert sent["kind"] == "walker";
    assert sent["name"] == "login";
    assert sent["node"] == "n-7";
    assert sent["fields"]["email"] == "ada@x.io";
    assert sent["token"] == "tok-w";

    _clear_native();
}

test "walker 401 clears the token and triggers a reload" {
    __setLocalStorage("jac_token", "stale-tok");
    reloads = _install_window_reload();
    _install_native(
        {"status": 401, "ok": False, "body": {"ok": False, "error": "expired"}}
    );

    out = await __jacSpawn("login", "", {});

    # 401 -> token cleared, one reload requested, returns {} without throwing.
    tok = __getLocalStorage("jac_token");
    assert tok == None or tok == "";
    assert len(reloads) == 1;
    assert len(Object.keys(out)) == 0;

    _clear_window_reload();
    _clear_native();
}

test "walker unknown-endpoint 404 body raises" {
    __setLocalStorage("jac_token", "");
    # An unknown walker yields a raw FastAPI 404 body (not an envelope); the
    # native branch still classifies it (no `ok`) and raises rather than hanging.
    _install_native({"status": 404, "ok": False, "body": {"detail": "Not Found"}});

    raised = False;
    # `except Exception` is the catch-all here: in the cl/ecmascript runtime it
    # lowers to `_jac.exc.matches(e, "Exception")`, which matches every Jac
    # `Exception` *and* any native JS throw -- so it fires regardless of which
    # module's `Exception` class the runtime raised. We only assert that it raised.
    try {
        await __jacSpawn("login", "", {});
    } except Exception {
        raised = True;
    }
    assert raised == True;

    _clear_native();
}

test "walker bridge error envelope raises" {
    __setLocalStorage("jac_token", "");
    _install_native(
        {"status": 200, "ok": False, "body": {"ok": False, "error": "boom"}}
    );

    raised = False;
    # `except Exception` catch-all (see the 404 test): only that it raised matters.
    try {
        await __jacSpawn("login", "", {});
    } except Exception {
        raised = True;
    }
    assert raised == True;

    _clear_native();
}

test "function call routes through the native bridge and unwraps result" {
    __setLocalStorage("jac_token", "tok-f");
    # Unknown endpoint (no effects metadata) -> __cachedEndpointCall falls
    # straight through to __doFuncFetch.
    seen = _install_native(
        {"status": 200, "ok": True, "body": {"ok": True, "data": {"result": 42}}}
    );

    out = await __jacCallFunction("add", {"a": 1, "b": 2});

    assert out == 42;
    assert len(seen) == 1;
    sent = JSON.parse(seen[0]);
    assert sent["kind"] == "function";
    assert sent["name"] == "add";
    # Functions carry no node; args travel in `fields`.
    assert sent["node"] == "";
    assert sent["fields"]["a"] == 1;
    assert sent["token"] == "tok-f";

    _clear_native();
}

test "function bridge error envelope raises" {
    __setLocalStorage("jac_token", "");
    _install_native(
        {"status": 200, "ok": False, "body": {"ok": False, "error": "nope"}}
    );

    raised = False;
    # `except Exception` catch-all (see the walker error test): only that it raised.
    try {
        await __jacCallFunction("add", {});
    } except Exception {
        raised = True;
    }
    assert raised == True;

    _clear_native();
}
