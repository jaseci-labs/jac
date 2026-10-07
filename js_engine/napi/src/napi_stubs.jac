"""NAPI deferred / stub ops (129–147).

Async work (125–128) lives in napi_async.na.jac; napi_dispatch routes it
there directly.

Ops returning NAPI_OK: callback scopes and adjust_external_memory (these
are no-ops in a single-threaded runtime; refusing them would break callers
that fire unconditionally).

Ops returning NAPI_GENERIC_FAILURE: threadsafe functions (the stub cases —
the real TSFN path dispatches through napi_tsfn), run_script, and async
cleanup hooks.

Per-env storage (set/get_instance_data) is implemented with a module-level
global since we are single-env.

Note: napi_adjust_external_memory (op 142), napi_get_node_version (op 31), and
napi_get_version (op 33) are handled inline in napi_shim.c and never reach this
dispatcher.  The cases are retained here as NAPI_OK fallbacks for correctness.

Bun reference: bun/src/bun.js/bindings/NapiHandleScope.cpp (env teardown)
"""

import from "lib/libnapi_shim.so" {
    def _napi_argv_i64(argv: int, idx: int) -> int;  def _napi_write_i64(
        p: int, v: int
    ) -> int;
}

import from napi.src.napi_tsfn { tsfn_dispatch }
import from "lib/libnapi_shim.so" {
    def _napi_tsfn_result -> int;  def _napi_tsfn_get_js_func(tsfn_ptr: int) -> int;
}

import from engine.src.runtime.gc { gc_pin_value, gc_unpin_value }
import from engine.src.runtime.jsvalue { JSValue }

import from napi.src.napi_ops {
    NAPI_OP_ASYNC_INIT,
    NAPI_OP_ASYNC_DESTROY,
    NAPI_OP_MAKE_CALLBACK,
    NAPI_OP_OPEN_CALLBACK_SCOPE,
    NAPI_OP_CLOSE_CALLBACK_SCOPE,
    NAPI_OP_CREATE_THREADSAFE_FUNCTION,
    NAPI_OP_GET_THREADSAFE_FUNCTION_CONTEXT,
    NAPI_OP_CALL_THREADSAFE_FUNCTION,
    NAPI_OP_ACQUIRE_THREADSAFE_FUNCTION,
    NAPI_OP_RELEASE_THREADSAFE_FUNCTION,
    NAPI_OP_REF_THREADSAFE_FUNCTION,
    NAPI_OP_UNREF_THREADSAFE_FUNCTION,
    NAPI_OP_RUN_SCRIPT,
    NAPI_OP_ADJUST_EXTERNAL_MEMORY,
    NAPI_OP_SET_INSTANCE_DATA,
    NAPI_OP_GET_INSTANCE_DATA,
    NAPI_OP_ADD_ASYNC_CLEANUP_HOOK,
    NAPI_OP_REMOVE_ASYNC_CLEANUP_HOOK,
    NAPI_OP_GET_MODULE_FILE_NAME,
    NAPI_OK,
    NAPI_GENERIC_FAILURE
}


# ── Per-env instance data ────────────────────────────────────────────────────────────

glob _napi_instance_data: int = 0;

# ── Dispatch ─────────────────────────────────────────────────────────────────────────────

def:pub _dispatch_stubs(op: int, argv: int) -> int {
    # Callback scopes — no-ops in single-threaded runtime.
    # Returning NAPI_OK lets addons that always open/close a callback scope
    # continue without hitting errors.
    if op == NAPI_OP_OPEN_CALLBACK_SCOPE {
        return NAPI_OK;
    } elif op == NAPI_OP_CLOSE_CALLBACK_SCOPE {
        return NAPI_OK;
    }
    # GC hint — handled inline in napi_shim.c; kept here as a safety net.
    elif op == NAPI_OP_ADJUST_EXTERNAL_MEMORY {
        return NAPI_OK;
    }
    # ── Per-env instance data ───────────────────────────────────────────────
    # shim passes: argv[0]=env, argv[1]=data_ptr, argv[2]=finalize_cb,
    #              argv[3]=finalize_hint  (set_instance_data)
    # shim passes: argv[0]=env, argv[1]=out_void** (get_instance_data)
    elif op == NAPI_OP_SET_INSTANCE_DATA {
        if argv != 0 {
            _napi_instance_data = _napi_argv_i64(argv, 1);
        }
        return NAPI_OK;
    } elif op == NAPI_OP_GET_INSTANCE_DATA {
        if argv != 0 {
            out_p: int = _napi_argv_i64(argv, 1);
            if out_p != 0 {
                _napi_write_i64(out_p, _napi_instance_data);
            }
        }
        return NAPI_OK;
    }
    # ── Deferred stubs: all return NAPI_GENERIC_FAILURE ────────────────────
    # Async work (125–128) is implemented in napi_async.na.jac and routed
    # there by napi_dispatch — those ops never reach this dispatcher.

    # Async context — not implemented.
    elif op == NAPI_OP_ASYNC_INIT {
        return NAPI_GENERIC_FAILURE;
    } elif op == NAPI_OP_ASYNC_DESTROY {
        return NAPI_GENERIC_FAILURE;
    } elif op == NAPI_OP_MAKE_CALLBACK {
        return NAPI_GENERIC_FAILURE;
    }
    # Threadsafe functions — real implementation in napi_tsfn.na.jac.
    # tsfn_dispatch writes its status into a C-side slot; we read it back
    # via _napi_tsfn_result() to avoid the cross-module Unknown-return issue.
    #
    # CREATE: GC-pin js_func (argv[1]) so the GC never reclaims the callback closure.
    # RELEASE: GC-unpin js_func when the TSFN is destroyed (should_close != 0).
    elif op == NAPI_OP_CREATE_THREADSAFE_FUNCTION {
        js_func_create: int = _napi_argv_i64(argv, 1);
        if js_func_create != 0 {
            gc_pin_value(js_func_create);
        }
        tsfn_dispatch(op, argv);
        return _napi_tsfn_result();
    } elif op == NAPI_OP_RELEASE_THREADSAFE_FUNCTION {
        tptr_release: int = _napi_argv_i64(argv, 0);
        js_func_release: int = _napi_tsfn_get_js_func(tptr_release);
        should_close: int = _napi_argv_i64(argv, 1);
        tsfn_dispatch(op, argv);
        if should_close != 0 {
            if js_func_release != 0 {
                gc_unpin_value(js_func_release);
            }
        }
        return _napi_tsfn_result();
    } elif op == NAPI_OP_CALL_THREADSAFE_FUNCTION
        or op == NAPI_OP_ACQUIRE_THREADSAFE_FUNCTION
        or op == NAPI_OP_REF_THREADSAFE_FUNCTION
        or op == NAPI_OP_UNREF_THREADSAFE_FUNCTION {
        tsfn_dispatch(op, argv);
        return _napi_tsfn_result();
    } elif op == NAPI_OP_GET_THREADSAFE_FUNCTION_CONTEXT {
        return NAPI_OK;
    }
    # Script evaluation — not implemented.
    elif op == NAPI_OP_RUN_SCRIPT {
        return NAPI_GENERIC_FAILURE;
    }
    # Async cleanup hooks — not implemented.
    elif op == NAPI_OP_ADD_ASYNC_CLEANUP_HOOK {
        return NAPI_GENERIC_FAILURE;
    } elif op == NAPI_OP_REMOVE_ASYNC_CLEANUP_HOOK {
        return NAPI_GENERIC_FAILURE;
    }
    # Module file name — not implemented.
    elif op == NAPI_OP_GET_MODULE_FILE_NAME {
        return NAPI_GENERIC_FAILURE;
    }

    return NAPI_GENERIC_FAILURE;
}
