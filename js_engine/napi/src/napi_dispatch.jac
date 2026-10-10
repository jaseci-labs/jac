"""NAPI dispatch — main entry point called by the C shim.

The C shim (lib/libnapi_shim.so) calls back into Jac via a function pointer
set by _napi_set_dispatch(fn_ptr).  This module provides:

  1. Import of _napi_set_dispatch from the shim (to register the callback).
  2. The _napi_dispatch(op, argv, argc) -> int  Jac function that IS
     the callback.  Its address (as int64 via ptrtoint coercion) is passed
     to _napi_set_dispatch once on the first .node load.

Op IDs must match the NapiOp enum in napi/shim/napi_shim.c.
"""

import from "lib/libnapi_shim.so" {
    def _napi_set_dispatch(fn: int) -> int;  def _napi_get_pending_init -> int;  def _napi_invoke_register(
        init_fn: int, env: int, exports: int
    ) -> int;  def _napi_slot_read(slot: int) -> int;  def _napi_slot_write(
        slot: int, val: int
    ) -> int;  def _napi_argv_i64(argv: int, idx: int) -> int;  def _napi_write_i64(
        p: int, v: int
    ) -> int;  def _napi_write_i32(p: int, v: int) -> int;  def _napi_write_u32(
        p: int, v: int
    ) -> int;  def _napi_write_bool(p: int, v: int) -> int;  def _napi_write_f64(
        p: int, v: float
    ) -> int;
}

# ── Op-ID and status constants (single source of truth in napi_ops.na.jac) ──

import from napi.src.napi_ops {
    NAPI_OP_OPEN_HANDLE_SCOPE,
    NAPI_OP_CLOSE_HANDLE_SCOPE,
    NAPI_OP_OPEN_ESCAPABLE_HANDLE_SCOPE,
    NAPI_OP_CLOSE_ESCAPABLE_HANDLE_SCOPE,
    NAPI_OP_ESCAPE_HANDLE,
    NAPI_OP_TYPEOF,
    NAPI_OP_IS_ARRAY,
    NAPI_OP_IS_ARRAYBUFFER,
    NAPI_OP_IS_BUFFER,
    NAPI_OP_IS_DATE,
    NAPI_OP_IS_ERROR,
    NAPI_OP_IS_PROMISE,
    NAPI_OP_IS_TYPEDARRAY,
    NAPI_OP_IS_DATAVIEW,
    NAPI_OP_IS_DETACHED_ARRAYBUFFER,
    NAPI_OP_STRICT_EQUALS,
    NAPI_OP_CREATE_INT32,
    NAPI_OP_CREATE_UINT32,
    NAPI_OP_CREATE_INT64,
    NAPI_OP_CREATE_DOUBLE,
    NAPI_OP_GET_BOOLEAN,
    NAPI_OP_GET_GLOBAL,
    NAPI_OP_GET_NULL,
    NAPI_OP_GET_UNDEFINED,
    NAPI_OP_GET_VALUE_INT32,
    NAPI_OP_GET_VALUE_UINT32,
    NAPI_OP_GET_VALUE_INT64,
    NAPI_OP_GET_VALUE_DOUBLE,
    NAPI_OP_GET_VALUE_BOOL,
    NAPI_OP_GET_LAST_ERROR_INFO,
    NAPI_OP_GET_NODE_VERSION,
    NAPI_OP_GET_UV_EVENT_LOOP,
    NAPI_OP_GET_VERSION,
    NAPI_OP_CREATE_STRING_UTF8,
    NAPI_OP_CREATE_STRING_UTF16,
    NAPI_OP_CREATE_STRING_LATIN1,
    NAPI_OP_GET_VALUE_STRING_UTF8,
    NAPI_OP_GET_VALUE_STRING_UTF16,
    NAPI_OP_GET_VALUE_STRING_LATIN1,
    NAPI_OP_CREATE_SYMBOL,
    NAPI_OP_NODE_API_SYMBOL_FOR,
    NAPI_OP_CREATE_OBJECT,
    NAPI_OP_CREATE_ARRAY,
    NAPI_OP_CREATE_ARRAY_WITH_LENGTH,
    NAPI_OP_CREATE_DATE,
    NAPI_OP_GET_DATE_VALUE,
    NAPI_OP_GET_PROPERTY,
    NAPI_OP_SET_PROPERTY,
    NAPI_OP_HAS_PROPERTY,
    NAPI_OP_DELETE_PROPERTY,
    NAPI_OP_GET_NAMED_PROPERTY,
    NAPI_OP_SET_NAMED_PROPERTY,
    NAPI_OP_HAS_NAMED_PROPERTY,
    NAPI_OP_HAS_OWN_PROPERTY,
    NAPI_OP_GET_ELEMENT,
    NAPI_OP_SET_ELEMENT,
    NAPI_OP_HAS_ELEMENT,
    NAPI_OP_DELETE_ELEMENT,
    NAPI_OP_GET_ARRAY_LENGTH,
    NAPI_OP_GET_PROPERTY_NAMES,
    NAPI_OP_GET_ALL_PROPERTY_NAMES,
    NAPI_OP_DEFINE_PROPERTIES,
    NAPI_OP_GET_PROTOTYPE,
    NAPI_OP_OBJECT_FREEZE,
    NAPI_OP_OBJECT_SEAL,
    NAPI_OP_COERCE_TO_BOOL,
    NAPI_OP_COERCE_TO_NUMBER,
    NAPI_OP_COERCE_TO_OBJECT,
    NAPI_OP_COERCE_TO_STRING,
    NAPI_OP_CREATE_FUNCTION,
    NAPI_OP_CALL_FUNCTION,
    NAPI_OP_NEW_INSTANCE,
    NAPI_OP_GET_CB_INFO,
    NAPI_OP_GET_NEW_TARGET,
    NAPI_OP_DEFINE_CLASS,
    NAPI_OP_WRAP,
    NAPI_OP_UNWRAP,
    NAPI_OP_REMOVE_WRAP,
    NAPI_OP_ADD_FINALIZER,
    NAPI_OP_INSTANCEOF,
    NAPI_OP_CREATE_EXTERNAL,
    NAPI_OP_GET_VALUE_EXTERNAL,
    NAPI_OP_CREATE_PROMISE,
    NAPI_OP_RESOLVE_DEFERRED,
    NAPI_OP_REJECT_DEFERRED,
    NAPI_OP_CREATE_ARRAYBUFFER,
    NAPI_OP_GET_ARRAYBUFFER_INFO,
    NAPI_OP_DETACH_ARRAYBUFFER,
    NAPI_OP_CREATE_EXTERNAL_ARRAYBUFFER,
    NAPI_OP_CREATE_TYPEDARRAY,
    NAPI_OP_GET_TYPEDARRAY_INFO,
    NAPI_OP_CREATE_DATAVIEW,
    NAPI_OP_GET_DATAVIEW_INFO,
    NAPI_OP_CREATE_BUFFER,
    NAPI_OP_CREATE_BUFFER_COPY,
    NAPI_OP_CREATE_EXTERNAL_BUFFER,
    NAPI_OP_GET_BUFFER_INFO,
    NAPI_OP_CREATE_ERROR,
    NAPI_OP_CREATE_TYPE_ERROR,
    NAPI_OP_CREATE_RANGE_ERROR,
    NAPI_OP_CREATE_SYNTAX_ERROR,
    NAPI_OP_THROW,
    NAPI_OP_THROW_ERROR,
    NAPI_OP_THROW_TYPE_ERROR,
    NAPI_OP_THROW_RANGE_ERROR,
    NAPI_OP_THROW_SYNTAX_ERROR,
    NAPI_OP_IS_EXCEPTION_PENDING,
    NAPI_OP_GET_AND_CLEAR_LAST_EXCEPTION,
    NAPI_OP_FATAL_EXCEPTION,
    NAPI_OP_CREATE_REFERENCE,
    NAPI_OP_DELETE_REFERENCE,
    NAPI_OP_REFERENCE_REF,
    NAPI_OP_REFERENCE_UNREF,
    NAPI_OP_GET_REFERENCE_VALUE,
    NAPI_OP_CREATE_BIGINT_INT64,
    NAPI_OP_CREATE_BIGINT_UINT64,
    NAPI_OP_CREATE_BIGINT_WORDS,
    NAPI_OP_GET_VALUE_BIGINT_INT64,
    NAPI_OP_GET_VALUE_BIGINT_UINT64,
    NAPI_OP_GET_VALUE_BIGINT_WORDS,
    NAPI_OP_TYPE_TAG_OBJECT,
    NAPI_OP_CHECK_OBJECT_TYPE_TAG,
    NAPI_OP_ADD_ENV_CLEANUP_HOOK,
    NAPI_OP_REMOVE_ENV_CLEANUP_HOOK,
    NAPI_OP_CREATE_ASYNC_WORK,
    NAPI_OP_DELETE_ASYNC_WORK,
    NAPI_OP_QUEUE_ASYNC_WORK,
    NAPI_OP_CANCEL_ASYNC_WORK,
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
    NAPI_INVALID_ARG,
    NAPI_OBJECT_EXPECTED,
    NAPI_STRING_EXPECTED,
    NAPI_NAME_EXPECTED,
    NAPI_FUNCTION_EXPECTED,
    NAPI_NUMBER_EXPECTED,
    NAPI_BOOLEAN_EXPECTED,
    NAPI_ARRAY_EXPECTED,
    NAPI_GENERIC_FAILURE,
    NAPI_PENDING_EXCEPTION,
    NAPI_CANCELLED,
    NAPI_ESCAPE_CALLED_TWICE,
    NAPI_HANDLE_SCOPE_MISMATCH,
    NAPI_CALLBACK_SCOPE_MISMATCH,
    NAPI_QUEUE_FULL,
    NAPI_CLOSING,
    NAPI_BIGINT_EXPECTED,
    NAPI_DATE_EXPECTED,
    NAPI_ARRAYBUFFER_EXPECTED,
    NAPI_DETACHABLE_ARRAYBUFFER_EXPECTED,
    NAPI_WOULD_DEADLOCK
}

import from engine.src.runtime.jsobject {
    js_object_napi_obs_push,
    js_object_napi_obs_pop
}

import from napi.src.napi_values { _dispatch_typeq, _dispatch_create, _dispatch_getval }
import from napi.src.napi_scope_dispatch { _dispatch_scope }
import from napi.src.napi_string { _dispatch_string }
import from napi.src.napi_props { _dispatch_props }
import from napi.src.napi_func { _dispatch_func }
import from napi.src.napi_async { _dispatch_async_work }
import from napi.src.napi_stubs { _dispatch_stubs }

"""Main NAPI dispatch entry point called by the C shim.

Signature on the C side:
    int _napi_dispatch(int op, int64_t* argv, int argc)

argv is a raw int64_t* pointer packed by the shim for the given op.
Read slots:  _napi_argv_i64(argv, idx)
Write out-params: _napi_write_i32 / _napi_write_i64 / _napi_write_f64 etc.

Op routing:
  1– 5  → scope ops      (_dispatch_scope  in napi_scope_dispatch.na.jac)
  6–16  → type queries   (_dispatch_typeq  in napi_values.na.jac)
  17–24 → create prims   (_dispatch_create in napi_values.na.jac)
  25–32 → get values     (_dispatch_getval in napi_values.na.jac)
  34–41 → strings/symbol (_dispatch_string in napi_string.na.jac)
  42–69 → objects/arrays/props/coercions (_dispatch_props in napi_props.na.jac)
  70–85 → functions/classes/promises     (_dispatch_func  in napi_func.na.jac)
  86–147 → errors, refs, BigInt, deferred ops
  Ops 30, 31, 33 are handled inline in the C shim (never arrive here).
"""
def:pub _napi_dispatch(op: int, argv: int, argc: int) -> int {
    js_object_napi_obs_push();
    res: int = _napi_dispatch_inner(op, argv, argc);
    js_object_napi_obs_pop();
    return res;
}

def _napi_dispatch_inner(op: int, argv: int, argc: int) -> int {
    # print("[NAPI_OP]", op);
    if op >= NAPI_OP_OPEN_HANDLE_SCOPE and op <= NAPI_OP_ESCAPE_HANDLE {
        return _dispatch_scope(op, argv);
    } elif op >= NAPI_OP_TYPEOF and op <= NAPI_OP_STRICT_EQUALS {
        return _dispatch_typeq(op, argv);
    } elif op >= NAPI_OP_CREATE_INT32 and op <= NAPI_OP_GET_UNDEFINED {
        return _dispatch_create(op, argv);
    } elif op >= NAPI_OP_GET_VALUE_INT32 and op <= NAPI_OP_GET_UV_EVENT_LOOP {
        return _dispatch_getval(op, argv);
    } elif op >= NAPI_OP_CREATE_STRING_UTF8 and op <= NAPI_OP_NODE_API_SYMBOL_FOR {
        return _dispatch_string(op, argv);
    } elif op >= NAPI_OP_CREATE_OBJECT and op <= NAPI_OP_COERCE_TO_STRING {
        return _dispatch_props(op, argv);
    } elif op >= NAPI_OP_CREATE_FUNCTION and op <= NAPI_OP_REJECT_DEFERRED {
        return _dispatch_func(op, argv);
    }
    # ArrayBuffer, TypedArray, Buffer, error, reference, BigInt ops (86–124)
    elif op >= 86 and op <= 124 {
        return _dispatch_func(op, argv);
    }
    # Async work (125–128) — napi_async.na.jac
    elif op >= NAPI_OP_CREATE_ASYNC_WORK and op <= NAPI_OP_CANCEL_ASYNC_WORK {
        return _dispatch_async_work(op, argv);
    }
    # Deferred / stub ops (129–147)
    elif op >= 129 and op <= 147 {
        return _dispatch_stubs(op, argv);
    }
    return NAPI_GENERIC_FAILURE;
}
