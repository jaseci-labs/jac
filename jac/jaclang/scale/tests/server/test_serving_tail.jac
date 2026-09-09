"""Guards #8000 follow-up 3: serving/restspec tail hardening.

Covers the trailing-slash 307 (FastAPI redirected, #7969 silently dropped
it), the WS lifecycle fixes (upgrades count as busy for drain grace,
cross-origin refusal by default, PING interleaved in a fragmented message,
aggregate reassembly cap), and OpenAPI fidelity (response content blocks,
WS routes present for the gateway).
"""

import asyncio;
import http.client;
import struct;
import time;
import from jaclang.server.serving.app { ServingApp }
import from jaclang.server.serving.datatypes { JSONResponse }
import from jaclang.server.serving.endpoint { HTTPMethod, JEndPoint, WSEndPoint }
import from jaclang.server.serving.openapi { build_openapi }
import from jaclang.server.serving.server { ServingServer }
import from jaclang.server.settings { ServeSettings }
import from jaclang.server.serving.ws {
    OP_CONT,
    OP_PING,
    OP_PONG,
    OP_TEXT,
    OP_CLOSE,
    encode_frame,
    read_frame
}


def _make_app -> ServingApp {
    def hello -> dict {
        return {"ok": True};
    }

    async def ws_echo(ws: any) {
        await ws.accept();
        while True {
            msg = await ws.receive();
            if msg["type"] == "websocket.disconnect" {
                return;
            }
            await ws.send_text(msg.get("text", ""));
        }
    }
    app = ServingApp();
    app.add_endpoint(JEndPoint(method=HTTPMethod.GET, path="/hello", callback=hello));
    app.add_ws_endpoint(WSEndPoint(path="/ws/echo", handler=ws_echo));
    return app;
}


def _spawn(
    ws_allowed_origins: (list[str] | None) = None, ws_max_message_bytes: int = 0
) -> tuple {
    settings = ServeSettings();
    if ws_allowed_origins is not None {
        settings.websocket.allowed_origins = list(ws_allowed_origins);
    }
    if ws_max_message_bytes {
        settings.websocket.max_message_bytes = ws_max_message_bytes;
    }
    server = ServingServer(
        app=_make_app(), settings=settings, host="127.0.0.1", port=0
    );
    stop = server.serve_background();
    return (stop, server);
}


def _run(coro: object) -> object {
    loop = asyncio.new_event_loop();
    try {
        return loop.run_until_complete(coro);
    } finally {
        loop.close();
    }
}


async def _ws_handshake(port: int, path: str, origin: str = "") -> tuple {
    (reader, writer) = await asyncio.open_connection("127.0.0.1", port);
    origin_line = f"Origin: {origin}\r\n" if origin else "";
    writer.write(
        (
            f"GET {path} HTTP/1.1\r\n"
            f"Host: 127.0.0.1:{port}\r\n"
            "Upgrade: websocket\r\n"
            "Connection: Upgrade\r\n"
            "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n"
            "Sec-WebSocket-Version: 13\r\n"
            f"{origin_line}\r\n"
        ).encode(
            "latin-1"
        )
    );
    await writer.drain();
    status_line = await reader.readline();
    while True {
        line = await reader.readline();
        if line in (b"\r\n", b"\n", b"") {
            break;
        }
    }
    return (reader, writer, status_line.decode("latin-1"));
}


test "trailing-slash miss 307-redirects to the canonical path (#8000 f3)" {
    (stop, server) = _spawn();
    try {
        conn = http.client.HTTPConnection("127.0.0.1", server.bound_port, timeout=10);
        conn.request("GET", "/hello/?a=1");
        resp = conn.getresponse();
        location = resp.getheader("Location");
        resp.read();
        conn.close();
        assert resp.status == 307 , f"expected 307, got {resp.status}";
        assert location == "/hello?a=1" , f"got Location={location!r}";

        conn2 = http.client.HTTPConnection("127.0.0.1", server.bound_port, timeout=10);
        conn2.request("GET", "/hello");
        resp2 = conn2.getresponse();
        body = resp2.read();
        conn2.close();
        assert resp2.status == 200 and b"true" in body.lower();
    } finally {
        stop();
    }
}


test "cross-origin WS upgrade is refused by default, allowed when configured" {
    (stop, server) = _spawn();
    try {
        async def refused -> str {
            (r, w, status) = await _ws_handshake(
                server.bound_port, "/ws/echo", origin="http://evil.example"
            );
            w.close();
            return status;
        }
        status = str(_run(refused()));
        assert " 403 " in status , f"cross-origin upgrade must 403, got {status!r}";

        async def same_origin -> str {
            (r, w, status) = await _ws_handshake(
                server.bound_port,
                "/ws/echo",
                origin=f"http://127.0.0.1:{server.bound_port}"
            );
            w.close();
            return status;
        }
        ok = str(_run(same_origin()));
        assert " 101 " in ok , f"same-origin upgrade must pass, got {ok!r}";
    } finally {
        stop();
    }

    (stop2, server2) = _spawn(ws_allowed_origins=["http://evil.example"]);
    try {
        async def allowed -> str {
            (r, w, status) = await _ws_handshake(
                server2.bound_port, "/ws/echo", origin="http://evil.example"
            );
            w.close();
            return status;
        }
        ok2 = str(_run(allowed()));
        assert " 101 " in ok2 , f"allowlisted origin must pass, got {ok2!r}";
    } finally {
        stop2();
    }
}


test "PING interleaved in a fragmented message is answered, message survives" {
    # RFC 6455 s5.4: control frames MAY be injected between fragments. The old
    # loop treated any non-CONT opcode between fragments as a protocol error
    # and closed 1002.
    (stop, server) = _spawn();
    try {
        async def scenario -> dict {
            (reader, writer, status) = await _ws_handshake(
                server.bound_port, "/ws/echo"
            );
            assert " 101 " in status;
            writer.write(
                encode_frame(OP_TEXT, b"he", mask=True)[:1].replace(b'\x81', b'\x01')
                    + encode_frame(OP_TEXT, b"he", mask=True)[1:]
            );
            writer.write(encode_frame(OP_PING, b"x", mask=True));
            writer.write(encode_frame(OP_CONT, b"llo", mask=True));
            await writer.drain();
            pong = await read_frame(reader, require_mask=False);
            echo = await read_frame(reader, require_mask=False);
            writer.close();
            return {
                "pong_op": pong.opcode,
                "echo_op": echo.opcode,
                "echo": echo.payload.decode("utf-8")
            };
        }
        result = _run(scenario());
        assert result["pong_op"] == OP_PONG , f"expected PONG, got {result}";
        assert result["echo_op"] == OP_TEXT and result["echo"] == "hello" , (
            f"fragmented message must survive the interleaved PING: {result}"
        );
    } finally {
        stop();
    }
}


test "aggregate reassembly cap closes 1009 before the message decodes" {
    (stop, server) = _spawn(ws_max_message_bytes=1024);
    try {
        async def scenario -> int {
            (reader, writer, status) = await _ws_handshake(
                server.bound_port, "/ws/echo"
            );
            assert " 101 " in status;
            first = encode_frame(OP_TEXT, b"a" * 600, mask=True);
            writer.write(first[:1].replace(b'\x81', b'\x01') + first[1:]);
            writer.write(encode_frame(OP_CONT, b"b" * 600, mask=True));
            await writer.drain();
            frame = await read_frame(reader, require_mask=False);
            writer.close();
            assert frame.opcode == OP_CLOSE , f"expected CLOSE, got opcode {frame.opcode}";
            return struct.unpack("!H", frame.payload[:2])[0];
        }
        code = int(_run(scenario()));
        assert code == 1009 , f"oversized reassembly must close 1009, got {code}";
    } finally {
        stop();
    }
}


test "an open WS connection counts as busy so drain grants it grace" {
    (stop, server) = _spawn();
    try {
        async def scenario -> int {
            (reader, writer, status) = await _ws_handshake(
                server.bound_port, "/ws/echo"
            );
            assert " 101 " in status;
            deadline = time.time() + 5.0;
            while time.time() < deadline and not server._busy {
                await asyncio.sleep(0.05);
            }
            n = len(server._busy);
            writer.close();
            return n;
        }
        busy = int(_run(scenario()));
        assert busy >= 1 , "WS handlers must be in _busy or drain kills them at 0s";
    } finally {
        stop();
    }
}


test "openapi carries response content blocks and WS routes (#8000 f3)" {
    app = _make_app();
    doc = build_openapi(app);
    hello = doc["paths"]["/hello"]["get"];
    content = hello["responses"]["200"].get("content");
    assert content and "application/json" in content , (
        "responses must advertise a content type for schema consumers"
    );
    assert "/ws/echo" in doc["paths"] , (
        "WS routes must be in the document so the gateway learns ownership"
    );
    assert "101" in doc["paths"]["/ws/echo"]["get"]["responses"];
}
