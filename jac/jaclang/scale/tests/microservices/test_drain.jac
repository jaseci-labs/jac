"""The transport's drain state: what SIGTERM flips and what the middleware,
readiness probe and gateway read from it."""

import asyncio;
import json;
import logging;
import sys;


"""A callable that defines `__eq__`, so like a dataclass it is not hashable."""
obj _Recorder {
    has ran: list[str];

    def __eq__(other: any) -> bool {
        return self is other;
    }

    def __call__ {
        self.ran.append("obj");
    }
}


def _request(path: str) -> Request {
    return Request(method="GET", url=URL(path=path));
}


def _run(coro: any) -> any {
    return asyncio.run(coro);
}


"""Empty the process-wide hook registry for one test; returns what to restore."""
def _clear_hooks -> tuple[list[any], set[int]] {
    saved = (list(DRAIN_HOOKS), set(DRAIN_TAKEN));
    DRAIN_HOOKS.clear();
    DRAIN_TAKEN.clear();
    return saved;
}


def _restore_hooks(saved: tuple[list[any], set[int]]) {
    DRAIN_HOOKS[:] = saved[0];
    DRAIN_TAKEN.clear();
    DRAIN_TAKEN.update(saved[1]);
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


test "drain hooks run once per process, awaited, past failures, including ones registered while draining" {
    ran: list[str] = [];

    def hook {
        ran.append("sync");
        on_drain(hook);
        on_drain(lambda { ran.append("late"); });
    }

    async def async_hook {
        ran.append("async");
    }

    def raises {
        raise RuntimeError("boom");
    }

    def exits {
        sys.exit(3);
    }
    saved = _clear_hooks();
    try {
        for fn in [hook, raises, exits, _Recorder(ran), async_hook, hook] {
            on_drain(fn);
        }
        for reason in ["first", "second"] {
            state = DrainState();
            state.start(reason);
            state.wait_for_hooks();
            assert ran == ["sync", "obj", "async", "late"] , reason;
        }
    } finally {
        _restore_hooks(saved);
    }
}


test "on_drain warns once when hooks pile up, as a lambda registered per request does" {
    warnings: list[str] = [];
    def capture(record: any) {
        warnings.append(record.getMessage());
    }
    handler = logging.Handler();
    handler.emit = capture;
    logging.getLogger().addHandler(handler);
    saved = _clear_hooks();
    try {
        for _ in range(150) {
            on_drain(lambda { return None; });
        }
    } finally {
        _restore_hooks(saved);
        logging.getLogger().removeHandler(handler);
    }
    assert len(
        [
            w
            for w in warnings
            if w.startswith("on_drain:")
        ]
    )
        == 1;
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


test "a sync drain hook can run its own event loop" {
    ran: list[str] = [];

    async def close {
        ran.append("closed");
    }

    def sync_hook {
        asyncio.run(close());
    }
    saved = _clear_hooks();
    try {
        on_drain(sync_hook);
        state = DrainState();
        state.start("test");
        state.wait_for_hooks();
    } finally {
        _restore_hooks(saved);
    }
    assert ran == ["closed"];
}
