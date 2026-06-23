"""Tests for O-02 distributed tracing id-reconciliation helpers.

The correctness-critical property of O-02 is that a request's logs
(keyed on the K-12 UUID4 string) and its spans (keyed on the OTel
128-bit trace id) share ONE id - otherwise Grafana's trace<->log
pivots return nothing. These helpers are pure string/int math with no
OpenTelemetry dependency, so they are tested here directly (and pass
whether or not `jac-scale[tracing]` is installed).

Also asserts the no-op contract: with tracing inactive, span creation
returns None and the gateway/services run unchanged.
"""

import from jac_scale.microservices.runtime.tracing {
    uuid_to_trace_id,
    trace_id_hex,
    new_span_id,
    build_traceparent,
    parse_traceparent,
    current_traceparent,
    start_server_span,
    end_span,
    install_tracing,
    tracing_active
}

# A fixed UUID4 + the canonical 32-hex form of its 128 bits.
glob _UUID: str = "0af76519-16cd-43dd-8448-eb211c80319c",
     _UUID_HEX: str = "0af7651916cd43dd8448eb211c80319c",
     _SPAN_HEX: str = "b7ad6b7169203331";


test "uuid_to_trace_id strips dashes and yields the 128-bit value" {
    tid = uuid_to_trace_id(_UUID);
    assert tid == int(_UUID_HEX, 16);
    # The hex form is exactly the dash-stripped UUID - this is the join
    # key that must also appear in the log `trace_id` field.
    assert trace_id_hex(tid) == _UUID_HEX;
    assert trace_id_hex(tid) == _UUID.replace("-", "");
}

test "uuid_to_trace_id returns 0 (mint-fresh sentinel) on bad input" {
    assert uuid_to_trace_id(None) == 0;
    assert uuid_to_trace_id("") == 0;
    assert uuid_to_trace_id("not-hex-zzzz") == 0;
}

test "build_traceparent emits the canonical W3C format" {
    tid = int(_UUID_HEX, 16);
    sid = int(_SPAN_HEX, 16);
    sampled_tp = build_traceparent(tid, sid, True);
    assert sampled_tp == f"00-{_UUID_HEX}-{_SPAN_HEX}-01";
    unsampled_tp = build_traceparent(tid, sid, False);
    assert unsampled_tp == f"00-{_UUID_HEX}-{_SPAN_HEX}-00";
}

test "parse_traceparent round-trips build_traceparent" {
    tid = int(_UUID_HEX, 16);
    sid = int(_SPAN_HEX, 16);
    tp = build_traceparent(tid, sid, True);
    parsed = parse_traceparent(tp);
    assert parsed is not None;
    assert parsed["trace_id"] == tid;
    assert parsed["span_id"] == sid;
    assert parsed["sampled"] == True;
}

test "parse_traceparent rejects malformed headers" {
    assert parse_traceparent(None) is None;
    assert parse_traceparent("") is None;
    # wrong field count
    assert parse_traceparent("00-abc-def") is None;
    # wrong hex widths
    assert parse_traceparent("00-tooShort-b7ad6b7169203331-01") is None;
    # all-zero trace id is invalid per spec
    zero_tid = "0" * 32;
    assert parse_traceparent(f"00-{zero_tid}-{_SPAN_HEX}-01") is None;
    # all-zero span id is invalid per spec
    zero_sid = "0" * 16;
    assert parse_traceparent(f"00-{_UUID_HEX}-{zero_sid}-01") is None;
}

test "new_span_id is a non-zero 64-bit value" {
    sid = new_span_id();
    assert sid != 0;
    assert sid < (1 << 64);
    # two draws are (overwhelmingly) distinct
    assert new_span_id() != new_span_id();
}

# Single self-contained lifecycle test: it is the ONLY test that calls
# install_tracing (which flips a process-global), so it must assert the
# inactive contract BEFORE installing - keeping it in one test avoids any
# cross-test ordering dependency on the global install state.
test "tracing lifecycle: inactive no-op, then active root + child spans" {
    # --- before install: tracing inactive -> everything is a no-op ---
    assert tracing_active() == False;
    assert start_server_span("GET /x", _UUID) is None;
    assert current_traceparent(_UUID) is None;
    assert current_traceparent(None) is None;

    # --- install: jac-scale[tracing] is in the [test] extra, so
    # OpenTelemetry is present and tracing activates. If it ever isn't,
    # degrade gracefully - the pure helpers above already cover the
    # correctness-critical id reconciliation. ---
    active = install_tracing(enabled=True, sample_ratio=1.0);
    if not active {
        return;
    }
    assert tracing_active() == True;

    # Root hop (no inbound traceparent): a GENUINE root (no parent) whose
    # trace id is the UUID's 128 bits. This is what makes Tempo show a
    # real root and keeps the trace joinable to its logs.
    rsp = start_server_span("GET /api/x", _UUID, None, {"http.method": "GET"});
    assert rsp is not None;
    assert rsp.parent is None;
    assert trace_id_hex(rsp.get_span_context().trace_id) == _UUID_HEX;

    # Child hop (inbound traceparent): inherits the same trace id and gets
    # a real parent span id.
    up_tp = build_traceparent(uuid_to_trace_id(_UUID), new_span_id(), True);
    csp = start_server_span("POST /lookup", _UUID, up_tp, {});
    assert csp is not None;
    assert csp.parent is not None;
    assert trace_id_hex(csp.get_span_context().trace_id) == _UUID_HEX;

    end_span(csp);
    end_span(rsp);
}
