import jaclang.runtimelib.serving.client as sv_http;
import from jaclang.runtimelib { sv_client }
import from jaclang.scale.runtime.context.auth_ctx {
    set_current_auth,
    reset_current_auth,
    get_current_auth
}
import from jaclang.scale.plugin { JacScalePlugin }
import from jaclang.scale.tests._sv_test_support {
    _MockRequest,
    _MockResponse,
    _install_mock,
    _install_rpc_timeout,
    _restore_rpc_timeout
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
        lambda { _K8sStubMsCfg(
            data={"routes": {"k9_2_peer": "/api/peer"}, "gateway_port": 8000}
        ); }
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
