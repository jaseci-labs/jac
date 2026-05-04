"""Unit tests for the microservices drain module (ROADMAP P13)."""

import asyncio;
import json;
import time;
import threading;
import from jac_scale.microservices._drain {
    is_draining,
    inflight,
    start_drain,
    incr_inflight,
    decr_inflight,
    wait_for_zero,
    reset_drain,
    drain_timeout_s,
    build_drain_middleware,
    install_signal_drain
}


test "initial state is not draining and inflight is zero" {
    reset_drain();
    assert not is_draining();
    assert inflight() == 0;
}


test "start_drain flips is_draining True" {
    reset_drain();
    assert not is_draining();
    start_drain(5.0);
    assert is_draining();
    reset_drain();
}


test "start_drain is idempotent; second call preserves original timeout" {
    reset_drain();
    start_drain(7.0);
    start_drain(99.0);
    assert is_draining();
    assert drain_timeout_s() == 7.0;
    reset_drain();
}


test "inflight counter increments and decrements" {
    reset_drain();
    assert inflight() == 0;
    incr_inflight();
    incr_inflight();
    assert inflight() == 2;
    decr_inflight();
    assert inflight() == 1;
    decr_inflight();
    assert inflight() == 0;
    reset_drain();
}


test "inflight cannot go negative" {
    reset_drain();
    decr_inflight();
    decr_inflight();
    assert inflight() == 0;
    reset_drain();
}


test "wait_for_zero returns True when already zero" {
    reset_drain();
    assert wait_for_zero(0.5);
}


test "wait_for_zero unblocks when inflight drops in another thread" {
    reset_drain();
    incr_inflight();

    def dropper -> None {
        time.sleep(0.05);
        decr_inflight();
    }

    t = threading.Thread(target=dropper);
    t.start();
    t0 = time.time();
    ok = wait_for_zero(1.0);
    elapsed = time.time() - t0;
    t.join();
    assert ok;
    assert elapsed < 0.5;
    reset_drain();
}


test "wait_for_zero times out when inflight stays stuck" {
    reset_drain();
    incr_inflight();
    t0 = time.time();
    ok = wait_for_zero(0.1);
    elapsed = time.time() - t0;
    assert not ok;
    assert elapsed >= 0.1;
    reset_drain();
}


"""Drive an async function from a sync test."""
def _run_async(coro: object) -> object {
    loop = asyncio.new_event_loop();
    try {
        return loop.run_until_complete(coro);
    } finally {
        loop.close();
    }
}


test "middleware passes through when not draining and tracks inflight=0 after" {
    reset_drain();
    mw = build_drain_middleware("test_svc");
    called: dict[str, int] = {"n": 0};

    async def next_handler(req: object) -> object {
        import from fastapi.responses { JSONResponse }
        called["n"] += 1;
        return JSONResponse(status_code=200, content={"ok": True});
    }

    resp = _run_async(mw(object(), next_handler));
    assert called["n"] == 1;
    assert getattr(resp, "status_code") == 200;
    assert inflight() == 0;
    reset_drain();
}


test "middleware returns 503 with Retry-After + envelope when draining" {
    reset_drain();
    mw = build_drain_middleware("cart_app");
    start_drain(10.0);

    async def next_handler(req: object) -> object {
        raise AssertionError("next_handler should not run during drain");
    }

    resp = _run_async(mw(object(), next_handler));
    assert getattr(resp, "status_code") == 503;
    headers = getattr(resp, "headers");
    assert headers.get("Retry-After") == "2";

    raw_body: bytes = bytes(getattr(resp, "body"));
    body: dict = json.loads(raw_body.decode());
    assert body["ok"] == False;
    err: dict = body["error"];
    assert err["code"] == "SERVICE_UNAVAILABLE";
    assert err["service"] == "cart_app";
    msg: str = err["message"];
    assert "draining" in msg;
    reset_drain();
}


test "middleware accounts inflight across concurrent in-flight requests" {
    reset_drain();
    mw = build_drain_middleware("svc");
    observed: list[int] = [];

    async def next_handler(req: object) -> object {
        import from fastapi.responses { JSONResponse }
        observed.append(inflight());
        return JSONResponse(status_code=200, content={"ok": True});
    }

    async def go -> None {
        await asyncio.gather(
            mw(object(), next_handler),
            mw(object(), next_handler),
            mw(object(), next_handler)
        );
    }

    _run_async(go());
    assert inflight() == 0;
    assert any(o >= 1 for o in observed);
    reset_drain();
}


test "middleware decrements inflight even when handler raises" {
    reset_drain();
    mw = build_drain_middleware("svc");

    async def bad_handler(req: object) -> object {
        raise RuntimeError("boom");
    }

    raised = False;
    try {
        _run_async(mw(object(), bad_handler));
    } except RuntimeError {
        raised = True;
    }
    assert raised;
    assert inflight() == 0;
    reset_drain();
}


obj _FakeServer {
    has handle_exit_calls: list = [];

    def handle_exit(sig: object, frame: object) -> None {
        self.handle_exit_calls.append((sig, frame));
    }
}


test "install_signal_drain wraps handle_exit and configures drain timeout" {
    reset_drain();
    srv = _FakeServer();
    orig = srv.handle_exit;
    install_signal_drain(srv, timeout_s=3.0);
    assert srv.handle_exit is not orig;
    assert drain_timeout_s() == 3.0;
    reset_drain();
}


test "wrapped handle_exit starts drain then calls original" {
    reset_drain();
    srv = _FakeServer();
    install_signal_drain(srv, timeout_s=2.0);
    assert not is_draining();

    srv.handle_exit(15, None);
    assert is_draining();
    assert len(srv.handle_exit_calls) == 1;
    assert srv.handle_exit_calls[0] == (15, None);
    reset_drain();
}
