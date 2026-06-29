import httpx;
import json;
import from jaclang.runtimelib { sv_client }
import from jaclang.runtimelib.sv_sse { _parse_sse, consume_sse_stream }
import from jac_scale.plugin { JacScalePlugin }


def _mock_client_class(handler: any) -> any {
    transport = httpx.MockTransport(handler);
    real_client_cls = httpx.Client;
    def factory(*args: any, **kwargs: any) -> any {
        return real_client_cls(transport=transport);
    }
    return factory;
}


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


test "_parse_sse splits messages on blank lines and accumulates data" {
    body = "data: hello\n" "\n" "data: line1\n" "data: line2\n" "\n";
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
        ": this is a heartbeat comment - ignore me\n" "id: 42\n" "data: keep_me\n" "\n"
    );
    out: list = [];
    for ev in _parse_sse(body.splitlines()) {
        out.append(ev);
    }
    assert out == [("message", "keep_me")];
}

test "_parse_sse yields trailing message without final blank line" {
    body = "data: a\n" "\n" "data: b\n";
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


obj _FakeResp {
    has body: str;

    def iter_lines -> any {
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
        for _ in consume_sse_stream(resp, "test.func") {
            ;
        }
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
            for _ in gen {
                ;
            }
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
    def handler(request: httpx.Request) -> httpx.Response {
        return httpx.Response(
            status_code=200, json={"ok": True, "data": {"result": "plain_json_ok"}}
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
