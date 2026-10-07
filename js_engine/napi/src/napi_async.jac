"""NAPI async work (ops 125–128) — create/queue/cancel/delete_async_work.

Execution model (ROLLUP_SUPPORT_PLAN.md R2, single-threaded runtime):
`execute` runs SYNCHRONOUSLY on the JS thread inside napi_queue_async_work.
This is spec-compatible: NAPI forbids `execute` from touching the env or
any JS value (in Node it runs on a threadpool thread), so the only
observable difference is wall-clock timing.  `complete` is deferred: the
work is marked pending and drained by el_tick (event_loop.na.jac) BEFORE
that tick's microtask checkpoint, so `complete(env, napi_ok, data)` runs
asynchronously with respect to the JS that queued the work, and the
promise it settles has its reactions run in the same tick as the settle —
Node's ordering contract.

Loop keep-alive: while completes are pending, the ENGINE's wakeup handle
(el.async_hdl, injected via napi_async_init) is uv_ref'd and signalled via
uv_async_send, so uv_run neither parks indefinitely nor exits before the
drain.  The ref is dropped when the pending count returns to zero
(strictly balanced through _aw_keepalive).

Cancellation: by the time an addon can call napi_cancel_async_work the
execute callback has already run (it runs inside queue), which is exactly
Node's "already executing" case — cancel therefore always returns
napi_generic_failure and complete(napi_cancelled) is never delivered.

Errors: a complete callback that throws via napi_throw leaves the NAPI
pending-exception slot set; it surfaces at the next NAPI boundary.  (Node
raises an uncaught exception from the async callback scope — divergence
documented; nothing on rollup's path throws from complete.)

Import discipline (same as napi_tsfn.na.jac): shim-only imports — engine
or libuv FFI imports here poison the Jac type checker for importers.
"""

import from "lib/libnapi_shim.so" {
    def _napi_argv_i64(argv: int, idx: int) -> int;  def _napi_write_i64(
        p: int, v: int
    ) -> int;  def _napi_call_async_execute(cb: int, env: int, data: int) -> None;  def _napi_call_async_complete(
        cb: int, env: int, status: int, data: int
    ) -> None;  def _napi_uv_ref(handle_ptr: int) -> None;  def _napi_uv_unref(
        handle_ptr: int
    ) -> None;  def _napi_uv_async_send(handle_ptr: int) -> None;
}

# Status codes (napi_ok / napi_invalid_arg / napi_generic_failure) + op ids
# — inlined per the import discipline above; _AW_-prefixed because the Jac
# native link has a flat symbol namespace across modules (E5026).
glob _AW_OK: int = 0,
     _AW_EINVAL: int = 1,
     _AW_EFAIL: int = 9,
     _OP_CREATE_ASYNC_WORK: int = 125,
     _OP_DELETE_ASYNC_WORK: int = 126,
     _OP_QUEUE_ASYNC_WORK: int = 127,
     _OP_CANCEL_ASYNC_WORK: int = 128,
     _AW_CREATED: int = 0,
     _AW_PENDING_COMPLETE: int = 1,
     _AW_DONE: int = 2,
     _AW_DELETED: int = 3,
     _AW_ENV: list[int] = [],
     _AW_EXECUTE: list[int] = [],
     _AW_COMPLETE: list[int] = [],
     _AW_DATA: list[int] = [],
     _AW_STATE: list[int] = [],
     _AW_WAKEUP_HDL: int = 0,
     _AW_PENDING: int = 0,
     _AW_KEEPALIVE_ON: bool = False;

# Work lifecycle states.
# created, not yet queued
# execute ran; complete awaits drain
# complete delivered
# slot retired via delete_async_work

# Work records; handle = index + 1 (0 is the invalid handle).

# Engine wakeup handle (el.async_hdl.handle_ptr) + keep-alive bookkeeping.
"""Inject the engine event-loop wakeup handle (called once from el_run)."""
def:pub napi_async_init(wakeup_handle_ptr: int) {
    _AW_WAKEUP_HDL = wakeup_handle_ptr;
}

"""Ref the wakeup handle while completes are pending; unref when drained.
Strictly balanced: transitions only on state change."""
def _aw_keepalive(want: bool) {
    if _AW_WAKEUP_HDL == 0 {
        return;
    }
    if want and not _AW_KEEPALIVE_ON {
        _napi_uv_ref(_AW_WAKEUP_HDL);
        _AW_KEEPALIVE_ON = True;
    } elif not want and _AW_KEEPALIVE_ON {
        _napi_uv_unref(_AW_WAKEUP_HDL);
        _AW_KEEPALIVE_ON = False;
    }
}

def _aw_index(work_handle: int) -> int {
    if work_handle < 1 or work_handle > len(_AW_STATE) {
        return -1;
    }
    if _AW_STATE[work_handle - 1] == _AW_DELETED {
        return -1;
    }
    return work_handle - 1;
}

# ── Op 125 — napi_create_async_work ──────────────────────────────────────────
# argv: [env, async_resource, async_resource_name, execute, complete, data, result*]
def _h_create_async_work(argv: int) -> int {
    env: int = _napi_argv_i64(argv, 0);
    execute: int = _napi_argv_i64(argv, 3);
    complete: int = _napi_argv_i64(argv, 4);
    data: int = _napi_argv_i64(argv, 5);
    res_p: int = _napi_argv_i64(argv, 6);
    if execute == 0 or res_p == 0 {
        return _AW_EINVAL;
    }
    _AW_ENV.append(env);
    _AW_EXECUTE.append(execute);
    _AW_COMPLETE.append(complete);
    _AW_DATA.append(data);
    _AW_STATE.append(_AW_CREATED);
    _napi_write_i64(res_p, len(_AW_STATE));  # handle = index + 1
    return _AW_OK;
}

# ── Op 127 — napi_queue_async_work ───────────────────────────────────────────
# argv: [env, work]
def _h_queue_async_work(argv: int) -> int {
    i: int = _aw_index(_napi_argv_i64(argv, 1));
    if i < 0 {
        return _AW_EINVAL;
    }
    if _AW_STATE[i] != _AW_CREATED {
        return _AW_EFAIL;
    }  # double queue
    # Execute now (env-free CPU work by NAPI contract); defer complete to the
    # next el_tick drain so it is asynchronous w.r.t. the queueing JS.
    _napi_call_async_execute(_AW_EXECUTE[i], _AW_ENV[i], _AW_DATA[i]);
    _AW_STATE[i] = _AW_PENDING_COMPLETE;
    _AW_PENDING = _AW_PENDING + 1;
    _aw_keepalive(True);
    if _AW_WAKEUP_HDL != 0 {
        _napi_uv_async_send(_AW_WAKEUP_HDL);
    }
    return _AW_OK;
}

# ── Op 128 — napi_cancel_async_work ──────────────────────────────────────────
# argv: [env, work]
def _h_cancel_async_work(argv: int) -> int {
    i: int = _aw_index(_napi_argv_i64(argv, 1));
    if i < 0 {
        return _AW_EINVAL;
    }
    # execute always runs inside queue (or the work was never queued, which
    # Node also rejects) — cancellation can never succeed here.
    return _AW_EFAIL;
}

# ── Op 126 — napi_delete_async_work ──────────────────────────────────────────
# argv: [env, work]
def _h_delete_async_work(argv: int) -> int {
    i: int = _aw_index(_napi_argv_i64(argv, 1));
    if i < 0 {
        return _AW_EINVAL;
    }
    if _AW_STATE[i] == _AW_PENDING_COMPLETE {
        # Node forbids deleting queued/executing work.
        return _AW_EFAIL;
    }
    _AW_STATE[i] = _AW_DELETED;
    _AW_EXECUTE[i] = 0;
    _AW_COMPLETE[i] = 0;
    _AW_DATA[i] = 0;
    return _AW_OK;
}

# ── Drain (called from el_tick before the microtask checkpoint) ──────────────

"""Number of completes awaiting delivery."""
def:pub napi_async_pending -> int {
    return _AW_PENDING;
}

"""Deliver every pending complete(env, napi_ok, data), in queue (FIFO)
order.  A complete may queue new work (state flips to pending mid-scan) or
delete its own work record — both are safe: state transitions happen
BEFORE the callback runs, and the outer loop re-scans until quiescent."""
def:pub napi_async_drain_all {
    while _AW_PENDING > 0 {
        i: int = 0;
        n: int = len(_AW_STATE);
        progressed: bool = False;
        while i < n {
            if _AW_STATE[i] == _AW_PENDING_COMPLETE {
                _AW_STATE[i] = _AW_DONE;
                _AW_PENDING = _AW_PENDING - 1;
                _napi_call_async_complete(
                    _AW_COMPLETE[i], _AW_ENV[i], _AW_OK, _AW_DATA[i]
                );
                progressed = True;
            }
            i = i + 1;
        }
        if not progressed {
            break;
        }  # defensive: counter drift must not spin
    }
    if _AW_PENDING == 0 {
        _aw_keepalive(False);
    }
}

# ── Sub-dispatcher — async work ops 125–128 ──────────────────────────────────

"""Route ops 125–128 to the appropriate handler."""
def:pub _dispatch_async_work(op: int, argv: int) -> int {
    if op == _OP_CREATE_ASYNC_WORK {
        return _h_create_async_work(argv);
    } elif op == _OP_DELETE_ASYNC_WORK {
        return _h_delete_async_work(argv);
    } elif op == _OP_QUEUE_ASYNC_WORK {
        return _h_queue_async_work(argv);
    } elif op == _OP_CANCEL_ASYNC_WORK {
        return _h_cancel_async_work(argv);
    }
    return _AW_EFAIL;
}
