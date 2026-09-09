import json;
import json as json_lib;
import from jaclang.server { sv_client }
import from jaclang.server.serving.sse {
    consume_sse_events as consume_sse_stream,
    parse_sse as _parse_sse
}
import from jaclang.scale.plugin { JacScalePlugin }


obj _StubResp {
    has body_text: str,
        content_type: str = "application/json";

    has text: str { getter; }

    def json -> any {
        return json_lib.loads(self.body_text);
    }

    def headers_obj -> any {
        import from jaclang.server.serving.datatypes { Headers }
        h = Headers();
        h.set("Content-Type", self.content_type);
        return h;
    }

    has headers: any { getter; }
}

impl _StubResp.text.getter -> str {
    return self.body_text;
}

impl _StubResp.headers.getter -> any {
    return self.headers_obj();
}

obj _StubClient {
    has body_text: str,
        content_type: str = "application/json",
        headers_seen: list[dict] = [];

    def post(path: str, json: any = None, headers: (dict | None) = None) -> _StubResp {
        self.headers_seen.append(dict(headers or {}));
        return _StubResp(body_text=self.body_text, content_type=self.content_type);
    }
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

test "_parse_sse decodes bytes input (native client aiter_lines yields bytes)" {
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
    for ev in consume_sse_stream(resp.iter_lines(), "test.func") {
        got.append(ev);
    }
    assert got == events_in;
}

test "consume_sse_stream raises RuntimeError on event: error" {
    resp = _FakeResp(body=_sse_body([], trailer="error"));
    raised_msg = "";
    try {
        for _ in consume_sse_stream(resp.iter_lines(), "test.func") {}
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
    for ev in consume_sse_stream(resp.iter_lines(), "test.func") {
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

    sv_client._test_clients["stream_mod"] = _StubClient(
        body_text=_sse_body(events_in), content_type="text/event-stream"
    );
    try {
        gen = JacScalePlugin.sv_service_call("stream_mod", "stream_events", {});
        out: list = [];
        for ev in gen {
            out.append(ev);
        }
        assert out == events_in;
    } finally {
        sv_client._test_clients.pop("stream_mod", None);
    }
}

test "sv_service_call SSE path surfaces producer error as RuntimeError" {
    sv_client._test_clients["stream_err_mod"] = _StubClient(
        body_text=_sse_body([{"type": "agent_started"}], trailer="error"),
        content_type="text/event-stream"
    );
    try {
        gen = JacScalePlugin.sv_service_call("stream_err_mod", "stream_events", {});
        raised_msg = "";
        try {
            for _ in gen {}
        } except RuntimeError as e {
            raised_msg = str(e);
        }
        assert "stream_err_mod.stream_events" in raised_msg;
        assert "boom" in raised_msg;
    } finally {
        sv_client._test_clients.pop("stream_err_mod", None);
    }
}

test "sv_service_call still unwraps JSON envelope when not SSE" {
    sv_client._test_clients["json_mod"] = _StubClient(
        body_text=json.dumps({"ok": True, "data": {"result": "plain_json_ok"}})
    );
    try {
        result = JacScalePlugin.sv_service_call("json_mod", "echo", {});
        assert result == "plain_json_ok";
    } finally {
        sv_client._test_clients.pop("json_mod", None);
    }
}


test "sv_walker_call carries the idempotency header through the scale transport" {
    stub = _StubClient(
        body_text=json.dumps({"ok": True, "data": {"result": {}, "reports": []}})
    );
    sv_client._test_clients["hdr_mod"] = stub;
    try {
        JacScalePlugin.sv_walker_call(
            "hdr_mod", "Greet", {}, None, headers={"X-Jac-Idempotency-Key": "k-1"}
        );
        assert stub.headers_seen[0]["X-Jac-Idempotency-Key"] == "k-1";
    } finally {
        sv_client._test_clients.pop("hdr_mod", None);
    }
}


obj _StubTransport {
    has calls: list[dict] = [];

    def sv_transport_available -> bool {
        return True;
    }

    def sv_service_call(
        app: str, func_name: str, args: dict, headers: (dict | None) = None
    ) -> any {
        self.calls.append(
            {"kind": "fn", "name": func_name, "headers": dict(headers or {})}
        );
        return "ok";
    }

    def sv_walker_call(
        app: str,
        walker_name: str,
        args: dict,
        stub_cls: any,
        headers: (dict | None) = None
    ) -> any {
        self.calls.append(
            {"kind": "walker", "name": walker_name, "headers": dict(headers or {})}
        );
        return {"reports": []};
    }
}


test "spawn_walker hands the idempotency key to the scale transport" {
    import asyncio;
    import unittest.mock;
    stub = _StubTransport();

    def _transport -> any {
        return stub;
    }
    patcher: any = unittest.mock.patch.object(
        sv_client, "_scale_transport", _transport
    );
    try {
        sv_client.register("scale_hdr_mod", "http://demo.invalid");
        with patcher {
            asyncio.run(
                sv_client.spawn_walker(
                    "scale_hdr_mod",
                    "Greet",
                    {"name": "ada"},
                    None,
                    idempotency_key="k-2"
                )
            );
            asyncio.run(sv_client.call("scale_hdr_mod", "ping", {}));
        }
        assert stub.calls[0]["kind"] == "walker";
        assert stub.calls[0]["headers"]["X-Jac-Idempotency-Key"] == "k-2";
        assert stub.calls[1]["kind"] == "fn";
        assert "X-Jac-Idempotency-Key" not in stub.calls[1]["headers"];
    } finally {
        sv_client.unregister("scale_hdr_mod");
    }
}


test "an outbox delivery reaches the scale transport with its idempotency key" {
    import os;
    import unittest.mock;
    import from tempfile { TemporaryDirectory }
    import from jaclang.server.outbox {
        STATUS_DELIVERED,
        SqliteOutboxStore,
        default_idempotency_key,
        deliver_pending,
        enqueue,
        use_store
    }
    stub = _StubTransport();

    def _transport -> any {
        return stub;
    }
    patcher: any = unittest.mock.patch.object(
        sv_client, "_scale_transport", _transport
    );
    with TemporaryDirectory() as tmp {
        store = SqliteOutboxStore(path=os.path.join(tmp, "outbox.sqlite"));
        use_store(store);
        try {
            sv_client.register("outbox_scale_mod", "http://demo.invalid");
            key = default_idempotency_key("outbox_scale_mod", "Greet", {"name": "ada"});
            enqueue("outbox_scale_mod", "Greet", {"name": "ada"});
            with patcher {
                assert deliver_pending() == 1;
            }
            assert stub.calls[0]["name"] == "Greet";
            assert stub.calls[0]["headers"]["X-Jac-Idempotency-Key"] == key;
            stored = store.get_by_key(key);
            assert stored is not None and stored.status == STATUS_DELIVERED;
        } finally {
            sv_client.unregister("outbox_scale_mod");
            use_store(None);
        }
    }
}
