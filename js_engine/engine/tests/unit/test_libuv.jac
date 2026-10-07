import from engine.src.ffi.libuv {
    UVLoop,
    UVHandle,
    uvloop_create,
    uvloop_run_default,
    uvloop_run_once,
    uvloop_run_nowait,
    uvloop_stop,
    uvloop_close,
    uvloop_alive,
    uvloop_default,
    uvtimer_create,
    uvtimer_start,
    uvtimer_stop,
    uvtimer_close,
    uv_timer_size,
    uv_async_size,
    uvasync_create,
    uvasync_send,
    uvasync_close
}

glob _smoke_fires: int = 0,
     _smoke_stop_fires: int = 0,
     _smoke_stop_loop: UVLoop = UVLoop(),
     _smoke_async_fires: int = 0;

# These are handed to libuv as raw C function pointers (`cb: int`). Engine
# modules are pinned native and get that coercion implicitly; this test module
# is not, so each call site carries `# jac:ignore[E1053]`.
def _smoke_timer_cb(handle: int) {
    _smoke_fires = _smoke_fires + 1;
}

def _smoke_stop_cb(handle: int) {
    _smoke_stop_fires = _smoke_stop_fires + 1;
    uvloop_stop(_smoke_stop_loop);
}

def _smoke_async_cb(handle: int) {
    _smoke_async_fires = _smoke_async_fires + 1;
}

with entry {
    ok: int = 0;
    err: int = 0;

    # 1 — loop create
    lp: UVLoop = uvloop_create();
    if lp.loop_ptr != 0 {
        print("OK  uvloop_create ptr =", lp.loop_ptr);
        ok = ok + 1;
    } else {
        print("FAIL  uvloop_create returned null");
        err = err + 1;
    }

    # 2 — uv_timer_size
    tsz: int = uv_timer_size();
    if tsz > 0 {
        print("OK  uv_timer_size =", tsz);
        ok = ok + 1;
    } else {
        print("FAIL  uv_timer_size =", tsz);
        err = err + 1;
    }

    # 3 — uv_async_size
    asz: int = uv_async_size();
    if asz > 0 {
        print("OK  uv_async_size =", asz);
        ok = ok + 1;
    } else {
        print("FAIL  uv_async_size =", asz);
        err = err + 1;
    }

    # 4 — loop has no active handles yet
    alive: int = uvloop_alive(lp);
    if alive == 0 {
        print("OK  uvloop_alive = 0 (no handles)");
        ok = ok + 1;
    } else {
        print("FAIL  uvloop_alive =", alive, "(expected 0)");
        err = err + 1;
    }

    # 5 — run NOWAIT on empty loop returns 0
    rc_nw: int = uvloop_run_nowait(lp);
    if rc_nw == 0 {
        print("OK  uvloop_run_nowait (empty) rc =", rc_nw);
        ok = ok + 1;
    } else {
        print("FAIL  uvloop_run_nowait rc =", rc_nw);
        err = err + 1;
    }

    # 6 — create timer
    timer: UVHandle = uvtimer_create(lp);
    if timer.handle_ptr != 0 {
        print("OK  uvtimer_create ptr =", timer.handle_ptr);
        ok = ok + 1;
    } else {
        print("FAIL  uvtimer_create returned null");
        err = err + 1;
    }

    # 7 — start timer (one-shot, fires immediately on next loop iteration)
    rc_ts: int = uvtimer_start(timer, _smoke_timer_cb, 0, 0);  # jac:ignore[E1053]
    if rc_ts == 0 {
        print("OK  uvtimer_start rc =", rc_ts);
        ok = ok + 1;
    } else {
        print("FAIL  uvtimer_start rc =", rc_ts);
        err = err + 1;
    }

    # 8 — run loop once to fire the timer
    uvloop_run_once(lp);
    if _smoke_fires == 1 {
        print("OK  timer callback fired");
        ok = ok + 1;
    } else {
        print("FAIL  timer callback fired", _smoke_fires, "time(s) (expected 1)");
        err = err + 1;
    }

    # 9 — close timer and drain close callbacks
    uvtimer_close(timer);
    uvloop_run_once(lp);

    # 10 — close loop
    rc_lc: int = uvloop_close(lp);
    if rc_lc == 0 {
        print("OK  uvloop_close rc =", rc_lc);
        ok = ok + 1;
    } else {
        print("FAIL  uvloop_close rc =", rc_lc, "(handles still open?)");
        err = err + 1;
    }

    # 11 — uvtimer_stop standalone (stop without closing)
    lp2: UVLoop = uvloop_create();
    timer2: UVHandle = uvtimer_create(lp2);
    uvtimer_start(timer2, _smoke_timer_cb, 0, 1);  # repeat=1ms — would run forever  # jac:ignore[E1053]
    rc_tstop: int = uvtimer_stop(timer2);
    uvloop_run_nowait(lp2);  # drain — callback must NOT fire
    if rc_tstop == 0 {
        print("OK  uvtimer_stop standalone rc =", rc_tstop);
        ok = ok + 1;
    } else {
        print("FAIL  uvtimer_stop rc =", rc_tstop);
        err = err + 1;
    }
    uvtimer_close(timer2);
    uvloop_run_once(lp2);
    uvloop_close(lp2);

    # 12 — uv_default_loop
    dlp: int = uvloop_default();
    if dlp != 0 {
        print("OK  uv_default_loop ptr =", dlp);
        ok = ok + 1;
    } else {
        print("FAIL  uv_default_loop returned null");
        err = err + 1;
    }

    # 13 — uvloop_run_default (one-shot timer; loop exits when no active handles remain)
    lp3: UVLoop = uvloop_create();
    timer3: UVHandle = uvtimer_create(lp3);
    uvtimer_start(timer3, _smoke_timer_cb, 0, 0);  # one-shot, timeout=0  # jac:ignore[E1053]
    uvloop_run_default(lp3);  # blocks until timer fires and loop empties
    uvtimer_close(timer3);
    uvloop_run_once(lp3);
    rc_lc3: int = uvloop_close(lp3);
    if rc_lc3 == 0 {
        print("OK  uvloop_run_default completed, close rc =", rc_lc3);
        ok = ok + 1;
    } else {
        print("FAIL  uvloop_run_default: close rc =", rc_lc3);
        err = err + 1;
    }

    # 14 — uvloop_stop (repeating timer stops the loop from inside callback)
    lp4: UVLoop = uvloop_create();
    _smoke_stop_loop = lp4;
    timer4: UVHandle = uvtimer_create(lp4);
    uvtimer_start(timer4, _smoke_stop_cb, 0, 1);  # fires immediately, then every 1ms  # jac:ignore[E1053]
    uvloop_run_default(lp4);  # callback calls uv_stop → returns
    if _smoke_stop_fires >= 1 {
        print("OK  uvloop_stop: loop exited by callback, fires =", _smoke_stop_fires);
        ok = ok + 1;
    } else {
        print("FAIL  uvloop_stop: callback never fired");
        err = err + 1;
    }
    uvtimer_close(timer4);
    uvloop_run_once(lp4);
    uvloop_close(lp4);

    # 15 — uvasync_create
    lp5: UVLoop = uvloop_create();
    async1: UVHandle = uvasync_create(lp5, _smoke_async_cb);  # jac:ignore[E1053]
    if async1.handle_ptr != 0 {
        print("OK  uvasync_create ptr =", async1.handle_ptr);
        ok = ok + 1;
    } else {
        print("FAIL  uvasync_create returned null");
        err = err + 1;
    }

    # 16 — uvasync_send + callback fires
    rc_as: int = uvasync_send(async1);
    uvloop_run_once(lp5);
    if _smoke_async_fires == 1 {
        print("OK  uvasync_send: callback fired");
        ok = ok + 1;
    } else {
        print("FAIL  uvasync_send: fires =", _smoke_async_fires, "(expected 1)");
        err = err + 1;
    }

    # 17 — uvasync_close
    uvasync_close(async1);
    uvloop_run_once(lp5);
    rc_lc5: int = uvloop_close(lp5);
    if rc_lc5 == 0 {
        print("OK  uvasync_close: loop closed rc =", rc_lc5);
        ok = ok + 1;
    } else {
        print("FAIL  uvasync_close: loop close rc =", rc_lc5);
        err = err + 1;
    }

    print("libuv smoke:", ok, "passed,", err, "failed");
}
