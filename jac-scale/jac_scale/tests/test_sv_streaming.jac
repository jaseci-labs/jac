"""Tests for generator-returning sv-RPC (the SSE streaming path).

Stack under test:

  jaclang.runtimelib._finalize_call_response  — passes generator results
                                                straight through
  jac_scale.microservices._sse.sse_frame_stream — wraps yields into
                                                  `data: {json}\n\n`
  jac_scale serve.endpoints.create_function_callback — emits as
                                                       text/event-stream
                                                       StreamingResponse
  jaclang.runtimelib.sv_sse._parse_sse / consume_sse_stream — parses
                                                              the framed
                                                              body line
                                                              by line
  jac_scale.plugin.sv_service_call (override) — picks SSE vs JSON by
                                                Content-Type, hands back a
                                                generator on SSE

Tests intercept at the httpx.Client level (matches test_sv_auth_forward).
The factory builds an httpx.MockTransport-backed Client; the handler can
return either a JSON Response (existing behavior) or an SSE Response so
we exercise both branches end-to-end.
"""

import httpx;
import json;
import from typing { Any }
import from jaclang.runtimelib { sv_client }
import from jaclang.runtimelib.sv_sse { _parse_sse, consume_sse_stream }
import from jac_scale.plugin { JacScalePlugin }


# =============================================================================
# Test helper (same shape as test_sv_auth_forward._mock_client_class — kept
# duplicated to avoid an import cycle; if a third file needs it, hoist into
# a shared tests/_mock_httpx.jac).
# =============================================================================
def _mock_client_class(handler: Any) -> Any {
    transport = httpx.MockTransport(handler);
    real_client_cls = httpx.Client;
    def factory(*args: Any, **kwargs: Any) -> Any {
        return real_client_cls(transport=transport);
    }
    return factory;
}


"""Compose a valid SSE body for use in tests.

`events` are JSON-serialized as one `data: {...}\n\n` chunk each.
`trailer` decides whether to append `event: end\ndata: {}\n\n`
(graceful close — the default) or `event: error\ndata: ...\n\n`
or "" (raw EOF — caller handles).
"""
def _sse_body(events: list[dict], trailer: str = "end") -> str {
    parts: list[str] = [];
    for ev in events {
        parts.append("data: " + json.dumps(ev) + "\n\n");
    }
    if trailer == "end" {
        parts.append("event: end\ndata: {}\n\n");
    } elif trailer == "error" {
        parts.append('event: error\ndata: {"message": "boom"}\n\n');
    }
    return "".join(parts);
}


# =============================================================================
# _parse_sse low-level parser
# =============================================================================

test "_parse_sse splits messages on blank lines and accumulates data" {
    body = (
        "data: hello\n"
        "\n"
        "data: line1\n"
        "data: line2\n"
        "\n"
    );
    out: list = [];
    for ev in _parse_sse(body.splitlines()) {
        out.append(ev);
    }
    assert out == [("message", "hello"), ("message", "line1\nline2")];
}

test "_parse_sse picks up event: tags and trims one leading space" {
    body = (
        "event: end\n"
        "data: {}\n"
        "\n"
        "event:error\n"
        "data:{\"message\": \"boom\"}\n"
        "\n"
    );
    out: list = [];
    for ev in _parse_sse(body.splitlines()) {
        out.append(ev);
    }
    assert out[0] == ("end", "{}");
    assert out[1][0] == "error";
}

test "_parse_sse ignores comment lines and unknown fields" {
    body = (
        ": this is a heartbeat comment — ignore me\n"
        "id: 42\n"
        "data: keep_me\n"
        "\n"
    );
    out: list = [];
    for ev in _parse_sse(body.splitlines()) {
        out.append(ev);
    }
    assert out == [("message", "keep_me")];
}

test "_parse_sse yields trailing message without final blank line" {
    body = (
        "data: a\n"
        "\n"
        "data: b\n"
    );
    out: list = [];
    for ev in _parse_sse(body.splitlines()) {
        out.append(ev);
    }
    assert out == [("message", "a"), ("message", "b")];
}

test "_parse_sse decodes bytes input (httpx iter_lines() under raw mode)" {
    body_lines = [b"data: hi", b"", b"event: end", b"data: {}", b""];
    out: list = [];
    for ev in _parse_sse(body_lines) {
        out.append(ev);
    }
    assert out[0] == ("message", "hi");
    assert out[1][0] == "end";
}


# =============================================================================
# consume_sse_stream — orchestrates _parse_sse over an httpx Response
# =============================================================================

obj _FakeResp {
    has body: str;
    def iter_lines -> Any {
        for line in self.body.splitlines() {
            yield line;
        }
    }
}

test "consume_sse_stream yields parsed dicts and stops at event: end" {
    events_in = [{"type": "tool_use", "step": 1}, {"type": "agent_text", "text": "hi"}];
    resp = _FakeResp(body=_sse_body(events_in));
    got: list = [];
    for ev in consume_sse_stream(resp, "test.func") {
        got.append(ev);
    }
    assert got == events_in;
}

test "consume_sse_stream raises RuntimeError on event: error" {
    resp = _FakeResp(body=_sse_body([], trailer="error"));
    raised_msg = "";
    try {
        for _ in consume_sse_stream(resp, "test.func") { ; }
    } except RuntimeError as e {
        raised_msg = str(e);
    }
    assert "test.func" in raised_msg;
    assert "boom" in raised_msg;
}

test "consume_sse_stream skips malformed JSON payload, keeps streaming" {
    body = (
        "data: {\"valid\": 1}\n"
        "\n"
        "data: not-json-{{\n"
        "\n"
        "data: {\"valid\": 2}\n"
        "\n"
        "event: end\n"
        "data: {}\n"
        "\n"
    );
    resp = _FakeResp(body=body);
    got: list = [];
    for ev in consume_sse_stream(resp, "test.func") {
        got.append(ev);
    }
    assert got == [{"valid": 1}, {"valid": 2}];
}


# =============================================================================
# sv_service_call end-to-end with an SSE-returning downstream
# =============================================================================

test "sv_service_call returns a generator when downstream emits SSE" {
    events_in = [
        {"type": "agent_started", "run_id": "r1"},
        {"type": "agent_text", "text": "hello"},
        {"type": "agent_done", "run_id": "r1"},
    ];

    def handler(request: httpx.Request) -> httpx.Response {
        return httpx.Response(
            status_code=200,
            headers={"content-type": "text/event-stream"},
            content=_sse_body(events_in)
        );
    }

    original_client = httpx.Client;
    httpx.Client = _mock_client_class(handler);

    try {
        sv_client.register("stream_mod", "http://demo.invalid");
        # SSE path: sv_service_call returns a generator, NOT a dict
        gen = JacScalePlugin.sv_service_call("stream_mod", "stream_events", {});
        out: list = [];
        for ev in gen {
            out.append(ev);
        }
        assert out == events_in;
    } finally {
        httpx.Client = original_client;
        sv_client.unregister("stream_mod");
    }
}

test "sv_service_call SSE path surfaces producer error as RuntimeError" {
    def handler(request: httpx.Request) -> httpx.Response {
        return httpx.Response(
            status_code=200,
            headers={"content-type": "text/event-stream"},
            content=_sse_body([{"type": "agent_started"}], trailer="error")
        );
    }

    original_client = httpx.Client;
    httpx.Client = _mock_client_class(handler);

    try {
        sv_client.register("stream_err_mod", "http://demo.invalid");
        gen = JacScalePlugin.sv_service_call("stream_err_mod", "stream_events", {});
        raised_msg = "";
        try {
            for _ in gen { ; }
        } except RuntimeError as e {
            raised_msg = str(e);
        }
        assert "stream_err_mod.stream_events" in raised_msg;
        assert "boom" in raised_msg;
    } finally {
        httpx.Client = original_client;
        sv_client.unregister("stream_err_mod");
    }
}

test "sv_service_call still unwraps JSON envelope when not SSE" {
    # Sanity check that the SSE branch didn't break the existing JSON path.
    def handler(request: httpx.Request) -> httpx.Response {
        return httpx.Response(
            status_code=200,
            json={"ok": True, "data": {"result": "plain_json_ok"}}
        );
    }

    original_client = httpx.Client;
    httpx.Client = _mock_client_class(handler);

    try {
        sv_client.register("json_mod", "http://demo.invalid");
        result = JacScalePlugin.sv_service_call("json_mod", "echo", {});
        assert result == "plain_json_ok";
    } finally {
        httpx.Client = original_client;
        sv_client.unregister("json_mod");
    }
}
