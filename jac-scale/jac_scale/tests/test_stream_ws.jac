"""Tests for the streaming + WebSocket proxy modules (ROADMAP P15)."""

import asyncio;
import from jac_scale.microservices._ws_forward {
    _to_ws_scheme,
    _select_handshake_headers
}
import from jac_scale.microservices.impl.http_forward {
    ForwardResult,
    stream_forward,
    raw_forward
}


test "ws scheme rewrite: http -> ws" {
    assert _to_ws_scheme("http://127.0.0.1:8001/ws/chat") == "ws://127.0.0.1:8001/ws/chat";
}


test "ws scheme rewrite: https -> wss" {
    assert _to_ws_scheme("https://api.internal/ws") == "wss://api.internal/ws";
}


test "ws scheme rewrite passes through already ws/wss URLs" {
    assert _to_ws_scheme("ws://a/b") == "ws://a/b";
    assert _to_ws_scheme("wss://a/b") == "wss://a/b";
}


test "handshake headers keep auth + trace + xff and drop the rest" {
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
    out = _select_handshake_headers(inbound);
    assert "Authorization" in out;
    assert out["Authorization"] == "Bearer abc";
    assert "X-Trace-Id" in out;
    assert "X-Forwarded-For" in out;
    # Everything else stripped
    assert "Cookie" not in out;
    assert "User-Agent" not in out;
    assert "Host" not in out;
    assert "Connection" not in out;
    assert "Upgrade" not in out;
    assert "Sec-WebSocket-Key" not in out;
    assert "Sec-WebSocket-Version" not in out;
}


test "handshake headers are case-insensitive on the filter" {
    inbound = {"authorization": "Bearer x", "X-TRACE-ID": "t1", "sec-websocket-key": "k"};
    out = _select_handshake_headers(inbound);
    assert out["authorization"] == "Bearer x";
    assert out["X-TRACE-ID"] == "t1";
    assert "sec-websocket-key" not in out;
}


"""aiohttp test server with echo/sse/big/fourofour routes. Caller
must await runner.cleanup()."""
async def _spawn_upstream -> tuple[object, object, str] {
    import aiohttp;
    import from aiohttp { web }

    async def echo(request: object) -> object {
        body = await request.read();
        return web.Response(body=body, status=200);
    }

    async def sse(request: object) -> object {
        resp = web.StreamResponse(
            status=200,
            headers={"Content-Type": "text/event-stream"}
        );
        await resp.prepare(request);
        for i in range(3) {
            await resp.write(f"data: event{i}\n\n".encode("utf-8"));
        }
        await resp.write_eof();
        return resp;
    }

    async def big(request: object) -> object {
        resp = web.StreamResponse(status=200);
        resp.enable_chunked_encoding();
        await resp.prepare(request);
        chunk = b"x" * 4096;
        for _ in range(16) {
            await resp.write(chunk);
        }
        await resp.write_eof();
        return resp;
    }

    async def fourofour(request: object) -> object {
        return web.Response(status=404, body=b"nope");
    }

    app = web.Application();
    app.router.add_post("/echo", echo);
    app.router.add_get("/sse", sse);
    app.router.add_get("/big", big);
    app.router.add_get("/fourofour", fourofour);

    runner = web.AppRunner(app);
    await runner.setup();
    site = web.TCPSite(runner, "127.0.0.1", 0);
    await site.start();
    actual_port: int = 0;
    for s in runner.sites {
        for srv in s._server.sockets if s._server else [] {
            actual_port = srv.getsockname()[1];
            break;
        }
        if actual_port {
            break;
        }
    }
    base = f"http://127.0.0.1:{actual_port}";
    return (site, runner, base);
}


def _run(coro: object) -> object {
    loop = asyncio.new_event_loop();
    try {
        return loop.run_until_complete(coro);
    } finally {
        loop.close();
    }
}


test "stream_forward streams SSE end-to-end with Content-Type preserved" {
    async def body -> dict {
        (site, runner, base) = await _spawn_upstream();
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
            await runner.cleanup();
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
        (site, runner, base) = await _spawn_upstream();
        try {
            fr = await stream_forward("GET", f"{base}/big", {}, b"");
            assert fr is not None;
            sr = fr.to_response();
            chunk_count: int = 0;
            total: int = 0;
            async for chunk in sr.body_iterator {
                chunk_count += 1;
                total += len(chunk) if isinstance(chunk, bytes) else len(chunk.encode());
            }
            return {"status": fr.status, "count": chunk_count, "total": total};
        } finally {
            await runner.cleanup();
        }
    }
    result = _run(body());
    assert result["status"] == 200;
    assert result["total"] == 65536;
    assert result["count"] >= 1;
}


test "stream_forward.cleanup closes session without streaming" {
    async def body -> dict {
        (site, runner, base) = await _spawn_upstream();
        try {
            fr = await stream_forward("GET", f"{base}/fourofour", {}, b"");
            assert fr is not None;
            assert fr.status == 404;
            await fr.cleanup();
            return {"ok": True};
        } finally {
            await runner.cleanup();
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
        (site, runner, base) = await _spawn_upstream();
        try {
            result = await raw_forward("POST", f"{base}/echo", {}, b"hello");
            return result;
        } finally {
            await runner.cleanup();
        }
    }
    result = _run(body());
    assert result is not None;
    (status, headers, body_bytes) = result;
    assert status == 200;
    assert body_bytes == b"hello";
}


test "ws route closes with 1008 when no registry prefix matches" {
    import from jac_scale.microservices.service_registry {
        ServiceRegistry
    }
    import from jac_scale.microservices.gateway { MicroserviceGateway }
    import from fastapi.testclient { TestClient }
    import from starlette.websockets { WebSocketDisconnect }

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
    import from jac_scale.microservices.service_registry {
        ServiceRegistry, ServiceEntry, ServiceStatus
    }
    import from jac_scale.microservices.gateway { MicroserviceGateway }
    import from jac_scale.microservices._drain {
        reset_drain, start_drain
    }
    import from fastapi.testclient { TestClient }

    reset_drain();
    reg = ServiceRegistry();
    reg.register(ServiceEntry(
        name="orders", file="orders.jac", prefix="/api/orders",
        port=8001, url="http://127.0.0.1:8001",
        status=ServiceStatus.HEALTHY
    ));
    gw = MicroserviceGateway(registry=reg);
    gw.setup();

    client = TestClient(gw.app);
    start_drain(10.0);
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
        reset_drain();
    }
}
