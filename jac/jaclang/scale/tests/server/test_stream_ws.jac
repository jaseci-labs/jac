import asyncio;
import from jaclang.scale.runtime.middleware.ws_forward {
    _to_ws_scheme,
    _select_handshake_headers,
    websocket_forward
}
import from jaclang.scale.runtime.transport.http_forward {
    ForwardResult,
    stream_forward,
    raw_forward
}


test "ws scheme rewrite: http -> ws" {
    assert _to_ws_scheme("http://127.0.0.1:8001/ws/chat")
        == "ws://127.0.0.1:8001/ws/chat";
}


test "ws scheme rewrite: https -> wss" {
    assert _to_ws_scheme("https://api.internal/ws") == "wss://api.internal/ws";
}


test "ws scheme rewrite passes through already ws/wss URLs" {
    assert _to_ws_scheme("ws://a/b") == "ws://a/b";
    assert _to_ws_scheme("wss://a/b") == "wss://a/b";
}


test "handshake headers keep auth + trace, drop the rest, and stamp the peer onto xff" {
    inbound = {
        "Authorization": "Bearer abc",
        "X-Trace-Id": "trace-123",
        "X-Forwarded-For": "10.0.0.1",
        "Cookie": "session=xyz",
        "User-Agent": "some/1.0",
        "Host": "gateway",
        "Connection": "Upgrade",
        "Upgrade": "websocket",
        "Sec-WebSocket-Key": "dGhlIHNhbXBsZQ==",
        "Sec-WebSocket-Version": "13"
    };
    out = _select_handshake_headers(inbound, "198.51.100.7");
    assert "Authorization" in out;
    assert out["Authorization"] == "Bearer abc";
    assert "X-Trace-Id" in out;
    assert out["X-Forwarded-For"] == "10.0.0.1, 198.51.100.7";

    assert "Cookie" not in out;
    assert "User-Agent" not in out;
    assert "Host" not in out;
    assert "Connection" not in out;
    assert "Upgrade" not in out;
    assert "Sec-WebSocket-Key" not in out;
    assert "Sec-WebSocket-Version" not in out;
}


test "handshake xff is the bare peer when the client sent no xff" {
    out = _select_handshake_headers({"Authorization": "Bearer abc"}, "198.51.100.7");
    assert out["X-Forwarded-For"] == "198.51.100.7";
}


test "handshake headers are case-insensitive on the filter" {
    inbound = {
        "authorization": "Bearer x",
        "X-TRACE-ID": "t1",
        "x-forwarded-for": "10.0.0.1",
        "sec-websocket-key": "k"
    };
    out = _select_handshake_headers(inbound, "198.51.100.7");
    assert out["authorization"] == "Bearer x";
    assert out["X-TRACE-ID"] == "t1";
    assert out["X-Forwarded-For"] == "10.0.0.1, 198.51.100.7";
    assert "x-forwarded-for" not in out;
    assert "sec-websocket-key" not in out;
}


"""Stand up an upstream on the native serving core.

The forwarders used to be exercised against an aiohttp server; the runtime no
longer depends on aiohttp, so the upstream is the same server jac ships."""
def _spawn_upstream -> tuple[object, object, str] {
    import from jaclang.server.serving.app { ServingApp }
    import from jaclang.server.serving.datatypes { Request, Response }
    import from jaclang.server.serving.endpoint { HTTPMethod, JEndPoint }
    import from jaclang.server.serving.server { ServingServer }

    def echo(request: Request) -> Response {
        return Response(content=request.body, media_type="application/octet-stream");
    }

    def sse -> any {
        def gen -> any {
            for i in range(3) {
                yield f"data: event{i}\n\n";
            }
        }
        import from jaclang.server.serving.datatypes { StreamingResponse }
        return StreamingResponse(gen(), media_type="text/event-stream");
    }

    def big -> any {
        def gen -> any {
            for _ in range(16) {
                yield b"x" * 4096;
            }
        }
        import from jaclang.server.serving.datatypes { StreamingResponse }
        return StreamingResponse(gen());
    }

    def fourofour -> Response {
        return Response(content=b"nope", status_code=404);
    }
    app = ServingApp();
    app.add_endpoint(JEndPoint(method=HTTPMethod.POST, path="/echo", callback=echo));
    app.add_endpoint(JEndPoint(method=HTTPMethod.GET, path="/sse", callback=sse));
    app.add_endpoint(JEndPoint(method=HTTPMethod.GET, path="/big", callback=big));
    app.add_endpoint(
        JEndPoint(method=HTTPMethod.GET, path="/fourofour", callback=fourofour)
    );
    server = ServingServer(app=app, host="127.0.0.1", port=0);
    stop = server.serve_background();
    return (stop, server, f"http://127.0.0.1:{server.bound_port}");
}

def _run(coro: any) -> any {
    loop = asyncio.new_event_loop();
    try {
        return loop.run_until_complete(coro);
    } finally {
        loop.close();
    }
}


test "stream_forward streams SSE end-to-end with Content-Type preserved" {
    async def body -> dict {
        (stop_upstream, server, base) = _spawn_upstream();
        try {
            fr = await stream_forward("GET", f"{base}/sse", {}, b"");
            assert fr is not None;
            ctype = fr.headers.get("Content-Type") or fr.headers.get("content-type");
            sr = fr.to_response();
            got = b"";
            async for chunk in sr.body_iterator {
                got += chunk if isinstance(chunk, bytes) else chunk.encode("utf-8");
            }
            return {"ctype": ctype, "status": fr.status, "body": got.decode("utf-8")};
        } finally {
            stop_upstream();
        }
    }
    result = _run(body());
    assert result["status"] == 200;
    assert "text/event-stream" in (result["ctype"] or "");
    assert "data: event0" in result["body"];
    assert "data: event1" in result["body"];
    assert "data: event2" in result["body"];
}


test "stream_forward streams chunked large body without buffering" {
    async def body -> dict {
        (stop_upstream, server, base) = _spawn_upstream();
        try {
            fr = await stream_forward("GET", f"{base}/big", {}, b"");
            assert fr is not None;
            sr = fr.to_response();
            chunk_count: int = 0;
            total: int = 0;
            async for chunk in sr.body_iterator {
                chunk_count += 1;
                total += len(chunk)
                    if isinstance(chunk, bytes)
                    else len(chunk.encode());
            }
            return {"status": fr.status, "count": chunk_count, "total": total};
        } finally {
            stop_upstream();
        }
    }
    result = _run(body());
    assert result["status"] == 200;
    assert result["total"] == 65536;
    assert result["count"] >= 1;
}


test "stream_forward.cleanup closes session without streaming" {
    async def body -> dict {
        (stop_upstream, server, base) = _spawn_upstream();
        try {
            fr = await stream_forward("GET", f"{base}/fourofour", {}, b"");
            assert fr is not None;
            assert fr.status == 404;
            await fr.cleanup();
            return {"ok": True};
        } finally {
            stop_upstream();
        }
    }
    assert _run(body())["ok"];
}


test "stream_forward returns None on connect refused (caller emits 502)" {
    async def body -> object {
        fr = await stream_forward("GET", "http://127.0.0.1:1/does/not/matter", {}, b"");
        return fr;
    }
    assert _run(body()) is None;
}


test "raw_forward still buffers for the passthrough path" {
    async def body -> object {
        (stop_upstream, server, base) = _spawn_upstream();
        try {
            result = await raw_forward("POST", f"{base}/echo", {}, b"hello");
            return result;
        } finally {
            stop_upstream();
        }
    }
    result = _run(body());
    assert result is not None;
    (status, headers, body_bytes) = result;
    assert status == 200;
    assert body_bytes == b"hello";
}


test "ws route closes with 1008 when no registry prefix matches" {
    import from jaclang.scale.runtime.gateway.service_registry { ServiceRegistry }
    import from jaclang.scale.runtime.gateway.microservice_gateway {
        MicroserviceGateway
    }
    import from jaclang.testing.testkit { ServingTestClient as TestClient }
    import from jaclang.server.serving.datatypes { WebSocketDisconnect }

    reg = ServiceRegistry();
    gw = MicroserviceGateway(registry=reg);
    gw.setup();

    client = TestClient(gw.app);
    got_code: int = 0;
    try {
        with client.websocket_connect("/no/such/prefix") as ws {
            try {
                ws.receive_text();
            } except WebSocketDisconnect as inner {
                got_code = getattr(inner, "code", 0);
            }
        }
    } except WebSocketDisconnect as outer {
        got_code = getattr(outer, "code", 0);
    }
    assert got_code == 1008;
}


test "ws route rejects with 1012 during drain" {
    import from jaclang.scale.runtime.gateway.service_registry {
        ServiceRegistry,
        ServiceEntry,
        ServiceStatus
    }
    import from jaclang.scale.runtime.gateway.microservice_gateway {
        MicroserviceGateway
    }
    import from jaclang.testing.testkit { ServingTestClient as TestClient }

    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(
            name="orders",
            file="orders.jac",
            prefix="/api/orders",
            port=8001,
            url="http://127.0.0.1:8001",
            status=ServiceStatus.HEALTHY
        )
    );
    gw = MicroserviceGateway(registry=reg);
    gw.setup();

    client = TestClient(gw.app);
    gw.drain.start("test");
    try {
        raised = False;
        try {
            with client.websocket_connect("/api/orders/ws/chat") as ws {
                ws.receive_text();
            }
        } except Exception as e {
            raised = True;
        }
        assert raised;
    } finally {
        gw.drain.reset();
    }
}


obj FakeClientWS {
    has inbound: any,
        sent: list,
        closed: bool = False,
        close_code: int = 0,
        client_host: str = "",
        accepts: list[str] = [];

    async def accept(subprotocol: str = '') {
        self.accepts.append(subprotocol);
    }

    async def receive -> dict {
        return await self.inbound.get();
    }

    async def send_text(data: str) {
        self.sent.append(("text", data));
    }

    async def send_bytes(data: bytes) {
        self.sent.append(("bytes", data));
    }

    async def close(code: int = 1000) {
        self.closed = True;
        self.close_code = code;
    }
}


"""Upstream websocket echo, served by the native ws codec."""
def _spawn_ws_upstream(
    captured_headers: list | None = None
) -> tuple[object, object, str] {
    import from jaclang.server.serving.app { ServingApp }
    import from jaclang.server.serving.endpoint { WSEndPoint }
    import from jaclang.server.serving.server { ServingServer }

    async def ws_echo(ws: any) {
        if captured_headers is not None {
            captured_headers.append(dict(ws.headers.items()));
        }
        await ws.accept();
        while True {
            msg = await ws.receive();
            if msg["type"] == "websocket.disconnect" {
                break;
            }
            if "text" in msg {
                await ws.send_text(msg["text"]);
                if msg["text"] == "bye" {
                    break;
                }
            } elif "bytes" in msg {
                await ws.send_bytes(msg["bytes"]);
            }
        }
        await ws.close();
    }
    app = ServingApp();
    app.add_ws_endpoint(WSEndPoint(path="/ws", handler=ws_echo));
    server = ServingServer(app=app, host="127.0.0.1", port=0);
    stop = server.serve_background();
    return (stop, server, f"http://127.0.0.1:{server.bound_port}/ws");
}

test "websocket_forward round-trips text and binary through a real upstream ws" {
    async def body -> dict {
        upstream_headers: list[dict[str, str]] = [];
        (stop_upstream, server, base) = _spawn_ws_upstream(upstream_headers);
        try {
            client = FakeClientWS(
                inbound=asyncio.Queue(), sent=[], client_host="203.0.113.9"
            );
            client.inbound.put_nowait({"type": "websocket.receive", "text": "hello"});
            client.inbound.put_nowait(
                {"type": "websocket.receive", "bytes": b"\x00\x01\x02"}
            );
            client.inbound.put_nowait({"type": "websocket.receive", "text": "bye"});
            client.inbound.put_nowait({"type": "websocket.disconnect"});

            await websocket_forward(
                client,
                base,
                {
                    "Authorization": "Bearer t",
                    "Cookie": "drop=me",
                    "X-Forwarded-For": "10.0.0.1"
                }
            );
            return {
                "sent": client.sent,
                "closed": client.closed,
                "upstream_headers": {
                    k.lower(): v for (k, v) in upstream_headers[0].items()
                }
            };
        } finally {
            stop_upstream();
        }
    }
    result = _run(body());
    sent = result["sent"];
    texts = [
        v
        for (t, v) in sent
        if t == "text"
    ];
    byte_msgs = [
        v
        for (t, v) in sent
        if t == "bytes"
    ];

    assert "hello" in texts;
    assert "bye" in texts;
    assert b"\x00\x01\x02" in byte_msgs;
    assert result["closed"] == True;

    seen = result["upstream_headers"];
    assert seen["x-forwarded-for"] == "10.0.0.1, 203.0.113.9";
    assert seen["authorization"] == "Bearer t";
    assert "cookie" not in seen;
}


test "websocket_forward closes the client with 1011 when the upstream handshake fails" {
    async def body -> dict {
        client = FakeClientWS(inbound=asyncio.Queue(), sent=[]);
        await websocket_forward(client, "http://127.0.0.1:1/ws", {});
        return {"closed": client.closed, "code": client.close_code};
    }
    result = _run(body());
    assert result["closed"] == True;
    assert result["code"] == 1011;
}


"""Upstream that selects a subprotocol, the way vite's HMR server does."""
def _spawn_ws_upstream_with_protocol(protocol: str) -> tuple[any, any, str] {
    import from jaclang.server.serving.app { ServingApp }
    import from jaclang.server.serving.endpoint { WSEndPoint }
    import from jaclang.server.serving.server { ServingServer }

    async def ws_echo(ws: any) {
        offered: str = str(ws.headers.get("sec-websocket-protocol") or "");
        await ws.accept(subprotocol=protocol if protocol in offered else "");
        while True {
            msg = await ws.receive();
            if msg["type"] == "websocket.disconnect" {
                break;
            }
            if "text" in msg {
                await ws.send_text(msg["text"]);
                break;
            }
        }
    }
    app = ServingApp();
    app.add_ws_endpoint(WSEndPoint(path="/ws", handler=ws_echo));
    server = ServingServer(app=app, host="127.0.0.1", port=0);
    stop = server.serve_background();
    return (stop, server, f"http://127.0.0.1:{server.bound_port}/ws");
}


test "the client is accepted once, after the upstream chose the subprotocol" {
    async def body -> dict {
        (stop_upstream, server, base) = _spawn_ws_upstream_with_protocol("vite-hmr");
        try {
            client = FakeClientWS(
                inbound=asyncio.Queue(), sent=[], accepts=[], client_host="127.0.0.1"
            );
            client.inbound.put_nowait({"type": "websocket.receive", "text": "ping"});
            client.inbound.put_nowait({"type": "websocket.disconnect"});

            chosen: list[str] = [];

            async def on_upstream(selected: str) {
                chosen.append(selected);
                await client.accept(subprotocol=selected);
            }
            await websocket_forward(
                client,
                base,
                {"Sec-WebSocket-Protocol": "vite-hmr"},
                on_upstream=on_upstream
            );
            return {"accepts": client.accepts, "chosen": chosen};
        } finally {
            server.request_stop();
        }
    }
    out = asyncio.run(body());
    assert out["chosen"] == ["vite-hmr"] , (
        f"the forwarder must report what the upstream selected; got {out['chosen']}"
    );
    assert out["accepts"] == ["vite-hmr"] , (
        f"the client is accepted exactly once, with the upstream's protocol - "
        f"answering 101 before the upstream handshake is what made a browser "
        f"tear the socket down and reconnect in a loop; got {out['accepts']}"
    );
}


test "a failed upstream handshake never accepts the client" {
    async def body -> dict {
        client = FakeClientWS(
            inbound=asyncio.Queue(), sent=[], accepts=[], client_host="127.0.0.1"
        );
        accepted: list[str] = [];

        async def on_upstream(selected: str) {
            accepted.append(selected);
        }
        await websocket_forward(
            client, "http://127.0.0.1:1/ws", {}, on_upstream=on_upstream
        );
        return {"accepted": accepted, "closed": client.closed};
    }
    out = asyncio.run(body());
    assert out["accepted"] == [] , (
        "no upstream means nothing to proxy; the client must not be handed a 101"
    );
    assert out["closed"];
}
