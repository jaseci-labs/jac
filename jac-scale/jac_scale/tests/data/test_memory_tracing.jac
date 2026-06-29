import from jac_scale.runtime.context.tracing {
    install_tracing,
    start_server_span,
    end_span,
    start_memory_span,
    end_memory_span
}

glob _UUID: str = "0af7651916cd43dd8448eb211c80319c";


test "end_memory_span tolerates None" {
    end_memory_span(None);
    assert True;
}


test "memory span is None when no server span is active" {
    active = install_tracing(enabled=True, sample_ratio=1.0);
    if not active {
        assert start_memory_span("memory.get") is None;
        return;
    }

    assert start_memory_span("memory.get") is None;
}


test "memory span nests under the active server span" {
    active = install_tracing(enabled=True, sample_ratio=1.0);
    if not active {
        return;
    }
    server = start_server_span("GET /api/x", _UUID);
    assert server is not None;

    mem = start_memory_span(
        "memory.get", {"db.system": "mongodb", "mem.tier": "L3", "mem.op": "get"}
    );
    assert mem is not None;

    sctx = server.get_span_context();
    mctx = mem.get_span_context();
    assert mctx.trace_id == sctx.trace_id;
    assert mctx.span_id != sctx.span_id;

    end_memory_span(mem);
    end_span(server);

    assert start_memory_span("memory.get") is None;
}
