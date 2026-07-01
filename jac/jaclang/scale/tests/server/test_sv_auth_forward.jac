import httpx;
import from jaclang.runtimelib { sv_client }
import from jaclang.scale.runtime.context.auth_ctx {
    set_current_auth,
    reset_current_auth,
    get_current_auth
}
import from jaclang.scale.plugin { JacScalePlugin }


def _mock_client_class(handler: any, on_init: any = None) -> any {
    transport = httpx.MockTransport(handler);
    real_client_cls = httpx.Client;
    def factory(*args: any, **kwargs: any) -> any {
        if on_init {
            on_init(kwargs);
        }
        return real_client_cls(transport=transport);
    }
    return factory;
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

    def handler(request: httpx.Request) -> httpx.Response {
        captured["auth"] = request.headers.get("Authorization", "");
        return httpx.Response(
            status_code=200, json={"ok": True, "data": {"result": "echoed"}}
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
            status_code=200, json={"ok": True, "data": {"result": "ok"}}
        );
    }

    original_client = httpx.Client;
    httpx.Client = _mock_client_class(handler);

    try {
        sv_client.register("demo_mod2", "http://demo.invalid");

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

test "sv_service_call retries on transport error and succeeds on 2nd attempt" {
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
        assert call_count["n"] == 2;
    } finally {
        httpx.Client = original_client;
        sv_client.unregister("retry_mod");
    }
}

test "sv_service_call gives up after max_attempts on persistent transport error" {
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

        JacScalePlugin.sv_service_call("trace_mod2", "ping", {});
        assert captured["trace"] == "";
    } finally {
        httpx.Client = original_client;
        sv_client.unregister("trace_mod2");
    }
}

import from jaclang.scale.runtime.rpc.breaker {
    _breaker_reset,
    breaker_record_success,
    breaker_record_failure,
    breaker_should_skip,
    _BREAKER_TRIP_THRESHOLD
}

test "breaker trips OPEN after N consecutive transport failures and fails fast" {
    mod = "breaker_open_test";
    _breaker_reset(mod);

    for _ in range(_BREAKER_TRIP_THRESHOLD) {
        breaker_record_failure(mod);
    }

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
    import from jaclang.scale.runtime.rpc.breaker {
        _breaker_peek,
        _breaker_force_cooldown_elapsed
    }

    mod = "breaker_half_open_test";
    _breaker_reset(mod);

    for _ in range(_BREAKER_TRIP_THRESHOLD) {
        breaker_record_failure(mod);
    }
    assert breaker_should_skip(mod);

    _breaker_force_cooldown_elapsed(mod);
    assert not breaker_should_skip(mod);
    st = _breaker_peek(mod);
    assert st is not None and st["state"] == "HALF_OPEN";

    breaker_record_success(mod);
    st = _breaker_peek(mod);
    assert st is not None and st["state"] == "CLOSED";
    assert st["fails"] == 0;

    _breaker_reset(mod);
}

test "application error envelope does NOT trip the breaker" {
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

        assert not breaker_should_skip(mod);
    } finally {
        httpx.Client = original_client;
        sv_client.unregister(mod);
        _breaker_reset(mod);
    }
}

test "sv_service_call does NOT retry on application error envelope" {
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
            status_code=200, json={"ok": True, "data": {"result": "done"}}
        );
    }

    def on_init(kwargs: dict) {
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
    import jaclang.scale.runtime.rpc.rpc as plugin_mod;
    captured: dict = {};

    def handler(request: httpx.Request) -> httpx.Response {
        return httpx.Response(
            status_code=200, json={"ok": True, "data": {"result": "done"}}
        );
    }

    def on_init(kwargs: dict) {
        captured["timeout"] = kwargs.get("timeout");
    }

    original_client = httpx.Client;
    httpx.Client = _mock_client_class(handler, on_init=on_init);

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
    import from jaclang.scale.runtime.rpc.rpc { _sv_rpc_timeout }
    t: float = _sv_rpc_timeout("module_that_has_no_override");
    assert t == 10.0;
}


test "sv_service_call uses URL from get_sv_registry hookspec when present" {
    import jaclang;

    captured: dict = {};
    def handler(request: httpx.Request) -> httpx.Response {
        captured["url"] = str(request.url);
        return httpx.Response(
            status_code=200, json={"ok": True, "data": {"result": "via-hookspec"}}
        );
    }

    original_client = httpx.Client;
    original_get_registry = jaclang.JacRuntime.get_sv_registry;
    httpx.Client = _mock_client_class(handler);

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
        httpx.Client = original_client;
    }
}


test "sv_service_call falls back to sv_client.resolve_url when hookspec empty" {
    import jaclang;

    captured: dict = {};
    def handler(request: httpx.Request) -> httpx.Response {
        captured["url"] = str(request.url);
        return httpx.Response(
            status_code=200, json={"ok": True, "data": {"result": "via-fallback"}}
        );
    }

    original_client = httpx.Client;
    original_get_registry = jaclang.JacRuntime.get_sv_registry;
    httpx.Client = _mock_client_class(handler);

    jaclang.JacRuntime.get_sv_registry = staticmethod(lambda : {});

    try {
        sv_client.register("k9_fallback_mod", "http://fallback.invalid:9999");
        result = JacScalePlugin.sv_service_call("k9_fallback_mod", "do", {});
        assert result == "via-fallback";
        assert "fallback.invalid:9999" in captured["url"];
    } finally {
        jaclang.JacRuntime.get_sv_registry = original_get_registry;
        httpx.Client = original_client;
        sv_client.unregister("k9_fallback_mod");
    }
}


obj _K8sStubMsCfg {
    has data: dict[str, any];

    def get_microservices_config -> dict[str, any] {
        return self.data;
    }
}

test "ensure_sv_service registers DNS URL when in K8s mode" {
    import os;
    import jaclang.scale.config.config_loader as cfg_mod;
    import from jaclang.scale.plugin { JacScalePlugin }

    orig_k8s_host = os.environ.get("KUBERNETES_SERVICE_HOST");
    orig_ns = os.environ.get("POD_NAMESPACE");
    original_cfg = getattr(cfg_mod, "get_scale_config");

    os.environ["KUBERNETES_SERVICE_HOST"] = "10.0.0.1";
    os.environ["POD_NAMESPACE"] = "prod";
    setattr(
        cfg_mod,
        "get_scale_config",
        lambda :
            _K8sStubMsCfg(
                data={"routes": {"k9_2_peer": "/api/peer"}, "gateway_port": 8000}
            )
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
        setattr(cfg_mod, "get_scale_config", original_cfg);
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
        assert sv_client._registry["k9_2_already_registered"] == (
            "http://prior-url.example.com:8000"
        );
    } finally {
        sv_client.unregister("k9_2_already_registered");
        if orig_k8s_host is None {
            del os.environ["KUBERNETES_SERVICE_HOST"];
        } else {
            os.environ["KUBERNETES_SERVICE_HOST"] = orig_k8s_host;
        }
    }
}
