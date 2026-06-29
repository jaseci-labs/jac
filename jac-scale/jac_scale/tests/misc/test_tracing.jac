import from jac_scale.runtime.context.tracing {
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

glob _UUID: str = "0af76519-16cd-43dd-8448-eb211c80319c",
     _UUID_HEX: str = "0af7651916cd43dd8448eb211c80319c",
     _SPAN_HEX: str = "b7ad6b7169203331";


test "uuid_to_trace_id strips dashes and yields the 128-bit value" {
    tid = uuid_to_trace_id(_UUID);
    assert tid == int(_UUID_HEX, 16);

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

    assert parse_traceparent("00-abc-def") is None;

    assert parse_traceparent("00-tooShort-b7ad6b7169203331-01") is None;

    zero_tid = "0" * 32;
    assert parse_traceparent(f"00-{zero_tid}-{_SPAN_HEX}-01") is None;

    zero_sid = "0" * 16;
    assert parse_traceparent(f"00-{_UUID_HEX}-{zero_sid}-01") is None;
}

test "new_span_id is a non-zero 64-bit value" {
    sid = new_span_id();
    assert sid != 0;
    assert sid < (1 << 64);

    assert new_span_id() != new_span_id();
}

test "tracing lifecycle: inactive no-op, then active root + child spans" {
    assert tracing_active() == False;
    assert start_server_span("GET /x", _UUID) is None;
    assert current_traceparent(_UUID) is None;
    assert current_traceparent(None) is None;

    active = install_tracing(enabled=True, sample_ratio=1.0);
    if not active {
        return;
    }
    assert tracing_active() == True;

    rsp = start_server_span("GET /api/x", _UUID, None, {"http.method": "GET"});
    assert rsp is not None;
    assert rsp.parent is None;
    assert trace_id_hex(rsp.get_span_context().trace_id) == _UUID_HEX;

    up_tp = build_traceparent(uuid_to_trace_id(_UUID), new_span_id(), True);
    csp = start_server_span("POST /lookup", _UUID, up_tp, {});
    assert csp is not None;
    assert csp.parent is not None;
    assert trace_id_hex(csp.get_span_context().trace_id) == _UUID_HEX;

    end_span(csp);
    end_span(rsp);
}
