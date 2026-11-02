"""NAPI value handlers.

Implements the NAPI op handlers for:
  • Type queries  (ops  6–16): typeof, is_array, strict_equals
  • Create prims  (ops 17–24): create_int32/uint32/int64/double, get_boolean/global/null/undefined
  • Get values    (ops 25–32): get_value_int32/uint32/int64/double/bool, get_uv_event_loop

Each handler signature: _h_xxx(argv: int) -> int
  argv — raw int64_t* pointer (from shim), read with _napi_argv_i64(argv, idx)
  returns napi_status (0 = NAPI_OK)

Scope ops (1–5) are handled in napi_scope_dispatch.na.jac.
All sub-dispatchers are called from _napi_dispatch in napi_dispatch.na.jac.

Bun reference: bun/src/bun.js/bindings/JSValue.zig
"""

import from "libjs_native.so" {
    def _napi_argv_i64(argv: int, idx: int) -> int;  def _napi_write_i64(
        p: int, v: int
    ) -> int;  def _napi_write_i32(p: int, v: int) -> int;  def _napi_write_u32(
        p: int, v: int
    ) -> int;  def _napi_write_bool(p: int, v: int) -> int;  def _napi_write_f64(
        p: int, v: float
    ) -> int;
}

import from engine.src.runtime.jsvalue {
    jsv_is_undefined,
    jsv_is_null,
    jsv_is_bool,
    jsv_is_number,
    jsv_is_int32,
    jsv_is_double,
    jsv_is_string_cell,
    jsv_is_symbol,
    jsv_is_bigint_cell,
    jsv_is_cell,
    jsv_is_object_cell,
    jsv_cell_kind,
    JS_CELL_KIND_NATIVE,
    jsv_to_int32,
    jsv_to_double,
    jsv_to_bool,
    jsv_to_number,
    jsv_to_table_id,
    jsv_from_int32,
    jsv_from_double,
    jsv_from_bool,
    jsv_null,
    jsv_undefined,
    js_strict_equal,
    JS_DOUBLE_OFF,
    JS_BITS_NAN
}

import from engine.src.runtime.jsobject {
    js_object_has_own,
    KEY_CTOR_KIND,
    js_object_get_prototype
}

import from engine.src.runtime.error { get_error_proto }

import from engine.src.runtime.binary_state {
    BackingStore,
    binary_backing_store,
    binary_kind_of,
    binary_is_array_buffer,
    binary_is_typed_array,
    binary_is_data_view,
    BINARY_KIND_ARRAY_BUFFER
}

import from engine.src.builtins.array { js_is_array }

import from "libjs_native.so" { def uv_default_loop -> int;  }

import from napi.src.napi_env { _napi_get_global_jsv }

import from napi.src.napi_ops {
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
    NAPI_OP_GET_UV_EVENT_LOOP,
    NAPI_OK,
    NAPI_NUMBER_EXPECTED,
    NAPI_BOOLEAN_EXPECTED
}

# ── Local constants ─────────────────────────────────────────────────────────────
# napi_valuetype (must match node_api_types.h):
glob _VT_UNDEFINED: int = 0,
     _VT_NULL: int = 1,
     _VT_BOOLEAN: int = 2,
     _VT_NUMBER: int = 3,
     _VT_STRING: int = 4,
     _VT_SYMBOL: int = 5,
     _VT_OBJECT: int = 6,
     _VT_FUNCTION: int = 7,
     _VT_BIGINT: int = 9;

# ══════════════════════════════════════════════════════════════════════════════
# Type-query sub-dispatcher (ops 6–16)
# ══════════════════════════════════════════════════════════════════════════════

"""Route type-query ops 6–16 to the appropriate handler."""
def:pub _dispatch_typeq(op: int, argv: int) -> int {
    if op == NAPI_OP_TYPEOF {
        return _h_typeof(argv);
    } elif op == NAPI_OP_IS_ARRAY {
        return _h_is_array(argv);
    } elif op == NAPI_OP_IS_ARRAYBUFFER {
        return _h_is_arraybuffer(argv);
    } elif op == NAPI_OP_IS_BUFFER {
        return _h_is_buffer(argv);
    } elif op == NAPI_OP_IS_DATE {
        return _h_is_pred_false(argv);
    } elif op == NAPI_OP_IS_ERROR {  # stub (dates unwired)
        return _h_is_error(argv);
    } elif op == NAPI_OP_IS_PROMISE {
        return _h_is_pred_false(argv);
    } elif op == NAPI_OP_IS_TYPEDARRAY {  # stub
        return _h_is_typedarray(argv);
    } elif op == NAPI_OP_IS_DATAVIEW {
        return _h_is_dataview(argv);
    } elif op == NAPI_OP_IS_DETACHED_ARRAYBUFFER {
        return _h_is_detached_arraybuffer(argv);
    } elif op == NAPI_OP_STRICT_EQUALS {
        return _h_strict_equals(argv);
    }
    return NAPI_OK;
}

"""napi_typeof: argv[0]=env, argv[1]=value, argv[2]=napi_valuetype* result."""
def _h_typeof(argv: int) -> int {
    v: int = _napi_argv_i64(argv, 1);
    result_ptr: int = _napi_argv_i64(argv, 2);
    t: int = _VT_UNDEFINED;
    if jsv_is_undefined(v) {
        t = _VT_UNDEFINED;
    } elif jsv_is_null(v) {
        t = _VT_NULL;
    } elif jsv_is_bool(v) {
        t = _VT_BOOLEAN;
    } elif jsv_is_number(v) {
        t = _VT_NUMBER;
    } elif jsv_is_string_cell(v) {
        t = _VT_STRING;
    } elif jsv_is_symbol(v) {
        t = _VT_SYMBOL;
    } elif jsv_is_bigint_cell(v) {
        t = _VT_BIGINT;
    } elif jsv_is_cell(v) {
        if jsv_cell_kind(v) == JS_CELL_KIND_NATIVE {
            t = _VT_FUNCTION;
        } elif jsv_is_object_cell(v)
            and jsv_to_table_id(v) > 0
            and js_object_has_own(v, KEY_CTOR_KIND) {
            # Callable JSObject constructor (RegExp, Array, Object, … created via
            # js_callable_create) — the VM reports `typeof` of these as "function",
            # so NAPI must agree, else napi-rs rejects e.g. a RegExp filter payload.
            t = _VT_FUNCTION;
        } else {
            t = _VT_OBJECT;
        }
    }
    # print("[TYPEOF] v=", v, " t=", t);
    _napi_write_i32(result_ptr, t);
    return NAPI_OK;
}

"""napi_is_array: argv[0]=env, argv[1]=value, argv[2]=bool* result."""
def _h_is_array(argv: int) -> int {
    v: int = _napi_argv_i64(argv, 1);
    result_ptr: int = _napi_argv_i64(argv, 2);
    b: bool = js_is_array(v);
    _napi_write_bool(result_ptr, int(b));
    return NAPI_OK;
}

"""napi_is_error: argv[0]=env, argv[1]=value, argv[2]=bool* result.
True when the value is an Error instance — i.e. the shared Error.prototype
(root of all built-in error subtypes) is on its prototype chain."""
def _h_is_error(argv: int) -> int {
    v: int = _napi_argv_i64(argv, 1);
    result_ptr: int = _napi_argv_i64(argv, 2);
    is_err: bool = False;
    if jsv_is_object_cell(v) {
        err_proto: int = get_error_proto();
        cur: int = js_object_get_prototype(v);
        # Bounded walk (guards against pathological/cyclic chains).
        steps: int = 0;
        while jsv_is_object_cell(cur) and steps < 100 {
            if cur == err_proto {
                is_err = True;
                break;
            }
            cur = js_object_get_prototype(cur);
            steps = steps + 1;
        }
    }
    _napi_write_bool(result_ptr, int(is_err));
    return NAPI_OK;
}

"""napi_is_arraybuffer — true for ArrayBuffer proper (SharedArrayBuffer is
excluded, matching V8's IsArrayBuffer)."""
def _h_is_arraybuffer(argv: int) -> int {
    v: int = _napi_argv_i64(argv, 1);
    result_ptr: int = _napi_argv_i64(argv, 2);
    b: bool = binary_kind_of(v) == BINARY_KIND_ARRAY_BUFFER;
    _napi_write_bool(result_ptr, int(b));
    return NAPI_OK;
}

"""napi_is_buffer — Node's Buffer::HasInstance is IsArrayBufferView():
true for ANY TypedArray and for DataView (oracle-verified vs node v20)."""
def _h_is_buffer(argv: int) -> int {
    v: int = _napi_argv_i64(argv, 1);
    result_ptr: int = _napi_argv_i64(argv, 2);
    b: bool = binary_is_typed_array(v) or binary_is_data_view(v);
    _napi_write_bool(result_ptr, int(b));
    return NAPI_OK;
}

"""napi_is_typedarray."""
def _h_is_typedarray(argv: int) -> int {
    v: int = _napi_argv_i64(argv, 1);
    result_ptr: int = _napi_argv_i64(argv, 2);
    _napi_write_bool(result_ptr, int(binary_is_typed_array(v)));
    return NAPI_OK;
}

"""napi_is_dataview."""
def _h_is_dataview(argv: int) -> int {
    v: int = _napi_argv_i64(argv, 1);
    result_ptr: int = _napi_argv_i64(argv, 2);
    _napi_write_bool(result_ptr, int(binary_is_data_view(v)));
    return NAPI_OK;
}

"""napi_is_detached_arraybuffer."""
def _h_is_detached_arraybuffer(argv: int) -> int {
    v: int = _napi_argv_i64(argv, 1);
    result_ptr: int = _napi_argv_i64(argv, 2);
    b: bool = False;
    if binary_is_array_buffer(v) {
        st: BackingStore = binary_backing_store(v);
        b = st.detached;
    }
    _napi_write_bool(result_ptr, int(b));
    return NAPI_OK;
}

"""Stub predicate that always returns false.
argv[2] = bool* result."""
def _h_is_pred_false(argv: int) -> int {
    result_ptr: int = _napi_argv_i64(argv, 2);
    _napi_write_bool(result_ptr, 0);
    return NAPI_OK;
}

"""napi_strict_equals: argv[0]=env, argv[1]=lhs, argv[2]=rhs, argv[3]=bool* result."""
def _h_strict_equals(argv: int) -> int {
    lhs: int = _napi_argv_i64(argv, 1);
    rhs: int = _napi_argv_i64(argv, 2);
    result_ptr: int = _napi_argv_i64(argv, 3);
    eq: bool = js_strict_equal(lhs, rhs);
    _napi_write_bool(result_ptr, int(eq));
    return NAPI_OK;
}

# ══════════════════════════════════════════════════════════════════════════════
# Create-primitive sub-dispatcher (ops 17–24)
# ══════════════════════════════════════════════════════════════════════════════

"""Route create-primitive ops 17–24 to the appropriate handler."""
def:pub _dispatch_create(op: int, argv: int) -> int {
    if op == NAPI_OP_CREATE_INT32 {
        return _h_create_int32(argv);
    } elif op == NAPI_OP_CREATE_UINT32 {
        return _h_create_uint32(argv);
    } elif op == NAPI_OP_CREATE_INT64 {
        return _h_create_int64(argv);
    } elif op == NAPI_OP_CREATE_DOUBLE {
        return _h_create_double(argv);
    } elif op == NAPI_OP_GET_BOOLEAN {
        return _h_get_boolean(argv);
    } elif op == NAPI_OP_GET_GLOBAL {
        return _h_get_global(argv);
    } elif op == NAPI_OP_GET_NULL {
        return _h_get_null(argv);
    } elif op == NAPI_OP_GET_UNDEFINED {
        return _h_get_undefined(argv);
    }
    return NAPI_OK;
}

"""napi_create_int32: argv[0]=env, argv[1]=int32 value, argv[2]=napi_value* out."""
def _h_create_int32(argv: int) -> int {
    v: int = _napi_argv_i64(argv, 1);
    result_ptr: int = _napi_argv_i64(argv, 2);
    jsval: int = jsv_from_int32(v);
    _napi_write_i64(result_ptr, jsval);
    return NAPI_OK;
}

"""napi_create_uint32: argv[0]=env, argv[1]=uint32 (zero-extended), argv[2]=napi_value* out."""
def _h_create_uint32(argv: int) -> int {
    v: int = _napi_argv_i64(argv, 1);
    result_ptr: int = _napi_argv_i64(argv, 2);
    # uint32 → JS number (double); the value always fits exactly in a double.
    jsval: int = jsv_from_double(float(v));
    _napi_write_i64(result_ptr, jsval);
    return NAPI_OK;
}

"""napi_create_int64: argv[0]=env, argv[1]=int64 value, argv[2]=napi_value* out.
Large int64 values may lose precision when converted to JS number (double)."""
def _h_create_int64(argv: int) -> int {
    v: int = _napi_argv_i64(argv, 1);
    result_ptr: int = _napi_argv_i64(argv, 2);
    jsval: int = jsv_from_double(float(v));
    _napi_write_i64(result_ptr, jsval);
    return NAPI_OK;
}

"""napi_create_double: argv[0]=env, argv[1]=raw IEEE 754 bits, argv[2]=napi_value* out.
The shim packs the double via union { double d; int64_t i; } before calling us.
We re-encode to the NaN-boxed JSValue format: bits + JS_DOUBLE_OFF (NaN → JS_BITS_NAN)."""
def _h_create_double(argv: int) -> int {
    bits: int = _napi_argv_i64(argv, 1);
    result_ptr: int = _napi_argv_i64(argv, 2);
    jsval: int = 0;
    if (bits & 0x7FF0_0000_0000_0000) == 0x7FF0_0000_0000_0000
        and (bits & 0x000F_FFFF_FFFF_FFFF) != 0 {
        jsval = JS_BITS_NAN;  # normalise any NaN to the canonical quiet NaN
    } else {
        jsval = bits + JS_DOUBLE_OFF;  # NaN-box the double
    }
    _napi_write_i64(result_ptr, jsval);
    return NAPI_OK;
}

"""napi_get_boolean: argv[0]=env, argv[1]=bool (0/1), argv[2]=napi_value* out."""
def _h_get_boolean(argv: int) -> int {
    b: int = _napi_argv_i64(argv, 1);
    result_ptr: int = _napi_argv_i64(argv, 2);
    jsval: int = jsv_from_bool(b != 0);
    _napi_write_i64(result_ptr, jsval);
    return NAPI_OK;
}

"""napi_get_global: argv[0]=env, argv[1]=napi_value* out.
Returns the global_this JSValue set by the loader.  Returns jsv_undefined()
if the loader has not called _napi_set_global_jsv yet."""
def _h_get_global(argv: int) -> int {
    result_ptr: int = _napi_argv_i64(argv, 1);
    g: int = _napi_get_global_jsv();
    if g == 0 {
        g = jsv_undefined();
    }
    _napi_write_i64(result_ptr, g);
    return NAPI_OK;
}

"""napi_get_null: argv[0]=env, argv[1]=napi_value* out."""
def _h_get_null(argv: int) -> int {
    result_ptr: int = _napi_argv_i64(argv, 1);
    _napi_write_i64(result_ptr, jsv_null());
    return NAPI_OK;
}

"""napi_get_undefined: argv[0]=env, argv[1]=napi_value* out."""
def _h_get_undefined(argv: int) -> int {
    result_ptr: int = _napi_argv_i64(argv, 1);
    _napi_write_i64(result_ptr, jsv_undefined());
    return NAPI_OK;
}

# ══════════════════════════════════════════════════════════════════════════════
# Get-value sub-dispatcher (ops 25–32)
# ══════════════════════════════════════════════════════════════════════════════

"""Route get-value ops 25–32 to the appropriate handler.
(Ops 30, 31, 33 are handled inline in the C shim and never arrive here.)"""
def:pub _dispatch_getval(op: int, argv: int) -> int {
    if op == NAPI_OP_GET_VALUE_INT32 {
        return _h_get_value_int32(argv);
    } elif op == NAPI_OP_GET_VALUE_UINT32 {
        return _h_get_value_uint32(argv);
    } elif op == NAPI_OP_GET_VALUE_INT64 {
        return _h_get_value_int64(argv);
    } elif op == NAPI_OP_GET_VALUE_DOUBLE {
        return _h_get_value_double(argv);
    } elif op == NAPI_OP_GET_VALUE_BOOL {
        return _h_get_value_bool(argv);
    } elif op == NAPI_OP_GET_UV_EVENT_LOOP {
        return _h_get_uv_event_loop(argv);
    }
    return NAPI_OK;
}

"""napi_get_value_int32: argv[0]=env, argv[1]=napi_value, argv[2]=int32_t* out."""
def _h_get_value_int32(argv: int) -> int {
    v: int = _napi_argv_i64(argv, 1);
    result_ptr: int = _napi_argv_i64(argv, 2);
    if not jsv_is_number(v) {
        return NAPI_NUMBER_EXPECTED;
    }
    n: float = jsv_to_number(v);
    _napi_write_i32(result_ptr, int(n));
    return NAPI_OK;
}

"""napi_get_value_uint32: argv[0]=env, argv[1]=napi_value, argv[2]=uint32_t* out."""
def _h_get_value_uint32(argv: int) -> int {
    v: int = _napi_argv_i64(argv, 1);
    result_ptr: int = _napi_argv_i64(argv, 2);
    if not jsv_is_number(v) {
        return NAPI_NUMBER_EXPECTED;
    }
    n: float = jsv_to_number(v);
    u32: int = int(n) & 0xFFFF_FFFF;
    _napi_write_u32(result_ptr, u32);
    return NAPI_OK;
}

"""napi_get_value_int64: argv[0]=env, argv[1]=napi_value, argv[2]=int64_t* out.
Converts via ToNumber; large doubles may lose precision."""
def _h_get_value_int64(argv: int) -> int {
    v: int = _napi_argv_i64(argv, 1);
    result_ptr: int = _napi_argv_i64(argv, 2);
    if not jsv_is_number(v) {
        return NAPI_NUMBER_EXPECTED;
    }
    n: float = jsv_to_number(v);
    _napi_write_i64(result_ptr, int(n));
    return NAPI_OK;
}

"""napi_get_value_double: argv[0]=env, argv[1]=napi_value, argv[2]=double* out."""
def _h_get_value_double(argv: int) -> int {
    v: int = _napi_argv_i64(argv, 1);
    result_ptr: int = _napi_argv_i64(argv, 2);
    if not jsv_is_number(v) {
        return NAPI_NUMBER_EXPECTED;
    }
    d: float = jsv_to_number(v);
    _napi_write_f64(result_ptr, d);
    return NAPI_OK;
}

"""napi_get_value_bool: argv[0]=env, argv[1]=napi_value, argv[2]=bool* out."""
def _h_get_value_bool(argv: int) -> int {
    v: int = _napi_argv_i64(argv, 1);
    result_ptr: int = _napi_argv_i64(argv, 2);
    if not jsv_is_bool(v) {
        return NAPI_BOOLEAN_EXPECTED;
    }
    b: bool = jsv_to_bool(v);
    _napi_write_bool(result_ptr, int(b));
    return NAPI_OK;
}

"""napi_get_uv_event_loop: argv[0]=env, argv[1]=uv_loop_t** out.
Writes the default loop pointer to *out."""
def _h_get_uv_event_loop(argv: int) -> int {
    result_ptr: int = _napi_argv_i64(argv, 1);
    loop_ptr: int = uv_default_loop();
    _napi_write_i64(result_ptr, loop_ptr);
    return NAPI_OK;
}
