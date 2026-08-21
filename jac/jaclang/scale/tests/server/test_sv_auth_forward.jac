import jaclang.runtimelib.serving.client as sv_http;
import from jaclang.runtimelib { sv_client }
import from jaclang.scale.runtime.context.auth_ctx {
    set_current_auth,
    reset_current_auth,
    get_current_auth
}
import from jaclang.scale.plugin { JacScalePlugin }
import jaclang.scale.runtime.rpc.rpc as rpc_mod;


obj _MockRequest {
    has url: str = '',
        headers: dict[str, str] = {},
        timeout: float = 0.0,
        json_body: any = None;
}

obj _MockResponse {
    has json_payload: any = None;
}

def _install_mock(handler: any) -> any {
    original = sv_http.post_stream_aware_sync;

    def fake(
        url: str,
        json_body: any = None,
        headers: (dict | None) = None,
        timeout: float = 30.0,
        label: str = ''
    ) -> tuple[str, any] {
        request = _MockRequest(
            url=url, headers=headers or {}, timeout=timeout, json_body=json_body
        );
        return ('json', handler(request).json_payload);
    }
    sv_http.post_stream_aware_sync = fake;
    return original;
}

"""Pin rpc_timeout for one module; every other module keeps the real resolver."""
def _install_rpc_timeout(module_name: str, seconds: float) -> any {
    original = getattr(rpc_mod, "_sv_rpc_timeout");

    def resolver(name: str) -> float {
        return seconds if name == module_name else original(name);
    }
    setattr(rpc_mod, "_sv_rpc_timeout", resolver);
    return original;
}

def _restore_rpc_timeout(original: any) {
    setattr(rpc_mod, "_sv_rpc_timeout", original);
}

"""Replace the function transport with one that always fails to connect."""
def _install_unreachable_transport(round_trips: dict) -> any {
    import from jaclang.runtimelib.serving.client { ClientRequestNotSent }
    original = sv_http.post_stream_aware_sync;

    def fake(*args: any, **kwargs: any) -> tuple[str, any] {
        round_trips["n"] = round_trips["n"] + 1;
        raise ClientRequestNotSent(detail="connection refused");
    }
    sv_http.post_stream_aware_sync = fake;
    return original;
}

"""Replace the walker transport with one that always fails to connect."""
def _install_unreachable_walker_transport(round_trips: dict) -> any {
    import from jaclang.runtimelib.serving.client { ClientRequestNotSent }
    original = sv_http.request_sync;

    def fake(*args: any, **kwargs: any) -> any {
        round_trips["n"] = round_trips["n"] + 1;
        raise ClientRequestNotSent(detail="connection refused");
    }
    sv_http.request_sync = fake;
    return original;
}

obj _StubMsCfg {
    has data: dict[str, any];

    def get_microservices_config -> dict[str, any] {
        return self.data;
    }
}

"""Point the scale config loader at an in-memory microservices config."""
def _install_ms_config(data: dict[str, any]) -> any {
    import jaclang.scale.config.config_loader as cfg_mod;
    original = getattr(cfg_mod, "get_scale_config");
    setattr(cfg_mod, "get_scale_config", lambda { _StubMsCfg(data=data); });
    return original;
}

def _restore_ms_config(original: any) {
    import jaclang.scale.config.config_loader as cfg_mod;
    setattr(cfg_mod, "get_scale_config", original);
}

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

test "sv_service_call forwards Authorization header when auth set" {
    captured: dict = {};

    def handler(request: _MockRequest) -> _MockResponse {
        captured["auth"] = request.headers.get("Authorization", "");
        return _MockResponse(json_payload={"ok": True, "data": {"result": "echoed"}});
    }

    original_post = _install_mock(handler);

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
        sv_http.post_stream_aware_sync = original_post;
        sv_client.unregister("demo_mod");
    }
}

test "sv_service_call omits Authorization when no auth context" {
    captured: dict = {"auth": "sentinel"};

    def handler(request: _MockRequest) -> _MockResponse {
        captured["auth"] = request.headers.get("Authorization", "");
        return _MockResponse(json_payload={"ok": True, "data": {"result": "ok"}});
    }

    original_post = _install_mock(handler);

    try {
        sv_client.register("demo_mod2", "http://demo.invalid");

        result = JacScalePlugin.sv_service_call("demo_mod2", "echo", {});
        assert captured["auth"] == "";
        assert result == "ok";
    } finally {
        sv_http.post_stream_aware_sync = original_post;
        sv_client.unregister("demo_mod2");
    }
}

test "sv_service_call surfaces application-level error from envelope" {
    def handler(request: _MockRequest) -> _MockResponse {
        return _MockResponse(
            json_payload={"ok": False, "error": {"code": "X", "message": "boom"}}
        );
    }

    original_post = _install_mock(handler);

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
        sv_http.post_stream_aware_sync = original_post;
        sv_client.unregister("demo_mod3");
    }
}

test "sv_service_call retries on transport error and succeeds on 2nd attempt" {
    call_count: dict = {"n": 0};

    def handler(request: _MockRequest) -> _MockResponse {
        call_count["n"] = call_count["n"] + 1;
        if call_count["n"] == 1 {
            raise sv_http.ClientRequestNotSent("connection refused");
        }
        return _MockResponse(json_payload={"ok": True, "data": {"result": "ok"}});
    }

    original_post = _install_mock(handler);

    try {
        sv_client.register("retry_mod", "http://demo.invalid");
        result = JacScalePlugin.sv_service_call("retry_mod", "ping", {});
        assert result == "ok";
        assert call_count["n"] == 2;
    } finally {
        sv_http.post_stream_aware_sync = original_post;
        sv_client.unregister("retry_mod");
    }
}

test "sv_service_call gives up after max_attempts on persistent transport error" {
    call_count: dict = {"n": 0};

    def handler(request: _MockRequest) -> _MockResponse {
        call_count["n"] = call_count["n"] + 1;
        raise sv_http.ClientRequestNotSent("connection refused");
    }

    original_post = _install_mock(handler);

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
        sv_http.post_stream_aware_sync = original_post;
        sv_client.unregister("dead_mod");
    }
}

import from jaclang.scale.runtime.context.trace_ctx {
    set_current_trace,
    reset_current_trace,
    get_current_trace,
    ensure_trace_id
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

    assert len(minted) == 36;
    assert minted.count("-") == 4;

    assert ensure_trace_id(None) != minted;
}

test "sv_service_call forwards X-Trace-Id when set in context" {
    captured: dict = {"trace": ""};

    def handler(request: _MockRequest) -> _MockResponse {
        captured["trace"] = request.headers.get("X-Trace-Id", "");
        return _MockResponse(json_payload={"ok": True, "data": {"result": "ok"}});
    }

    original_post = _install_mock(handler);

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
        sv_http.post_stream_aware_sync = original_post;
        sv_client.unregister("trace_mod");
    }
}

test "sv_service_call omits X-Trace-Id when no trace context is set" {
    captured: dict = {"trace": "sentinel"};

    def handler(request: _MockRequest) -> _MockResponse {
        captured["trace"] = request.headers.get("X-Trace-Id", "");
        return _MockResponse(json_payload={"ok": True, "data": {"result": "ok"}});
    }

    original_post = _install_mock(handler);

    try {
        sv_client.register("trace_mod2", "http://demo.invalid");

        JacScalePlugin.sv_service_call("trace_mod2", "ping", {});
        assert captured["trace"] == "";
    } finally {
        sv_http.post_stream_aware_sync = original_post;
        sv_client.unregister("trace_mod2");
    }
}

import from jaclang.scale.runtime.rpc.breaker {
    _breaker_reset,
    _breaker_peek,
    _breaker_force_cooldown_elapsed,
    _breaker_force_probe_expired,
    breaker_admit,
    breaker_still_admitted,
    breaker_record_success,
    breaker_record_failure,
    breaker_should_skip,
    _BREAKER_TRIP_THRESHOLD
}

glob _PROBE_TTL: float = 60.0;

"""Trip the breaker OPEN without going through the transport."""
def _trip_breaker(mod: str) {
    _breaker_reset(mod);
    for _ in range(_BREAKER_TRIP_THRESHOLD) {
        breaker_record_failure(mod);
    }
}

"""Take the HALF_OPEN probe lease the way a real caller would, and return it."""
def _take_probe(mod: str) -> int {
    _breaker_force_cooldown_elapsed(mod);
    (admitted, probe) = breaker_admit(mod, _PROBE_TTL);
    assert admitted and probe != 0;
    return probe;
}

test "breaker trips OPEN after N consecutive transport failures and fails fast" {
    mod = "breaker_open_test";
    _trip_breaker(mod);

    assert breaker_should_skip(mod);

    raised_msg = "";
    try {
        JacScalePlugin.sv_service_call(mod, "anything", {});
    } except RuntimeError as e {
        raised_msg = str(e);
    }
    assert "open circuit breaker" in raised_msg;

    _breaker_reset(mod);
}

test "an open breaker sheds a call before its service URL is resolved" {
    mod = "breaker_unresolved_test";
    _trip_breaker(mod);
    sv_client.unregister(mod);

    call_msg = "";
    try {
        JacScalePlugin.sv_service_call(mod, "anything", {});
    } except RuntimeError as e {
        call_msg = str(e);
    }
    assert "open circuit breaker" in call_msg , (
        f"an unregistered service reported '{call_msg}' instead of the breaker"
    );

    spawn_msg = "";
    try {
        JacScalePlugin.sv_walker_call(mod, "Ping", {}, None);
    } except RuntimeError as e {
        spawn_msg = str(e);
    }
    assert "open circuit breaker" in spawn_msg , (
        f"an unregistered service reported '{spawn_msg}' instead of the breaker"
    );

    _breaker_reset(mod);
}

test "breaker success recorder resets failure count" {
    mod = "breaker_reset_test";
    _breaker_reset(mod);

    for _ in range(_BREAKER_TRIP_THRESHOLD - 1) {
        breaker_record_failure(mod);
    }
    assert not breaker_should_skip(mod);

    breaker_record_success(mod);

    for _ in range(_BREAKER_TRIP_THRESHOLD - 1) {
        breaker_record_failure(mod);
    }
    assert not breaker_should_skip(mod);

    _breaker_reset(mod);
}

test "HALF_OPEN probe success closes the breaker" {
    mod = "breaker_half_open_test";
    _trip_breaker(mod);
    assert breaker_should_skip(mod);

    probe = _take_probe(mod);
    st = _breaker_peek(mod);
    assert st is not None and st["state"] == "HALF_OPEN";

    breaker_record_success(mod, probe);
    st = _breaker_peek(mod);
    assert st is not None and st["state"] == "CLOSED";
    assert st["fails"] == 0;

    _breaker_reset(mod);
}

test "HALF_OPEN probe failure re-opens the breaker with a fresh cooldown" {
    import time;
    mod = "breaker_half_open_reopen_test";
    _trip_breaker(mod);
    assert breaker_should_skip(mod);

    probe = _take_probe(mod);
    st = _breaker_peek(mod);
    assert st is not None and st["state"] == "HALF_OPEN";

    before = time.time();
    breaker_record_failure(mod, probe);
    after = time.time();

    st = _breaker_peek(mod);
    assert st is not None and st["state"] == "OPEN";
    assert before <= st["opened_at"] <= after;

    assert breaker_should_skip(mod);

    _breaker_reset(mod);
}

test "walker_call records one breaker failure per failed round trip" {
    import from jaclang.scale.runtime.rpc.rpc { _RPC_MAX_ATTEMPTS }

    mod = "breaker_walker_per_attempt_test";
    _breaker_reset(mod);
    round_trips: dict = {"n": 0};
    original_request = _install_unreachable_walker_transport(round_trips);

    try {
        sv_client.register(mod, "http://demo.invalid");
        try {
            JacScalePlugin.sv_walker_call(mod, "Ping", {}, None);
        } except RuntimeError {
            ;
        }

        st = _breaker_peek(mod);
        assert st is not None;
        assert round_trips["n"] == _RPC_MAX_ATTEMPTS;
        assert st["fails"] == round_trips["n"];
    } finally {
        sv_http.request_sync = original_request;
        sv_client.unregister(mod);
        _breaker_reset(mod);
    }
}

test "breaker opens after exactly the trip threshold of failed round trips" {
    mod = "breaker_trip_roundtrips_test";
    _breaker_reset(mod);
    round_trips: dict = {"n": 0};
    original_post = _install_unreachable_transport(round_trips);

    try {
        sv_client.register(mod, "http://demo.invalid");
        calls = 0;
        while not breaker_should_skip(mod) and calls < _BREAKER_TRIP_THRESHOLD {
            calls += 1;
            try {
                JacScalePlugin.sv_service_call(mod, "ping", {});
            } except RuntimeError {
                ;
            }
        }

        assert round_trips["n"] == _BREAKER_TRIP_THRESHOLD , (
            f"breaker opened after {round_trips['n']} round trips, "
            + f"expected {_BREAKER_TRIP_THRESHOLD}"
        );
    } finally {
        sv_http.post_stream_aware_sync = original_post;
        sv_client.unregister(mod);
        _breaker_reset(mod);
    }
}

test "a breaker that trips mid-call abandons the remaining retries" {
    mod = "breaker_probe_single_test";
    _trip_breaker(mod);
    _breaker_force_cooldown_elapsed(mod);

    round_trips: dict = {"n": 0};
    original_post = _install_unreachable_transport(round_trips);

    try {
        sv_client.register(mod, "http://demo.invalid");
        raised_msg = "";
        try {
            JacScalePlugin.sv_service_call(mod, "ping", {});
        } except RuntimeError as e {
            raised_msg = str(e);
        }

        assert round_trips["n"] == 1 , (
            f"HALF_OPEN probe spent {round_trips['n']} round trips, expected 1"
        );
        assert "1 attempts (stopped by open circuit breaker)" in raised_msg , (
            f"short attempt count needs a reason, got: {raised_msg}"
        );
        st = _breaker_peek(mod);
        assert st is not None and st["state"] == "OPEN";
    } finally {
        sv_http.post_stream_aware_sync = original_post;
        sv_client.unregister(mod);
        _breaker_reset(mod);
    }
}

test "a caller admitted before the trip stops instead of retrying into recovery" {
    import from jaclang.runtimelib.serving.client { ClientRequestNotSent }

    mod = "breaker_straggler_retry_test";
    _breaker_reset(mod);

    round_trips: dict = {"n": 0};
    original_post = sv_http.post_stream_aware_sync;

    def fake(*args: any, **kwargs: any) -> tuple[str, any] {
        round_trips["n"] = round_trips["n"] + 1;
        if round_trips["n"] == 1 {
            _trip_breaker(mod);
            _breaker_force_cooldown_elapsed(mod);
        }
        raise ClientRequestNotSent(detail="connection refused");
    }
    sv_http.post_stream_aware_sync = fake;

    try {
        sv_client.register(mod, "http://demo.invalid");
        raised_msg = "";
        try {
            JacScalePlugin.sv_service_call(mod, "ping", {});
        } except RuntimeError as e {
            raised_msg = str(e);
        }

        assert round_trips["n"] == 1 , (
            f"a caller holding no lease spent {round_trips['n']} round trips, "
            + "expected 1: its retries race the recovery probe and its verdicts "
            + "no longer count"
        );
        assert "1 attempts (stopped by open circuit breaker)" in raised_msg , (
            f"short attempt count needs a reason, got: {raised_msg}"
        );
    } finally {
        sv_http.post_stream_aware_sync = original_post;
        sv_client.unregister(mod);
        _breaker_reset(mod);
    }
}

test "admission survives only in CLOSED or while holding the live probe" {
    mod = "breaker_admission_states_test";
    _breaker_reset(mod);

    assert breaker_still_admitted(mod, 0) , "an unknown provider sheds nobody";

    _trip_breaker(mod);
    assert not breaker_still_admitted(mod, 0);

    _breaker_force_cooldown_elapsed(mod);
    assert not breaker_still_admitted(mod, 0) , (
        "the cooldown elapsing hands the next arrival a probe, so a caller from "
        + "the previous generation must not retry alongside it"
    );

    probe = _take_probe(mod);
    assert breaker_still_admitted(mod, probe);
    assert not breaker_still_admitted(mod, 0);

    _breaker_force_probe_expired(mod);
    assert breaker_still_admitted(mod, probe) , (
        "an expired lease stays the probe of record until it is reclaimed, so "
        + "its holder keeps the admission its verdicts still carry"
    );
    assert not breaker_still_admitted(mod, 0);

    breaker_record_success(mod, probe);
    assert breaker_still_admitted(mod, 0);
    assert breaker_still_admitted(mod, probe) , (
        "a CLOSED breaker sheds nobody, including a retired probe holder"
    );

    _breaker_reset(mod);
}

test "only one caller is admitted while a HALF_OPEN probe is in flight" {
    mod = "breaker_single_probe_admit_test";
    _trip_breaker(mod);
    probe = _take_probe(mod);

    (admitted, second_probe) = breaker_admit(mod, _PROBE_TTL);
    assert not admitted , "a second caller was admitted into a live probe";
    assert second_probe == 0;
    assert breaker_should_skip(mod);

    st = _breaker_peek(mod);
    assert st is not None and st["probe"] == probe;

    _breaker_reset(mod);
}

test "concurrent callers do not pile onto a HALF_OPEN probe" {
    import threading;
    import from jaclang.runtimelib.serving.client { ClientConnectionError }

    mod = "breaker_probe_concurrency_test";
    _trip_breaker(mod);
    _breaker_force_cooldown_elapsed(mod);

    round_trips: dict = {"n": 0};
    probe_started = threading.Event();
    probe_may_finish = threading.Event();
    errors: list[str] = [];
    errors_lock = threading.Lock();
    original_post = sv_http.post_stream_aware_sync;

    def fake(*args: any, **kwargs: any) -> tuple[str, any] {
        with errors_lock {
            round_trips["n"] = round_trips["n"] + 1;
        }
        probe_started.set();
        probe_may_finish.`wait(5.0);
        raise ClientConnectionError(detail="connection refused");
    }
    sv_http.post_stream_aware_sync = fake;

    def call {
        try {
            JacScalePlugin.sv_service_call(mod, "ping", {});
        } except RuntimeError as e {
            with errors_lock {
                errors.append(str(e));
            }
        }
    }

    try {
        sv_client.register(mod, "http://demo.invalid");
        prober = threading.Thread(target=call);
        prober.start();
        assert probe_started.`wait(5.0) , "probe never reached the transport";

        others = [threading.Thread(target=call) for _ in range(8)];
        for t in others {
            t.start();
        }
        for t in others {
            t.join(5.0);
        }

        assert round_trips["n"] == 1 , (
            f"{round_trips['n']} concurrent probes reached the transport, expected 1"
        );
        with errors_lock {
            blocked = [
                m
                for m in errors
                if "blocked by open circuit breaker" in m
            ];
        }
        assert len(blocked) == len(others) , (
            f"only {len(blocked)} of {len(others)} callers were shed"
        );
    } finally {
        probe_may_finish.set();
        prober.join(5.0);
        sv_http.post_stream_aware_sync = original_post;
        sv_client.unregister(mod);
        _breaker_reset(mod);
    }
}

test "a probe that dies without a verdict does not wedge the breaker shut" {
    import time;
    mod = "breaker_probe_abandoned_test";
    _trip_breaker(mod);
    _breaker_force_cooldown_elapsed(mod);

    abandoned_at = time.time();
    original_post = sv_http.post_stream_aware_sync;

    def fake(*args: any, **kwargs: any) -> tuple[str, any] {
        raise ValueError("transport blew up");
    }
    sv_http.post_stream_aware_sync = fake;

    try {
        sv_client.register(mod, "http://demo.invalid");
        try {
            JacScalePlugin.sv_service_call(mod, "ping", {});
        } except ValueError {
            ;
        }

        st = _breaker_peek(mod);
        assert st is not None and st["state"] == "OPEN" , (
            f"abandoned probe left the breaker in {st}"
        );
        assert st["opened_at"] >= abandoned_at , (
            "an unclassified failure must restart the cooldown, so a peer that "
            + "keeps abandoning probes is retried once per cooldown, not freely"
        );

        _breaker_force_cooldown_elapsed(mod);
        (admitted, probe) = breaker_admit(mod, _PROBE_TTL);
        assert admitted and probe != 0;
    } finally {
        sv_http.post_stream_aware_sync = original_post;
        sv_client.unregister(mod);
        _breaker_reset(mod);
    }
}

test "a probe that never reports back is reclaimed after the probe timeout" {
    mod = "breaker_probe_stale_test";
    _trip_breaker(mod);
    stale_probe = _take_probe(mod);

    (admitted, blocked_probe) = breaker_admit(mod, _PROBE_TTL);
    assert not admitted and blocked_probe == 0;

    _breaker_force_probe_expired(mod);
    (reclaimed, fresh_probe) = breaker_admit(mod, _PROBE_TTL);
    assert reclaimed , "a stuck probe pinned the breaker in HALF_OPEN";
    assert fresh_probe != stale_probe;

    breaker_record_failure(mod, stale_probe);
    st = _breaker_peek(mod);
    assert st is not None and st["state"] == "HALF_OPEN" , (
        "a stale probe verdict clobbered the live probe"
    );

    _breaker_reset(mod);
}

test "a probe lease is reclaimed at the deadline its caller set" {
    mod = "breaker_probe_lease_ttl_test";
    _trip_breaker(mod);
    _breaker_force_cooldown_elapsed(mod);

    (admitted, spent_probe) = breaker_admit(mod, 0.0);
    assert admitted and spent_probe != 0;

    (reclaimed, fresh_probe) = breaker_admit(mod, _PROBE_TTL);
    assert reclaimed , "a lease past its deadline pinned the breaker in HALF_OPEN";
    assert fresh_probe != spent_probe;

    (blocked, no_probe) = breaker_admit(mod, _PROBE_TTL);
    assert not blocked and no_probe == 0;

    _breaker_reset(mod);
}

test "a probe lease outlasts the rpc_timeout of the call holding it" {
    import time;
    import from jaclang.runtimelib.serving.client { ClientConnectionError }

    mod = "breaker_slow_probe_test";
    slow_timeout: float = 120.0;
    _trip_breaker(mod);
    _breaker_force_cooldown_elapsed(mod);

    in_flight: dict = {};
    original_post = sv_http.post_stream_aware_sync;

    def fake(*args: any, **kwargs: any) -> tuple[str, any] {
        in_flight["state"] = _breaker_peek(mod);
        in_flight["at"] = time.time();
        in_flight["timeout"] = kwargs.get("timeout");
        raise ClientConnectionError(detail="connection refused");
    }
    sv_http.post_stream_aware_sync = fake;

    original_cfg = _install_ms_config(
        {"services": {mod: {"rpc_timeout": slow_timeout}}}
    );

    try {
        sv_client.register(mod, "http://demo.invalid");
        try {
            JacScalePlugin.sv_service_call(mod, "ping", {});
        } except RuntimeError {
            ;
        }

        st = in_flight.get("state");
        assert st is not None and st["state"] == "HALF_OPEN" , (
            "the probe never reached the transport"
        );
        assert in_flight["timeout"] == slow_timeout , (
            f"the call ran under {in_flight['timeout']}s, not the configured "
            + f"{slow_timeout}s"
        );
        assert st["probe_expires_at"] - in_flight["at"] > slow_timeout , (
            "the probe lease expires while the call holding it can still be running"
        );
    } finally {
        _restore_ms_config(original_cfg);
        sv_http.post_stream_aware_sync = original_post;
        sv_client.unregister(mod);
        _breaker_reset(mod);
    }
}

test "a stale probe success does not close the breaker around a live probe" {
    mod = "breaker_stale_success_test";
    _trip_breaker(mod);
    stale_probe = _take_probe(mod);

    _breaker_force_probe_expired(mod);
    (reclaimed, fresh_probe) = breaker_admit(mod, _PROBE_TTL);
    assert reclaimed and fresh_probe != stale_probe;

    breaker_record_success(mod, stale_probe);
    st = _breaker_peek(mod);
    assert st is not None and st["state"] == "HALF_OPEN" , (
        "a stale probe success reopened the breaker to every caller"
    );
    assert st["probe"] == fresh_probe;

    (admitted, blocked_probe) = breaker_admit(mod, _PROBE_TTL);
    assert not admitted and blocked_probe == 0;

    _breaker_reset(mod);
}

"""Retire a probe by expiring it and letting its replacement succeed."""
def _strand_probe(mod: str) -> int {
    stale_probe = _take_probe(mod);
    _breaker_force_probe_expired(mod);
    (reclaimed, fresh_probe) = breaker_admit(mod, _PROBE_TTL);
    assert reclaimed and fresh_probe != stale_probe;
    breaker_record_success(mod, fresh_probe);
    return stale_probe;
}

test "a stale probe failure does not count toward the trip threshold" {
    mod = "breaker_stale_failure_test";
    _trip_breaker(mod);
    stale_probe = _strand_probe(mod);

    st = _breaker_peek(mod);
    assert st is not None and st["state"] == "CLOSED" and st["fails"] == 0;

    breaker_record_failure(mod, stale_probe);
    st = _breaker_peek(mod);
    assert st is not None and st["fails"] == 0 , (
        "a stale probe failure was counted as a current failure"
    );

    _breaker_reset(mod);
}

test "a stale probe success does not erase current failures" {
    mod = "breaker_stale_success_clear_test";
    _trip_breaker(mod);
    stale_probe = _strand_probe(mod);

    for _ in range(_BREAKER_TRIP_THRESHOLD - 1) {
        breaker_record_failure(mod);
    }
    st = _breaker_peek(mod);
    assert st is not None and st["fails"] == _BREAKER_TRIP_THRESHOLD - 1;

    breaker_record_success(mod, stale_probe);
    st = _breaker_peek(mod);
    assert st is not None and st["fails"] == _BREAKER_TRIP_THRESHOLD - 1 , (
        "a stale probe success erased current failures"
    );

    _breaker_reset(mod);
}

test "a success from before the breaker opened does not cancel the cooldown" {
    mod = "breaker_straggler_success_test";
    _breaker_reset(mod);
    _trip_breaker(mod);

    breaker_record_success(mod);
    st = _breaker_peek(mod);
    assert st is not None and st["state"] == "OPEN" , (
        "a straggler success cancelled the cooldown"
    );
    assert breaker_should_skip(mod);

    _breaker_reset(mod);
}

test "application error envelope does NOT trip the breaker" {
    mod = "breaker_app_err_test";
    _breaker_reset(mod);

    def handler(request: _MockRequest) -> _MockResponse {
        return _MockResponse(
            json_payload={"ok": False, "error": {"code": "X", "message": "nope"}}
        );
    }

    original_post = _install_mock(handler);

    try {
        sv_client.register(mod, "http://demo.invalid");
        for _ in range(_BREAKER_TRIP_THRESHOLD) {
            try {
                JacScalePlugin.sv_service_call(mod, "fail", {});
            } except RuntimeError {
                ;
            }
        }

        assert not breaker_should_skip(mod);
    } finally {
        sv_http.post_stream_aware_sync = original_post;
        sv_client.unregister(mod);
        _breaker_reset(mod);
    }
}

test "sv_service_call does NOT retry on application error envelope" {
    call_count: dict = {"n": 0};

    def handler(request: _MockRequest) -> _MockResponse {
        call_count["n"] = call_count["n"] + 1;
        return _MockResponse(
            json_payload={
                "ok": False,
                "error": {"code": "X", "message": "deterministic_fail"}
            }
        );
    }

    original_post = _install_mock(handler);

    try {
        sv_client.register("app_err_mod", "http://demo.invalid");
        raised_msg = "";
        try {
            JacScalePlugin.sv_service_call("app_err_mod", "fail", {});
        } except RuntimeError as e {
            raised_msg = str(e);
        }

        assert call_count["n"] == 1;
        assert "deterministic_fail" in raised_msg;
    } finally {
        sv_http.post_stream_aware_sync = original_post;
        sv_client.unregister("app_err_mod");
    }
}


test "sv_service_call uses the default 10s timeout when no per-service override" {
    captured: dict = {};

    def handler(request: _MockRequest) -> _MockResponse {
        captured["timeout"] = request.timeout;
        return _MockResponse(json_payload={"ok": True, "data": {"result": "done"}});
    }

    original_post = _install_mock(handler);

    try {
        sv_client.register("default_to_mod", "http://demo.invalid");
        JacScalePlugin.sv_service_call("default_to_mod", "run", {});
        assert captured["timeout"] == 10.0;
    } finally {
        sv_http.post_stream_aware_sync = original_post;
        sv_client.unregister("default_to_mod");
    }
}


test "sv_service_call honors per-service rpc_timeout from config" {
    captured: dict = {};

    def handler(request: _MockRequest) -> _MockResponse {
        captured["timeout"] = request.timeout;
        return _MockResponse(json_payload={"ok": True, "data": {"result": "done"}});
    }

    original_post = _install_mock(handler);
    original_resolver = _install_rpc_timeout("slow_mod", 75.5);

    try {
        sv_client.register("slow_mod", "http://demo.invalid");
        JacScalePlugin.sv_service_call("slow_mod", "run", {});
        assert captured["timeout"] == 75.5;
    } finally {
        _restore_rpc_timeout(original_resolver);
        sv_http.post_stream_aware_sync = original_post;
        sv_client.unregister("slow_mod");
    }
}


test "_sv_rpc_timeout returns default when config lookup fails" {
    import from jaclang.scale.runtime.rpc.rpc { _sv_rpc_timeout }
    t: float = _sv_rpc_timeout("module_that_has_no_override");
    assert t == 10.0;
}


test "sv_service_call uses URL from get_sv_registry hookspec when present" {
    import jaclang;

    captured: dict = {};
    def handler(request: _MockRequest) -> _MockResponse {
        captured["url"] = str(request.url);
        return _MockResponse(
            json_payload={"ok": True, "data": {"result": "via-hookspec"}}
        );
    }

    original_post = _install_mock(handler);
    original_get_registry = jaclang.JacRuntime.get_sv_registry;

    def fake_registry -> dict[str, str] {
        return {
            "k9_test_mod": "http://k9-test-mod-service.prod.svc.cluster.local:8000"
        };
    }
    jaclang.JacRuntime.get_sv_registry = staticmethod(fake_registry);

    try {
        if "k9_test_mod" in sv_client._registry {
            sv_client.unregister("k9_test_mod");
        }

        result = JacScalePlugin.sv_service_call("k9_test_mod", "do", {});
        assert result == "via-hookspec";

        assert "k9-test-mod-service.prod.svc.cluster.local" in captured["url"];
    } finally {
        jaclang.JacRuntime.get_sv_registry = original_get_registry;
        sv_http.post_stream_aware_sync = original_post;
    }
}


test "sv_service_call falls back to sv_client.resolve_url when hookspec empty" {
    import jaclang;

    captured: dict = {};
    def handler(request: _MockRequest) -> _MockResponse {
        captured["url"] = str(request.url);
        return _MockResponse(
            json_payload={"ok": True, "data": {"result": "via-fallback"}}
        );
    }

    original_post = _install_mock(handler);
    original_get_registry = jaclang.JacRuntime.get_sv_registry;

    jaclang.JacRuntime.get_sv_registry = staticmethod(lambda { {}; });

    try {
        sv_client.register("k9_fallback_mod", "http://fallback.invalid:9999");
        result = JacScalePlugin.sv_service_call("k9_fallback_mod", "do", {});
        assert result == "via-fallback";
        assert "fallback.invalid:9999" in captured["url"];
    } finally {
        jaclang.JacRuntime.get_sv_registry = original_get_registry;
        sv_http.post_stream_aware_sync = original_post;
        sv_client.unregister("k9_fallback_mod");
    }
}


test "ensure_sv_service registers DNS URL when in K8s mode" {
    import os;
    import from jaclang.scale.plugin { JacScalePlugin }

    orig_k8s_host = os.environ.get("KUBERNETES_SERVICE_HOST");
    orig_ns = os.environ.get("POD_NAMESPACE");

    os.environ["KUBERNETES_SERVICE_HOST"] = "10.0.0.1";
    os.environ["POD_NAMESPACE"] = "prod";
    original_cfg = _install_ms_config(
        {"routes": {"k9_2_peer": "/api/peer"}, "gateway_port": 8000}
    );

    if "k9_2_peer" in sv_client._registry {
        sv_client.unregister("k9_2_peer");
    }

    try {
        JacScalePlugin.ensure_sv_service("k9_2_peer", ".");
        url = sv_client._registry.get("k9_2_peer", "");
        assert url == "http://k9-2-peer-service.prod.svc.cluster.local:8000" , (
            f"expected DNS URL, got '{url}'"
        );
    } finally {
        if "k9_2_peer" in sv_client._registry {
            sv_client.unregister("k9_2_peer");
        }
        if orig_k8s_host is None {
            del os.environ["KUBERNETES_SERVICE_HOST"];
        } else {
            os.environ["KUBERNETES_SERVICE_HOST"] = orig_k8s_host;
        }
        if orig_ns is None {
            del os.environ["POD_NAMESPACE"];
        } else {
            os.environ["POD_NAMESPACE"] = orig_ns;
        }
        _restore_ms_config(original_cfg);
    }
}


test "ensure_sv_service early-returns when peer already registered" {
    import os;
    import from jaclang.scale.plugin { JacScalePlugin }

    orig_k8s_host = os.environ.get("KUBERNETES_SERVICE_HOST");
    os.environ["KUBERNETES_SERVICE_HOST"] = "10.0.0.1";

    sv_client.register("k9_2_already_registered", "http://prior-url.example.com:8000");

    try {
        JacScalePlugin.ensure_sv_service("k9_2_already_registered", ".");
        assert sv_client._registry["k9_2_already_registered"]
            == ("http://prior-url.example.com:8000");
    } finally {
        sv_client.unregister("k9_2_already_registered");
        if orig_k8s_host is None {
            del os.environ["KUBERNETES_SERVICE_HOST"];
        } else {
            os.environ["KUBERNETES_SERVICE_HOST"] = orig_k8s_host;
        }
    }
}

import socket;
import threading;


"""Count round trips and delivered POSTs apart; an abandoned connect is not a delivery."""
def _start_counting_server(counts: dict, reply: (bytes | None)) -> tuple {
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM);
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1);
    srv.bind(("127.0.0.1", 0));
    srv.listen(8);
    port = srv.getsockname()[1];
    held: list = [];

    def serve {
        while True {
            try {
                (conn, _addr) = srv.accept();
            } except OSError {
                return;
            }
            counts["conns"] = counts["conns"] + 1;
            held.append(conn);
            try {
                data = conn.recv(65536);
            } except OSError {
                continue;
            }
            if not data.startswith(b"POST ") {
                continue;
            }
            counts["posts"] = counts["posts"] + 1;
            if reply is not None {
                try {
                    conn.sendall(reply);
                    conn.close();
                } except OSError {
                    ;
                }
            }
        }
    }
    t = threading.Thread(target=serve, daemon=True);
    t.start();
    return (srv, held, port);
}


def _stop_counting_server(srv: any, held: list) {
    try {
        srv.close();
    } except OSError {
        ;
    }
    for conn in held {
        try {
            conn.close();
        } except OSError {
            ;
        }
    }
}


test "walker_call sends exactly one POST to a peer that never replies" {
    counts: dict = {"conns": 0, "posts": 0};
    (srv, held, port) = _start_counting_server(counts, None);
    mod = "deaf_walker_mod";
    _breaker_reset(mod);
    original_timeout = _install_rpc_timeout(mod, 1.5);
    try {
        sv_client.register(mod, f"http://127.0.0.1:{port}");
        raised_msg = "";
        try {
            JacScalePlugin.sv_walker_call(mod, "Ping", {}, None);
        } except RuntimeError as e {
            raised_msg = str(e);
        }
        assert "no response head within" in raised_msg , raised_msg;
        assert counts["posts"] == 1 , raised_msg;
        assert f"after {counts['conns']} attempts" in raised_msg , raised_msg;
    } finally {
        _restore_rpc_timeout(original_timeout);
        sv_client.unregister(mod);
        _stop_counting_server(srv, held);
        _breaker_reset(mod);
    }
}


test "service_call sends exactly one POST to a peer that never replies" {
    counts: dict = {"conns": 0, "posts": 0};
    (srv, held, port) = _start_counting_server(counts, None);
    mod = "deaf_service_mod";
    _breaker_reset(mod);
    original_timeout = _install_rpc_timeout(mod, 1.5);
    try {
        sv_client.register(mod, f"http://127.0.0.1:{port}");
        raised_msg = "";
        try {
            JacScalePlugin.sv_service_call(mod, "ping", {});
        } except RuntimeError as e {
            raised_msg = str(e);
        }
        assert "no response head within" in raised_msg , raised_msg;
        assert counts["posts"] == 1 , raised_msg;
        assert f"after {counts['conns']} attempts" in raised_msg , raised_msg;
    } finally {
        _restore_rpc_timeout(original_timeout);
        sv_client.unregister(mod);
        _stop_counting_server(srv, held);
        _breaker_reset(mod);
    }
}


test "service_call does not retry an HTTP 500" {
    counts: dict = {"conns": 0, "posts": 0};
    reply = (
        b"HTTP/1.1 500 Internal Server Error\r\n"
        + b"Content-Type: text/plain\r\n"
        + b"Content-Length: 4\r\n"
        + b"Connection: close\r\n\r\nboom"
    );
    (srv, held, port) = _start_counting_server(counts, reply);
    mod = "http500_service_mod";
    _breaker_reset(mod);
    original_timeout = _install_rpc_timeout(mod, 1.5);
    try {
        sv_client.register(mod, f"http://127.0.0.1:{port}");
        raised_msg = "";
        try {
            JacScalePlugin.sv_service_call(mod, "boom", {});
        } except RuntimeError as e {
            raised_msg = str(e);
        }
        assert "HTTP 500" in raised_msg , raised_msg;
        assert counts["posts"] == 1 , raised_msg;
        assert f"after {counts['conns']} attempts" in raised_msg , raised_msg;
    } finally {
        _restore_rpc_timeout(original_timeout);
        sv_client.unregister(mod);
        _stop_counting_server(srv, held);
        _breaker_reset(mod);
    }
}
