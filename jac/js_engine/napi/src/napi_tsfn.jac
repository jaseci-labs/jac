"""TSFN (Threadsafe Function) bridge — Jac-side implementation.

Only imports from "libjs_native.so" (the C shim).  No engine modules, no libuv FFI
imports here — mixing those with shim FFI imports poisons the Jac type
checker for any file that transitively imports this module.

event_loop.na.jac calls tsfn_init(loop_ptr) after el_create() and calls
tsfn_drain_all() inside el_tick().
"""

import from "libjs_native.so" {
    # argv read helpers
    def _napi_tsfn_read_argv2(argv: int) -> None;  def _napi_tsfn_scratch0 -> int;  def _napi_tsfn_scratch1 -> int;
    # result slot (avoids Unknown return-type cross-module issue)
    def _napi_tsfn_set_result(v: int) -> None;  def _napi_tsfn_result -> int;
    # ring-buffer / registry
    def _napi_tsfn_get_js_func(tsfn_ptr: int) -> int;  def _napi_tsfn_get_context(
        tsfn_ptr: int
    ) -> int;  def _napi_tsfn_get_env(tsfn_ptr: int) -> int;  def _napi_tsfn_get_call_js_cb(
        tsfn_ptr: int
    ) -> int;  def _napi_tsfn_pop_slot(tsfn_ptr: int) -> int;  def _napi_invoke_tsfn_cb(
        cb: int, env: int, fn: int, ctx: int, data: int
    ) -> None;  def _napi_tsfn_destroy(tsfn_ptr: int) -> None;  def _napi_tsfn_registry_count -> int;  def _napi_tsfn_registry_get(
        idx: int
    ) -> int;  def _napi_tsfn_has_pending(tsfn_ptr: int) -> int;  def _napi_tsfn_set_drain_handle(
        handle_ptr: int
    ) -> None;  def _napi_tsfn_hold_count -> int;
    # libuv wrappers (no direct libuv FFI import here)
    def _napi_uv_async_create(loop_ptr: int, cb_ptr: int) -> int;  def _napi_uv_ref(
        handle_ptr: int
    ) -> None;  def _napi_uv_unref(handle_ptr: int) -> None;  def _napi_uv_async_close(
        handle_ptr: int
    ) -> None;  def _napi_tsfn_store_loop(loop_ptr: int) -> None;  def _napi_tsfn_get_loop -> int;
}

# Op constants — inlined to avoid importing napi_ops (which poisons types).
glob _OP_CREATE: int = 134,
     _OP_CALL: int = 136,
     _OP_ACQUIRE: int = 137,
     _OP_RELEASE: int = 138,
     _OP_REF: int = 139,
     _OP_UNREF: int = 140,
     _NAPI_OK: int = 0,
     _NAPI_FAIL: int = 9;

# ── Module state ───────────────────────────────────────────────────────────────

glob:pub _TSFN_DRAIN_HDL_PTR: int = 0,
     _TSFN_DRAIN_INIT: bool = False,
     _TSFN_LIVE_COUNT: int = 0,
     _TSFN_REF_COUNT: int = 0;

# Counts live TSFNs (thread_count > 0); drain handle stays reffed while > 0.

# Counts explicitly reffed TSFNs; separate from live count.
# ── C callback ─────────────────────────────────────────────────────────────────

def:pub _tsfn_drain_cb(handle: int) {
    tsfn_drain_all();
}

# ── Init ───────────────────────────────────────────────────────────────────────

def:pub tsfn_init(loop_ptr: int) {
    _napi_tsfn_store_loop(loop_ptr);
}

# ── Helpers ────────────────────────────────────────────────────────────────────

def _ensure_drain_handle {
    if not _TSFN_DRAIN_INIT {
        lp: int = _napi_tsfn_get_loop();
        ptr: int = _napi_uv_async_create(lp, _tsfn_drain_cb);
        _napi_uv_unref(ptr);
        _TSFN_DRAIN_HDL_PTR = ptr;
        _napi_tsfn_set_drain_handle(ptr);
        _TSFN_DRAIN_INIT = True;
    }
}

# True while the drain handle is uv_ref'd (loop-holding).
glob _TSFN_HELD: bool = False;

# Ref the drain handle only while at least one LIVE **and REFFED** TSFN
# exists (C-side _napi_tsfn_hold_count consults the per-TSFN ref/thread
# counters).  Node semantics: napi_unref_threadsafe_function marks a TSFN
# as not-loop-holding — napi-rs's CustomGC TSFN is created then immediately
# unref'd, and treating unref as a no-op held the loop open forever (the
# rollup/vite "process never exits naturally" tail).
def _tsfn_sync_keepalive {
    if _TSFN_DRAIN_HDL_PTR == 0 {
        return;
    }
    want: bool = _napi_tsfn_hold_count() > 0;
    if want and not _TSFN_HELD {
        _napi_uv_ref(_TSFN_DRAIN_HDL_PTR);
        _TSFN_HELD = True;
    } elif not want and _TSFN_HELD {
        _napi_uv_unref(_TSFN_DRAIN_HDL_PTR);
        _TSFN_HELD = False;
    }
}

def _tsfn_acquire_live {
    _ensure_drain_handle();
    _TSFN_LIVE_COUNT = _TSFN_LIVE_COUNT + 1;
    _tsfn_sync_keepalive();
}

def _tsfn_release_live {
    if _TSFN_LIVE_COUNT > 0 {
        _TSFN_LIVE_COUNT = _TSFN_LIVE_COUNT - 1;
        if _TSFN_LIVE_COUNT == 0 {
            # Close the drain handle so libuv does not warn about unclosed
            # handles at process exit.  uv_close implies uv_unref.
            _napi_uv_async_close(_TSFN_DRAIN_HDL_PTR);
            _TSFN_DRAIN_HDL_PTR = 0;
            _TSFN_DRAIN_INIT = False;
            _TSFN_HELD = False;
        } else {
            _tsfn_sync_keepalive();
        }
    }
}

# ── Drain ──────────────────────────────────────────────────────────────────────

def:pub tsfn_drain_all {
    n: int = _napi_tsfn_registry_count();
    i: int = 0;
    while i < n {
        tptr: int = _napi_tsfn_registry_get(i);
        i = i + 1;
        if tptr == 0 {
            continue;
        }
        jfn: int = _napi_tsfn_get_js_func(tptr);
        env: int = _napi_tsfn_get_env(tptr);
        ctx: int = _napi_tsfn_get_context(tptr);
        cb: int = _napi_tsfn_get_call_js_cb(tptr);
        # Drain until empty.
        while _napi_tsfn_has_pending(tptr) > 0 {
            dat: int = _napi_tsfn_pop_slot(tptr);
            if cb != 0 {
                _napi_invoke_tsfn_cb(cb, env, jfn, ctx, dat);
            }
        }
    }
}

# ── Dispatch ───────────────────────────────────────────────────────────────────
# Returns result via _napi_tsfn_result() slot to sidestep the Unknown-return
# cross-module type issue.  Callers: read the slot after calling tsfn_dispatch.

def:pub tsfn_dispatch(op: int, argv: int) {
    if op == _OP_CREATE {
        # A new live TSFN — keep drain handle reffed.
        _tsfn_acquire_live();
        _napi_tsfn_set_result(_NAPI_OK);
    } elif op == _OP_CALL {
        _napi_tsfn_set_result(_NAPI_OK);
    } elif op == _OP_ACQUIRE {
        # Additional thread acquired the TSFN — bump live count.
        _tsfn_acquire_live();
        _napi_tsfn_set_result(_NAPI_OK);
    } elif op == _OP_RELEASE {
        # argv2: [tsfn_ptr, should_close]
        _napi_tsfn_read_argv2(argv);
        _tsfn_release_live();
        if _napi_tsfn_scratch1() != 0 {
            _napi_tsfn_destroy(_napi_tsfn_scratch0());
        }
        _napi_tsfn_set_result(_NAPI_OK);
    } elif op == _OP_REF {
        # The C shim already adjusted t->ref before dispatching — just
        # resync the drain-handle keepalive against the new hold count.
        _tsfn_sync_keepalive();
        _napi_tsfn_set_result(_NAPI_OK);
    } elif op == _OP_UNREF {
        _tsfn_sync_keepalive();
        _napi_tsfn_set_result(_NAPI_OK);
    } else {
        _napi_tsfn_set_result(_NAPI_FAIL);
    }
}
