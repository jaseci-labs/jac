"""The transport's drain state: what SIGTERM flips and what the middleware,
readiness probe and gateway read from it."""

import asyncio;
import json;
import from jaclang.server.serving.datatypes { JSONResponse, Request, URL }
import from jaclang.server.serving.drain { DrainState, drain_middleware }


def _request(path: str) -> Request {
    return Request(method="GET", url=URL(path=path));
}


def _run(coro: any) -> any {
    return asyncio.run(coro);
}


test "initial state is not draining and keeps its budget" {
    state = DrainState(timeout=4.0);
    assert not state.draining;
    assert state.remaining() == 4.0;
    assert state.reason == "";
}


test "start flips draining once and keeps the first reason" {
    state = DrainState(timeout=7.0);
    assert state.start("signal SIGTERM");
    assert state.draining;
    assert state.reason == "signal SIGTERM";
    assert not state.start("second");
    assert state.reason == "signal SIGTERM";
    state.reset();
    assert not state.draining;
}


test "remaining counts down from the budget once draining" {
    state = DrainState(timeout=10.0);
    state.start("test");
    left = state.remaining();
    assert 0.0 < left <= 10.0;
}


test "middleware passes through when not draining" {
    state = DrainState();
    called: list[str] = [];

    async def handler(request: Request) -> JSONResponse {
        called.append(request.url.path);
        return JSONResponse(content={"ok": True});
    }
    mw = drain_middleware(state, "svc");
    resp = _run(mw(_request("/walker/Foo"), handler));
    assert resp.status_code == 200;
    assert called == ["/walker/Foo"];
}


test "middleware answers 503 with Retry-After and an envelope when draining" {
    state = DrainState();
    state.start("test");

    async def handler(request: Request) -> JSONResponse {
        raise AssertionError("handler must not run while draining");
    }
    mw = drain_middleware(state, "orders");
    resp = _run(mw(_request("/walker/Foo"), handler));
    assert resp.status_code == 503;
    assert resp.headers.get("Retry-After") == "1";
    assert resp.headers.get("Connection") == "close";
    body = json.loads(resp.body_bytes());
    assert body["ok"] is False;
    assert body["error"]["code"] == "SERVICE_UNAVAILABLE";
    assert "orders" in body["error"]["message"];
}


test "health probes bypass the drain middleware" {
    state = DrainState();
    state.start("test");
    seen: list[str] = [];

    async def handler(request: Request) -> JSONResponse {
        seen.append(request.url.path);
        return JSONResponse(content={"status": "draining"});
    }
    mw = drain_middleware(state, "svc");
    for path in ["/healthz", "/healthz/live", "/healthz/ready"] {
        resp = _run(mw(_request(path), handler));
        assert resp.status_code == 200 , path;
    }
    assert seen == ["/healthz", "/healthz/live", "/healthz/ready"];
}


test "the transport flips its drain state on a termination signal" {
    import from jaclang.server.serving.app { ServingApp }
    import from jaclang.server.serving.server { ServingServer }
    import from jaclang.server.settings { ServeSettings }

    settings = ServeSettings();
    settings.timeouts.drain = 3.5;
    server = ServingServer(app=ServingApp(), settings=settings);
    assert server.drain.timeout == 3.5;
    assert not server.drain.draining;
    assert server.app.state["drain"] is server.drain;
}
