"""Tests for the in-admin Traces backend (/admin/traces/*).

Pure-function unit tests for the Tempo-proxy helpers in
`admin/impl/traces.impl.jac`: trace-id normalization (the join key
between logs and Tempo), TraceQL query building, and flattening Tempo's
OTLP-JSON trace into the flat span list the React waterfall consumes.
"""

import from jaclang.scale.admin.traces {
    _normalize_trace_id,
    _build_traceql,
    _otlp_value,
    _otlp_attrs,
    _flatten_tempo_trace
}


test "normalize_trace_id: dashed UUID or 32-hex -> 32-hex; garbage -> ''" {
    # A dashed UUID and Tempo's 32-hex are the same 128 bits.
    assert _normalize_trace_id("0af76519-16cd-43dd-8448-eb211c80319c") == "0af7651916cd43dd8448eb211c80319c";
    assert _normalize_trace_id("0AF7651916CD43DD8448EB211C80319C") == "0af7651916cd43dd8448eb211c80319c";
    assert _normalize_trace_id("") == "";
    assert _normalize_trace_id("not-hex-zzzz") == "";
}


test "build_traceql composes selectors; empty filters match all" {
    assert _build_traceql("", "", 0) == "{ }";
    assert _build_traceql("gateway", "", 0) == "{ resource.service.name = \"gateway\" }";
    q = _build_traceql("cart", "error", 200);
    assert "resource.service.name = \"cart\"" in q;
    assert "status = error" in q;
    assert "duration > 200ms" in q;
    assert "&&" in q;
}


test "otlp value + attrs extraction" {
    assert _otlp_value({"stringValue": "GET"}) == "GET";
    assert _otlp_value({"intValue": "5"}) == "5";
    assert _otlp_value({}) == "";
    attrs = _otlp_attrs(
        [
            {"key": "http.method", "value": {"stringValue": "GET"}},
            {"key": "http.status_code", "value": {"intValue": "200"}}
        ]
    );
    assert attrs["http.method"] == "GET";
    assert attrs["http.status_code"] == "200";
}


test "flatten_tempo_trace -> flat spans with service, timing, attributes" {
    payload = {
        "batches": [
            {
                "resource": {
                    "attributes": [
                        {"key": "service.name", "value": {"stringValue": "gateway"}}
                    ]
                },
                "scopeSpans": [
                    {
                        "spans": [
                            {
                                "spanId": "b7ad6b7169203331",
                                "parentSpanId": "",
                                "name": "GET /api/x",
                                "kind": "SERVER",
                                "startTimeUnixNano": "1000000000",
                                "endTimeUnixNano": "1300000000",
                                "status": {"code": "STATUS_CODE_OK"},
                                "attributes": [
                                    {
                                        "key": "http.method",
                                        "value": {"stringValue": "GET"}
                                    }
                                ]
                            }
                        ]
                    }
                ]
            }
        ]
    };
    flat = _flatten_tempo_trace(payload);
    assert flat["count"] == 1;
    sp = flat["spans"][0];
    assert sp["service"] == "gateway";
    assert sp["name"] == "GET /api/x";
    assert sp["span_id"] == "b7ad6b7169203331";
    # (1.3e9 - 1.0e9) ns = 300 ms.
    assert sp["duration_ms"] == 300.0;
    assert sp["attributes"]["http.method"] == "GET";
}
