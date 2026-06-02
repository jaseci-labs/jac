"""Tests for A-05a's JacAPIServerLogs mixin. Verifies the 3 endpoint
paths get registered correctly on the JFastApiServer; the actual
handler bodies are integration-tested via the real-cluster e2e
(scripts/k8s_microservice_real_e2e.sh) since they require a live
Loki backend."""

import from jac_scale.admin.logs { JacAPIServerLogs }
import from jac_scale.jserver.jfast_api { JFastApiServer }


obj LogsHost(JacAPIServerLogs) {
    has server: any = None;
}


test "register_logs_endpoints adds /admin/logs, /admin/logs/services, /admin/logs/trace/{id}" {
    host = LogsHost();
    host.server = JFastApiServer();

    host.register_logs_endpoints();

    paths = [e.path for e in host.server._endpoints];
    # The 3 endpoints the React LogsPage talks to.
    assert "/admin/logs/services" in paths;
    assert "/admin/logs" in paths;
    assert "/admin/logs/trace/{trace_id}" in paths;
}


test "all logs endpoints are GET (read-only surface)" {
    import from jac_scale.jserver.jserver { HTTPMethod }

    host = LogsHost();
    host.server = JFastApiServer();
    host.register_logs_endpoints();

    for ep in host.server._endpoints {
        if ep.path.startswith("/admin/logs") {
            assert ep.method == HTTPMethod.GET , f"{ep.path} should be GET, got {ep.method}";
        }
    }
}


test "logs endpoints are tagged 'Logs' so OpenAPI groups them" {
    host = LogsHost();
    host.server = JFastApiServer();
    host.register_logs_endpoints();

    for ep in host.server._endpoints {
        if ep.path.startswith("/admin/logs") {
            assert ep.tags == ["Logs"] , f"{ep.path} should be tagged ['Logs'], got {ep.tags}";
        }
    }
}


test "flatten newest-first vs oldest-first via ascending flag" {
    # Listing wants newest-first (matches `kubectl logs --tail` UX);
    # trace-detail wants oldest-first (causal order). Same flattener,
    # different `ascending=` argument; nanosecond ts_ns is what we
    # sort on, not the lossy ISO string.
    import from jac_scale.admin.logs { _flatten_loki_response }

    payload = {
        "data": {
            "result": [
                {
                    "stream": {"namespace": "ns", "pod": "p1"},
                    "values": [
                        ["1716412345000000000", "older"],
                        ["1716412355000000000", "newer"]
                    ]
                }
            ]
        }
    };

    asc = _flatten_loki_response(payload, ascending=True);
    assert asc[0].get("msg") == "older" , f"asc[0] = {asc[0]}";
    assert asc[1].get("msg") == "newer" , f"asc[1] = {asc[1]}";

    desc = _flatten_loki_response(payload, ascending=False);
    assert desc[0].get("msg") == "newer" , f"desc[0] = {desc[0]}";
    assert desc[1].get("msg") == "older" , f"desc[1] = {desc[1]}";

    # ts_ns must survive flattening so the listing endpoint can use
    # it as a `before` cursor for older-page pagination.
    assert desc[0].get("ts_ns") == "1716412355000000000" , f"ts_ns missing: {desc[0]}";
}


test "trace filter renders bracket escapes Loki's parser accepts" {
    # Regression: pre-fix, the trace_id pipeline produced a LogQL
    # string containing a bare `\[` which Go's strconv.Unquote
    # rejects with "invalid char escape", so Loki returned HTTP 400
    # and the admin UI showed "Log backend unavailable" whenever the
    # user clicked into a trace row. Brackets must be encoded as
    # `\\[` / `\\]` in the LogQL string so unescaping yields `\[` /
    # `\]` for the regex engine.
    import from jac_scale.admin.logs { _build_logql }

    q = _build_logql("ns", "", "", "", "abc12345-dead-beef-cafe-000000000001");
    assert "\\\\[trace=" in q , f"expected `\\\\[` in {q}";
    assert "\\\\]" in q , f"expected `\\\\]` in {q}";
    # And no bare `\[` (which would re-introduce the parser error).
    assert "\\[" not in q.replace("\\\\[", "") , f"bare `\\[` found in {q}";
}


test "search filter doubles backslashes before escaping quotes" {
    # Regression: pre-fix, the replace order was quotes-first then
    # backslashes, which re-doubled the backslashes the quote-escape
    # had just inserted, delivering stray `\` chars to Loki's
    # substring match. Doubling backslashes first keeps quote
    # escapes intact.
    import from jac_scale.admin.logs { _build_logql }

    q = _build_logql("ns", "", "", 'say "hi"', "");
    # The final LogQL fragment must read: |= "say \"hi\""
    assert '|= "say \\"hi\\""' in q , f"unexpected escape shape: {q}";
}
