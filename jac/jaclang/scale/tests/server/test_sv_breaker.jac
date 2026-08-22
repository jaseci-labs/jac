import jaclang.runtimelib.serving.client as sv_http;
import socket;
import threading;
import from jaclang.runtimelib { sv_client }
import from jaclang.scale.plugin { JacScalePlugin }
import from jaclang.scale.tests._sv_test_support {
    _MockRequest,
    _MockResponse,
    _install_mock,
    _install_unreachable_transport,
    _install_unreachable_walker_transport,
    _install_rpc_timeout,
    _restore_rpc_timeout
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

test "HALF_OPEN probe failure re-opens the breaker with a fresh cooldown" {
    import time;
    import from jaclang.scale.runtime.rpc.breaker {
        _breaker_peek,
        _breaker_force_cooldown_elapsed
    }

    mod = "breaker_half_open_reopen_test";
    _breaker_reset(mod);

    for _ in range(_BREAKER_TRIP_THRESHOLD) {
        breaker_record_failure(mod);
    }
    assert breaker_should_skip(mod);

    _breaker_force_cooldown_elapsed(mod);
    assert not breaker_should_skip(mod);
    st = _breaker_peek(mod);
    assert st is not None and st["state"] == "HALF_OPEN";

    before = time.time();
    breaker_record_failure(mod);
    after = time.time();

    st = _breaker_peek(mod);
    assert st is not None and st["state"] == "OPEN";
    assert before <= st["opened_at"] <= after;

    assert breaker_should_skip(mod);

    _breaker_reset(mod);
}

test "walker_call records one breaker failure per failed round trip" {
    import from jaclang.scale.runtime.rpc.breaker { _breaker_peek }
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
    import from jaclang.scale.runtime.rpc.breaker {
        _breaker_peek,
        _breaker_force_cooldown_elapsed
    }

    mod = "breaker_probe_single_test";
    _breaker_reset(mod);
    for _ in range(_BREAKER_TRIP_THRESHOLD) {
        breaker_record_failure(mod);
    }
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
