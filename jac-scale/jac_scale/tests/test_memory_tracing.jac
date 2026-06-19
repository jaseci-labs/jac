"""Tests for memory-hierarchy span helpers (start/end_memory_span).

These spans wrap the Redis (L2) and Mongo (L3) backend ops and must nest
under the active request SERVER span. Pure behaviour tests, no cluster:
- end_memory_span tolerates None.
- start_memory_span returns None when no SERVER span is active (so memory
  ops outside a traced request add nothing).
- with a SERVER span active, the memory span is a child (same trace id,
  different span id).

When OpenTelemetry isn't installed everything is a no-op, which the tests
assert instead of skipping.
"""

import from jac_scale.microservices.runtime.tracing {
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
        # OpenTelemetry not installed: every helper is a no-op.
        assert start_memory_span("memory.get") is None;
        return;
    }
    # Active, but no SERVER span open in this context -> no parent.
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

    # Child of the SERVER span: same trace id, distinct span id.
    sctx = server.get_span_context();
    mctx = mem.get_span_context();
    assert mctx.trace_id == sctx.trace_id;
    assert mctx.span_id != sctx.span_id;

    end_memory_span(mem);
    end_span(server);

    # Once the SERVER span ends, memory spans have no parent again.
    assert start_memory_span("memory.get") is None;
}
