"""Tests for sv-to-sv Authorization header forwarding via the plugin's
sv_service_call hookimpl.

Covers:
  - _auth_ctx.set/get/reset semantics
  - plugin override reads the current auth token and forwards it
  - no auth set -> no header added
"""

import httpx;
import from typing { Any }
import from jaclang.runtimelib { sv_client }
import from jac_scale.microservices._auth_ctx {
    set_current_auth, reset_current_auth, get_current_auth
}
import from jac_scale.plugin { JacScalePlugin }


# =============================================================================
# Test helper: mock-backed httpx.Client
# =============================================================================
# The plugin's sv_service_call uses httpx.Client(timeout=...).stream("POST", ...)
# to inspect Content-Type before consuming the body (so it can pivot to SSE
# streaming when the downstream returns a generator). For tests we need to
# intercept at the Client level — `transport=MockTransport(handler)` lets a
# real Client serve canned Responses without doing real I/O. Both .stream()
# and .post() on the Client go through the transport, so a single helper
# covers every existing test pattern (plain JSON, ConnectError on retry,
# call counting, timeout capture).

def _mock_client_class(handler: Any, on_init: Any = None) -> Any {
    # Returns a *factory callable* (not a class) so the plugin's
    # `httpx.Client(timeout=...)` substitution still works. Subclassing
    # httpx.Client inside a Jac function and calling super().__init__
    # raises 'super' object is not callable (Jac compiles the inner
    # class differently than CPython expects). The factory pattern
    # sidesteps that — we just hand back a fresh real Client backed by
    # our MockTransport on every call.
    #
    # Capture the *original* httpx.Client at helper-construction time:
    # by the time the factory runs, the test has already done
    # `httpx.Client = _mock_client_class(...)`, so calling httpx.Client
    # inside the factory would recurse infinitely.
    transport = httpx.MockTransport(handler);
    real_client_cls = httpx.Client;
    def factory(*args: Any, **kwargs: Any) -> Any {
        if on_init {
            on_init(kwargs);
        }
        return real_client_cls(transport=transport);
    }
    return factory;
}

# =============================================================================
# _auth_ctx
# =============================================================================

test "set/get/reset auth context round-trips" {
    tok = set_current_auth("Bearer abc");
    assert get_current_auth() == "Bearer abc";
    reset_current_auth(tok);
    assert get_current_auth() == "";
}

test "set_current_auth None stores empty string" {
    tok = set_current_auth(None);
    assert get_current_auth() == "";
    reset_current_auth(tok);
}

# =============================================================================
# Plugin sv_service_call override forwards Authorization header
# =============================================================================

test "sv_service_call forwards Authorization header when auth set" {
    captured: dict = {};

    def handler(request: httpx.Request) -> httpx.Response {
        captured["auth"] = request.headers.get("Authorization", "");
        return httpx.Response(
            status_code=200,
            json={"ok": True, "data": {"result": "echoed"}}
        );
    }

    original_client = httpx.Client;
    httpx.Client = _mock_client_class(handler);

    try {
        sv_client.register("demo_mod", "http://demo.invalid");
        tok = set_current_auth("Bearer xyz");
        try {
            result = JacScalePlugin.sv_service_call("demo_mod", "echo", {"x": 1});
        } finally {
            reset_current_auth(tok);
        }

        assert captured["auth"] == "Bearer xyz";
        assert result == "echoed";
    } finally {
        httpx.Client = original_client;
        sv_client.unregister("demo_mod");
    }
}

test "sv_service_call omits Authorization when no auth context" {
    captured: dict = {"auth": "sentinel"};

    def handler(request: httpx.Request) -> httpx.Response {
        captured["auth"] = request.headers.get("Authorization", "");
        return httpx.Response(
            status_code=200,
            json={"ok": True, "data": {"result": "ok"}}
        );
    }

    original_client = httpx.Client;
    httpx.Client = _mock_client_class(handler);

    try {
        sv_client.register("demo_mod2", "http://demo.invalid");
        # Do not set auth; context var default is ""
        result = JacScalePlugin.sv_service_call("demo_mod2", "echo", {});
        assert captured["auth"] == "";
        assert result == "ok";
    } finally {
        httpx.Client = original_client;
        sv_client.unregister("demo_mod2");
    }
}

test "sv_service_call surfaces application-level error from envelope" {
    def handler(request: httpx.Request) -> httpx.Response {
        return httpx.Response(
            status_code=200,
            json={"ok": False, "error": {"code": "X", "message": "boom"}}
        );
    }

    original_client = httpx.Client;
    httpx.Client = _mock_client_class(handler);

    try {
        sv_client.register("demo_mod3", "http://demo.invalid");
        raised = False;
        try {
            JacScalePlugin.sv_service_call("demo_mod3", "fail", {});
        } except RuntimeError as e {
            raised = "boom" in str(e);
        }
        assert raised;
    } finally {
        httpx.Client = original_client;
        sv_client.unregister("demo_mod3");
    }
}

# =============================================================================
# Retry with exponential backoff (ROADMAP P5)
# =============================================================================

test "sv_service_call retries on transport error and succeeds on 2nd attempt" {
    # Simulates: pod is coming up, first connect fails; second succeeds.
    # We count how many times the handler was called - should be 2.
    call_count: dict = {"n": 0};

    def handler(request: httpx.Request) -> httpx.Response {
        call_count["n"] = call_count["n"] + 1;
        if call_count["n"] == 1 {
            raise httpx.ConnectError("connection refused");
        }
        return httpx.Response(
            status_code=200, json={"ok": True, "data": {"result": "ok"}}
        );
    }

    original_client = httpx.Client;
    httpx.Client = _mock_client_class(handler);

    try {
        sv_client.register("retry_mod", "http://demo.invalid");
        result = JacScalePlugin.sv_service_call("retry_mod", "ping", {});
        assert result == "ok";
        assert call_count["n"] == 2;  # first failed, second succeeded
    } finally {
        httpx.Client = original_client;
        sv_client.unregister("retry_mod");
    }
}

test "sv_service_call gives up after max_attempts on persistent transport error" {
    # Simulates: downstream is genuinely unreachable. All 3 attempts
    # fail; caller gets a RuntimeError mentioning "after N attempts".
    call_count: dict = {"n": 0};

    def handler(request: httpx.Request) -> httpx.Response {
        call_count["n"] = call_count["n"] + 1;
        raise httpx.ConnectError("connection refused");
    }

    original_client = httpx.Client;
    httpx.Client = _mock_client_class(handler);

    try {
        sv_client.register("dead_mod", "http://demo.invalid");
        raised_msg = "";
        try {
            JacScalePlugin.sv_service_call("dead_mod", "ping", {});
        } except RuntimeError as e {
            raised_msg = str(e);
        }
        assert call_count["n"] == 3;
        assert "3 attempts" in raised_msg;
    } finally {
        httpx.Client = original_client;
        sv_client.unregister("dead_mod");
    }
}

# =============================================================================
# X-Trace-Id propagation (ROADMAP P7)
# =============================================================================

import from jac_scale.microservices._trace_ctx {
    set_current_trace, reset_current_trace, get_current_trace, ensure_trace_id
}

test "trace_ctx set/get/reset round-trips" {
    tok = set_current_trace("abc-123");
    assert get_current_trace() == "abc-123";
    reset_current_trace(tok);
    assert get_current_trace() == "";
}

test "set_current_trace None stores empty string" {
    tok = set_current_trace(None);
    assert get_current_trace() == "";
    reset_current_trace(tok);
}

test "ensure_trace_id preserves inbound header" {
    assert ensure_trace_id("inbound-xyz") == "inbound-xyz";
}

test "ensure_trace_id mints a UUID4 when no inbound header" {
    minted = ensure_trace_id(None);
    # UUID4 string is 36 chars with 4 dashes; basic shape check
    assert len(minted) == 36;
    assert minted.count("-") == 4;
    # Must differ between calls (statistically; UUID4 collision
    # probability is astronomically low)
    assert ensure_trace_id(None) != minted;
}

test "sv_service_call forwards X-Trace-Id when set in context" {
    captured: dict = {"trace": ""};

    def handler(request: httpx.Request) -> httpx.Response {
        captured["trace"] = request.headers.get("X-Trace-Id", "");
        return httpx.Response(
            status_code=200, json={"ok": True, "data": {"result": "ok"}}
        );
    }

    original_client = httpx.Client;
    httpx.Client = _mock_client_class(handler);

    try {
        sv_client.register("trace_mod", "http://demo.invalid");
        tok = set_current_trace("test-trace-xyz");
        try {
            JacScalePlugin.sv_service_call("trace_mod", "ping", {});
        } finally {
            reset_current_trace(tok);
        }
        assert captured["trace"] == "test-trace-xyz";
    } finally {
        httpx.Client = original_client;
        sv_client.unregister("trace_mod");
    }
}

test "sv_service_call omits X-Trace-Id when no trace context is set" {
    captured: dict = {"trace": "sentinel"};

    def handler(request: httpx.Request) -> httpx.Response {
        captured["trace"] = request.headers.get("X-Trace-Id", "");
        return httpx.Response(
            status_code=200, json={"ok": True, "data": {"result": "ok"}}
        );
    }

    original_client = httpx.Client;
    httpx.Client = _mock_client_class(handler);

    try {
        sv_client.register("trace_mod2", "http://demo.invalid");
        # Don't set trace ctx; default empty string means no header added
        JacScalePlugin.sv_service_call("trace_mod2", "ping", {});
        assert captured["trace"] == "";
    } finally {
        httpx.Client = original_client;
        sv_client.unregister("trace_mod2");
    }
}

# =============================================================================
# Circuit breaker (ROADMAP P6)
# =============================================================================

import from jac_scale.plugin {
    _breaker_reset, _breaker_record_success, _breaker_record_failure,
    _breaker_should_skip, _BREAKER_TRIP_THRESHOLD
}

test "breaker trips OPEN after N consecutive transport failures and fails fast" {
    # Drive the breaker to OPEN directly via the recorder so we don't
    # have to burn N full retry cycles in the test.
    mod = "breaker_open_test";
    _breaker_reset(mod);

    for _ in range(_BREAKER_TRIP_THRESHOLD) {
        _breaker_record_failure(mod);
    }

    # Breaker should now short-circuit any sv_service_call for this mod.
    # Confirm by checking the skip helper directly - no httpx mock needed
    # because the call path raises before any network I/O.
    assert _breaker_should_skip(mod);

    # And a real sv_service_call should fail fast with the breaker msg.
    # We don't even register the URL: if the breaker opens correctly,
    # the call never gets as far as URL resolution.
    raised_msg = "";
    try {
        JacScalePlugin.sv_service_call(mod, "anything", {});
    } except RuntimeError as e {
        raised_msg = str(e);
    }
    assert "open circuit breaker" in raised_msg;

    _breaker_reset(mod);
}

test "breaker success recorder resets failure count" {
    mod = "breaker_reset_test";
    _breaker_reset(mod);

    # Fail threshold-1 times (one short of tripping)
    for _ in range(_BREAKER_TRIP_THRESHOLD - 1) {
        _breaker_record_failure(mod);
    }
    assert not _breaker_should_skip(mod);

    # A success resets the counter
    _breaker_record_success(mod);

    # Now threshold-1 more failures should NOT trip (counter was reset)
    for _ in range(_BREAKER_TRIP_THRESHOLD - 1) {
        _breaker_record_failure(mod);
    }
    assert not _breaker_should_skip(mod);

    _breaker_reset(mod);
}

test "HALF_OPEN probe success closes the breaker" {
    # Simulate: breaker OPEN, cooldown elapses, probe succeeds.
    # Without waiting 30s we use _breaker_force_cooldown_elapsed.
    import from jac_scale.plugin {
        _breaker_peek, _breaker_force_cooldown_elapsed
    }

    mod = "breaker_half_open_test";
    _breaker_reset(mod);

    for _ in range(_BREAKER_TRIP_THRESHOLD) {
        _breaker_record_failure(mod);
    }
    assert _breaker_should_skip(mod);

    # Force cooldown elapsed, next skip-check transitions OPEN -> HALF_OPEN
    _breaker_force_cooldown_elapsed(mod);
    assert not _breaker_should_skip(mod);
    st = _breaker_peek(mod);
    assert st is not None and st["state"] == "HALF_OPEN";

    # Probe success closes the breaker fully
    _breaker_record_success(mod);
    st = _breaker_peek(mod);
    assert st is not None and st["state"] == "CLOSED";
    assert st["fails"] == 0;

    _breaker_reset(mod);
}

test "application error envelope does NOT trip the breaker" {
    # 5 application-error calls in a row should NOT open the breaker -
    # only transport errors count. Verified by calling through the real
    # hookimpl with a mock that always returns ok=false.
    mod = "breaker_app_err_test";
    _breaker_reset(mod);

    def handler(request: httpx.Request) -> httpx.Response {
        return httpx.Response(
            status_code=200,
            json={"ok": False, "error": {"code": "X", "message": "nope"}}
        );
    }

    original_client = httpx.Client;
    httpx.Client = _mock_client_class(handler);

    try {
        sv_client.register(mod, "http://demo.invalid");
        for _ in range(_BREAKER_TRIP_THRESHOLD) {
            try {
                JacScalePlugin.sv_service_call(mod, "fail", {});
            } except RuntimeError {
                ;
            }
        }
        # Breaker should still be CLOSED - app errors don't count
        assert not _breaker_should_skip(mod);
    } finally {
        httpx.Client = original_client;
        sv_client.unregister(mod);
        _breaker_reset(mod);
    }
}

test "sv_service_call does NOT retry on application error envelope" {
    # Simulates: downstream returns 200 with ok=false (application-level
    # error). Retrying won't change the answer, so we give up after 1
    # request and raise immediately.
    call_count: dict = {"n": 0};

    def handler(request: httpx.Request) -> httpx.Response {
        call_count["n"] = call_count["n"] + 1;
        return httpx.Response(
            status_code=200,
            json={"ok": False, "error": {"code": "X", "message": "deterministic_fail"}}
        );
    }

    original_client = httpx.Client;
    httpx.Client = _mock_client_class(handler);

    try {
        sv_client.register("app_err_mod", "http://demo.invalid");
        raised_msg = "";
        try {
            JacScalePlugin.sv_service_call("app_err_mod", "fail", {});
        } except RuntimeError as e {
            raised_msg = str(e);
        }
        # Exactly one call: application errors don't retry
        assert call_count["n"] == 1;
        assert "deterministic_fail" in raised_msg;
    } finally {
        httpx.Client = original_client;
        sv_client.unregister("app_err_mod");
    }
}


test "sv_service_call uses the default 10s timeout when no per-service override" {
    captured: dict = {};

    def handler(request: httpx.Request) -> httpx.Response {
        return httpx.Response(
            status_code=200,
            json={"ok": True, "data": {"result": "done"}}
        );
    }

    def on_init(kwargs: dict) -> None {
        captured["timeout"] = kwargs.get("timeout");
    }

    original_client = httpx.Client;
    httpx.Client = _mock_client_class(handler, on_init=on_init);

    try {
        sv_client.register("default_to_mod", "http://demo.invalid");
        JacScalePlugin.sv_service_call("default_to_mod", "run", {});
        assert captured["timeout"] == 10.0;
    } finally {
        httpx.Client = original_client;
        sv_client.unregister("default_to_mod");
    }
}


test "sv_service_call honors per-service rpc_timeout from config" {
    import jac_scale.plugin as plugin_mod;
    captured: dict = {};

    def handler(request: httpx.Request) -> httpx.Response {
        return httpx.Response(
            status_code=200,
            json={"ok": True, "data": {"result": "done"}}
        );
    }

    def on_init(kwargs: dict) -> None {
        captured["timeout"] = kwargs.get("timeout");
    }

    original_client = httpx.Client;
    httpx.Client = _mock_client_class(handler, on_init=on_init);

    # Patch _sv_rpc_timeout to avoid depending on a jac.toml fixture.
    original_resolver = getattr(plugin_mod, "_sv_rpc_timeout");
    def fake_resolver(module_name: str) -> float {
        return 75.5 if module_name == "slow_mod" else 10.0;
    }
    setattr(plugin_mod, "_sv_rpc_timeout", fake_resolver);

    try {
        sv_client.register("slow_mod", "http://demo.invalid");
        JacScalePlugin.sv_service_call("slow_mod", "run", {});
        assert captured["timeout"] == 75.5;
    } finally {
        setattr(plugin_mod, "_sv_rpc_timeout", original_resolver);
        httpx.Client = original_client;
        sv_client.unregister("slow_mod");
    }
}


test "_sv_rpc_timeout returns default when config lookup fails" {
    import from jac_scale.plugin { _sv_rpc_timeout }
    t: float = _sv_rpc_timeout("module_that_has_no_override");
    assert t == 10.0;
}
