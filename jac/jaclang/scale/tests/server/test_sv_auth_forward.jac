import jaclang.server.serving.client as sv_http;
import from jaclang.server { sv_client }
import from jaclang.scale.runtime.context.auth_ctx {
    set_current_auth,
    reset_current_auth,
    get_current_auth
}
import from jaclang.scale.plugin { JacScalePlugin }
import from jaclang.scale.runtime.rpc.breaker { _breaker_reset }
import from jaclang.scale.tests._sv_test_support {
    _MockRequest,
    _MockResponse,
    _install_mock,
    _install_rpc_timeout,
    _restore_rpc_timeout
}


def _as_any(v: any) -> any {
    return v;
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
    _as_any(jaclang.JacRuntime).get_sv_registry = staticmethod(fake_registry);

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

    _as_any(jaclang.JacRuntime).get_sv_registry = staticmethod(lambda { {}; });

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
                } except OSError {}
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
    } except OSError {}
    for conn in held {
        try {
            conn.close();
        } except OSError {}
    }
}


"""Record the request line's path of every POST and answer it with `reply`."""
def _start_capturing_server(paths: list[str], reply: bytes) -> tuple {
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
            held.append(conn);
            try {
                data = conn.recv(65536);
            } except OSError {
                continue;
            }
            if not data.startswith(b"POST ") {
                continue;
            }
            paths.append(data.split(b" ")[1].decode("ascii"));
            try {
                conn.sendall(reply);
                conn.close();
            } except OSError {}
        }
    }
    t = threading.Thread(target=serve, daemon=True);
    t.start();
    return (srv, held, port);
}


glob _WALKER_OK_BODY: bytes = b'{"ok": true, "data": {"result": {}, "reports": []}}',
     _WALKER_OK_REPLY: bytes = (
         b"HTTP/1.1 200 OK\r\n"
         + b"Content-Type: application/json\r\n"
         + b"Content-Length: "
         + str(len(_WALKER_OK_BODY)).encode("ascii")
         + b"\r\n"
         + b"Connection: close\r\n\r\n"
         + _WALKER_OK_BODY
     );


def _reset_peer(mod: str) {
    sv_client.unregister(mod);
    sv_client._consumer_providers.pop("route_consumer", None);
    sv_client.set_consumer_app("");
    _breaker_reset(mod);
}


test "a compiled consumer's declared route is not appended to a bare peer URL" {
    paths: list[str] = [];
    (srv, held, port) = _start_capturing_server(paths, _WALKER_OK_REPLY);
    mod = "declared_route_peer";
    _reset_peer(mod);
    try {
        sv_client._declare_consumer_provider("route_consumer", mod, "/api/peer");
        sv_client.register(mod, f"http://127.0.0.1:{port}");
        assert sv_client.provider_route(mod) == "/api/peer";
        assert sv_client.registered_route(mod) == "";
        assert sv_client.resolve_url(mod) == f"http://127.0.0.1:{port}";

        JacScalePlugin.sv_walker_call(mod, "Ping", {}, None);
        assert paths == ["/walker/Ping"] , paths;
    } finally {
        _reset_peer(mod);
        _stop_counting_server(srv, held);
    }
}


test "a route registered together with a URL is appended (gateway base)" {
    paths: list[str] = [];
    (srv, held, port) = _start_capturing_server(paths, _WALKER_OK_REPLY);
    mod = "gateway_route_peer";
    _reset_peer(mod);
    try {
        sv_client._declare_consumer_provider("route_consumer", mod, "/api/peer");
        sv_client.register(mod, f"http://127.0.0.1:{port}/", "/api/peer");
        assert sv_client.registered_route(mod) == "/api/peer";
        assert sv_client.resolve_url(mod) == f"http://127.0.0.1:{port}/api/peer";

        JacScalePlugin.sv_walker_call(mod, "Ping", {}, None);
        assert paths == ["/api/peer/walker/Ping"] , paths;

        sv_client.register(mod, f"http://127.0.0.1:{port}");
        assert sv_client.registered_route(mod) == "";
        JacScalePlugin.sv_walker_call(mod, "Ping", {}, None);
        assert paths == ["/api/peer/walker/Ping", "/walker/Ping"] , paths;
    } finally {
        _reset_peer(mod);
        _stop_counting_server(srv, held);
    }
}


test "JAC_APP_<APP>_URL is used as given unless JAC_APP_<APP>_ROUTE is set too" {
    import os;
    mod = "env_route_peer";
    url_key = sv_client.peer_url_env_key(mod);
    route_key = sv_client.peer_route_env_key(mod);
    saved_url = os.environ.get(url_key);
    saved_route = os.environ.get(route_key);
    _reset_peer(mod);
    try {
        sv_client._declare_consumer_provider("route_consumer", mod, "/api/peer");
        os.environ[url_key] = "http://member.invalid:9001";
        os.environ.pop(route_key, None);
        assert sv_client.resolve_url(mod) == "http://member.invalid:9001";

        sv_client.unregister(mod);
        os.environ[route_key] = "/api/peer";
        assert sv_client.resolve_url(mod) == "http://member.invalid:9001/api/peer";
    } finally {
        _reset_peer(mod);
        for (k, v) in [(url_key, saved_url), (route_key, saved_route)] {
            if v is None {
                os.environ.pop(k, None);
            } else {
                os.environ[k] = v;
            }
        }
    }
}
