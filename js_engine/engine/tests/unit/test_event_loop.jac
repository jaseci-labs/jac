import from engine.src.vm.event_loop {
    EventLoop,
    el_create,
    el_tick,
    uvloop_run_default,
    uvloop_run_nowait,
    uvloop_close,
    uvloop_alive,
    uvasync_close
}

with entry {
    print("OK event_loop module loads");

    # ── 1. Create a fresh EventLoop ──────────────────────────────────────────
    test_el: EventLoop = el_create();

    if test_el.loop.loop_ptr == 0 {
        print("FAIL loop_ptr is 0");
    } else {
        print("OK loop_ptr allocated: " + str(test_el.loop.loop_ptr));
    }

    if test_el.async_hdl.handle_ptr == 0 {
        print("FAIL async_hdl.handle_ptr is 0");
    } else {
        print(
            "OK async_hdl.handle_ptr allocated: " + str(test_el.async_hdl.handle_ptr)
        );
    }

    # ── 2. Run the loop ───────────────────────────────────────────────────────
    # The async handle is unreffed so there are no active reffed handles.
    # uv_run(UV_RUN_DEFAULT=0) must return immediately with exit code 0.
    rc: int = uvloop_run_default(test_el.loop);
    print("OK uv_run returned: " + str(rc));

    # ── 3. Verify the loop is no longer alive ────────────────────────────────
    alive: int = uvloop_alive(test_el.loop);
    if alive != 0 {
        print("FAIL loop unexpectedly alive after run: " + str(alive));
    } else {
        print("OK loop not alive after run");
    }

    # ── 4. Close the loop cleanly ────────────────────────────────────────────
    uvasync_close(test_el.async_hdl);
    uvloop_run_nowait(test_el.loop);  # drain close callback
    rc2: int = uvloop_close(test_el.loop);
    if rc2 != 0 {
        print("FAIL uvloop_close returned error: " + str(rc2));
    } else {
        print("OK loop closed cleanly");
    }

    # ── 5. Verify tick counter starts at zero ────────────────────────────────
    test_el2: EventLoop = el_create();
    if test_el2.tick_count != 0 {
        print("FAIL tick_count should be 0, got: " + str(test_el2.tick_count));
    } else {
        print("OK tick_count initialised to 0");
    }
    uvasync_close(test_el2.async_hdl);
    uvloop_run_nowait(test_el2.loop);
    uvloop_close(test_el2.loop);

    print("OK event loop runs and closes");
}
