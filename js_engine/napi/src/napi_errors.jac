"""NAPI Errors, references, BigInt, cleanup hooks.

Implements op handlers for:
  CREATE_ERROR (98),       CREATE_TYPE_ERROR (99),
  CREATE_RANGE_ERROR (100), CREATE_SYNTAX_ERROR (101),
  THROW (102),             THROW_ERROR (103),
  THROW_TYPE_ERROR (104),  THROW_RANGE_ERROR (105),
  THROW_SYNTAX_ERROR (106),
  IS_EXCEPTION_PENDING (107),
  GET_AND_CLEAR_LAST_EXCEPTION (108),
  FATAL_EXCEPTION (109),
  CREATE_REFERENCE (110),  DELETE_REFERENCE (111),
  REFERENCE_REF (112),     REFERENCE_UNREF (113),
  GET_REFERENCE_VALUE (114),
  CREATE_BIGINT_INT64 (115), CREATE_BIGINT_UINT64 (116),
  CREATE_BIGINT_WORDS (117),
  GET_VALUE_BIGINT_INT64 (118), GET_VALUE_BIGINT_UINT64 (119),
  GET_VALUE_BIGINT_WORDS (120),
  TYPE_TAG_OBJECT (121),   CHECK_OBJECT_TYPE_TAG (122),
  ADD_ENV_CLEANUP_HOOK (123), REMOVE_ENV_CLEANUP_HOOK (124).

Exception model:
  napi_throw* handlers set _napi_pending_exc / _napi_had_exception in
  napi_env.na.jac.  vm.na.jac reads these after every NAPI callback returns
  and propagates them into vm.had_exception / vm.pending_exc.

Reference model:
  napi_ref is an opaque int handle (1-based index into _napi_ref_table).
  _napi_ref_table[idx] holds the JSValue (as int).
  _napi_ref_counts[idx] holds the uint32 refcount.
  Index 0 is unused so handle 0 is the null/invalid ref.

BigInt model:
  BigInt cells use JS_CELL_KIND_BIGINT with a string-interned decimal
  representation (same encoding as process.hrtime.bigint()).
  Words-based BigInt ops return NAPI_GENERIC_FAILURE (deferred).

Cleanup hooks:
  No-ops — the engine is single-threaded and doesn't implement addon teardown.

Type tagging:
  Stored as two hidden uint64 properties on the object under reserved keys
  _KEY_NAPI_TYPE_TAG_LO / _KEY_NAPI_TYPE_TAG_HI.  Reading back uses the same
  keys.

Bun reference: bun/src/bun.js/bindings/NapiHandleScope.h (NapiRef)
               bun/src/bun.js/bindings/JSNativeFunction.zig (throw helpers)
"""

import from "lib/libnapi_shim.so" {
    def _napi_argv_i64(argv: int, idx: int) -> int;  def _napi_write_i64(
        p: int, v: int
    ) -> int;  def _napi_write_bool(p: int, v: int) -> int;
}

import from engine.src.runtime.mem { read_byte, byte_chr }
import from engine.src.ffi.libc { write, _exit }

import from napi.src.napi_env {
    _napi_set_exception,
    _napi_get_had_exception,
    _napi_consume_exception
}

import from napi.src.napi_ops {
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
    NAPI_OK,
    NAPI_GENERIC_FAILURE,
    NAPI_INVALID_ARG
}

import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    js_null,
    js_true,
    js_false,
    js_int,
    jsv_is_string_cell,
    jsv_is_null,
    jsv_is_undefined,
    jsv_to_table_id,
    jsv_from_cell_kind,
    jsv_from_string_id,
    JS_CELL_KIND_BIGINT
}

import from engine.src.runtime.jsstring { str_intern, str_from_id }
import from engine.src.runtime.jsobject {
    js_object_create_null,
    js_object_set,
    js_object_get,
    js_object_set_prototype
}
# A STRONG napi reference (refcount >= 1) must keep its target alive. The GC
# mark phase cannot enumerate _napi_ref_table, so without an explicit root a
# strong-ref'd object is swept out from under the addon (napi/tests/20_gcref).
# Pin strong refs through the shared pin registry (gc_mark_roots traces
# gc_pinned_list); gc_pin is a leaf module so this adds no import cycle. Same
# pattern napi_stubs/napi_func already use for function values.
import from engine.src.runtime.gc_pin { gc_pin_value, gc_unpin_value }
import from engine.src.runtime.error {
    make_error,
    make_type_error,
    make_range_error,
    make_syntax_error,
    get_error_proto,
    get_type_error_proto,
    get_range_error_proto,
    get_syntax_error_proto
}

# ── Module-level ref table ────────────────────────────────────────────────────
# Index 0 is sentinel (unused). Handles are 1-based indices.

glob _napi_ref_table: list[int] = [0],
     _napi_ref_counts: list[int] = [0],
     _KEY_NAPI_TYPE_TAG_LO: int = 1000030,
     _KEY_NAPI_TYPE_TAG_HI: int = 1000031;  # _napi_ref_table[0] unused

# _napi_ref_counts[0] unused

# Hidden property keys for type tagging
# ── Helpers ───────────────────────────────────────────────────────────────────

"""Read a null-terminated C string from memory address ptr."""
def _read_cstr_n6(ptr: int) -> str {
    if ptr == 0 {
        return "";
    }
    result: str = "";
    i: int = 0;
    while i < 65536 {
        b: int = read_byte(ptr, i);
        if b == 0 {
            break;
        }
        result = result + byte_chr(b);
        i = i + 1;
    }
    return result;
}

"""Extract a Jac string from a JSValue string (must be jsv_is_string_cell)."""
def _n6_jsv_to_str(v: JSValue) -> str {
    if jsv_is_null(v) or jsv_is_undefined(v) {
        return "";
    }
    if jsv_is_string_cell(v) {
        return str_from_id(jsv_to_table_id(v));
    }
    return "";
}

"""Build an error object with the given name and message, using the given proto."""
def _make_napi_error(err_name: str, msg_v: JSValue, proto: JSValue) -> JSValue {
    msg_str: str = _n6_jsv_to_str(msg_v);
    err_obj: JSValue = make_error(msg_str);
    # Overwrite the name property to match the requested error kind.
    # Use a real string-cell JSValue: js_string() returns a JSString struct,
    # not a JSValue, so the old cast stored a non-string and left name blank.
    name_key: int = str_intern("name");
    name_val: JSValue = jsv_from_string_id(str_intern(err_name));
    js_object_set(err_obj, name_key, name_val);
    js_object_set_prototype(err_obj, proto);
    return err_obj;
}

# ── Error creation ops (98–101) ───────────────────────────────────────────────

"""napi_create_error / napi_create_type_error / …
   argv[1]=code (napi_value, optional), argv[2]=msg (napi_value), argv[3]=result*"""
def:pub _h_create_error_kind(argv: int, err_name: str, proto: JSValue) -> int {
    msg_v: JSValue = _napi_argv_i64(argv, 2);
    res_p: int = _napi_argv_i64(argv, 3);
    err_obj: JSValue = _make_napi_error(err_name, msg_v, proto);
    # Store optional code property
    code_v: JSValue = _napi_argv_i64(argv, 1);
    if not jsv_is_null(code_v) and not jsv_is_undefined(code_v) {
        code_key: int = str_intern("code");
        js_object_set(err_obj, code_key, code_v);
    }
    if res_p != 0 {
        _napi_write_i64(res_p, err_obj);
    }
    return NAPI_OK;
}

# ── Throw ops (102–106) ───────────────────────────────────────────────────────

"""napi_throw(env, error) — argv[1]=error JSValue"""
def:pub _h_throw(argv: int) -> int {
    err_v: int = _napi_argv_i64(argv, 1);
    _napi_set_exception(err_v);
    return NAPI_OK;
}

"""napi_throw_error / throw_type_error / throw_range_error / throw_syntax_error
   argv[1]=code (char*), argv[2]=msg (char*)"""
def:pub _h_throw_str_error(argv: int, err_name: str, proto: JSValue) -> int {
    msg_ptr: int = _napi_argv_i64(argv, 2);
    msg_str: str = _read_cstr_n6(msg_ptr);
    # Build a real string-cell JSValue. js_string() returns a JSString struct,
    # NOT a JSValue — passing it to _make_napi_error/_n6_jsv_to_str (which
    # gate on jsv_is_string_cell) yielded "" and dropped message+code (F3).
    msg_v: JSValue = jsv_from_string_id(str_intern(msg_str));
    err_obj: JSValue = _make_napi_error(err_name, msg_v, proto);
    # Store optional code property
    code_ptr: int = _napi_argv_i64(argv, 1);
    if code_ptr != 0 {
        code_str: str = _read_cstr_n6(code_ptr);
        code_key: int = str_intern("code");
        code_v: JSValue = jsv_from_string_id(str_intern(code_str));
        js_object_set(err_obj, code_key, code_v);
    }
    _napi_set_exception(err_obj);
    return NAPI_OK;
}

# ── Exception query ops (107–109) ─────────────────────────────────────────────

"""napi_is_exception_pending — argv[1]=result (bool*)"""
def:pub _h_is_exception_pending(argv: int) -> int {
    res_p: int = _napi_argv_i64(argv, 1);
    if res_p != 0 {
        _napi_write_bool(res_p, int(_napi_get_had_exception()));
    }
    return NAPI_OK;
}

"""napi_get_and_clear_last_exception — argv[1]=result (napi_value*)"""
def:pub _h_get_and_clear_last_exception(argv: int) -> int {
    res_p: int = _napi_argv_i64(argv, 1);
    exc: int = _napi_consume_exception();
    if res_p != 0 {
        _napi_write_i64(res_p, exc);
    }
    return NAPI_OK;
}

"""napi_fatal_exception — print the error and exit."""
def:pub _h_fatal_exception(argv: int) -> int {
    msg: str = "FATAL NAPI EXCEPTION\n";
    write(2, msg, len(msg));
    _exit(1);
    return NAPI_GENERIC_FAILURE;
}

# ── Reference ops (110–114) ───────────────────────────────────────────────────

"""napi_create_reference — argv[1]=value, argv[2]=refcount (u32), argv[3]=result*"""
def:pub _h_create_reference(argv: int) -> int {
    val_v: int = _napi_argv_i64(argv, 1);
    refcount: int = _napi_argv_i64(argv, 2);
    res_p: int = _napi_argv_i64(argv, 3);
    _napi_ref_table.append(val_v);
    _napi_ref_counts.append(refcount);
    handle: int = len(_napi_ref_table) - 1;  # 1-based: appended at idx=handle
    # Strong ref → root the target so GC can't sweep it (see import note).
    if refcount >= 1 and val_v != 0 {
        gc_pin_value(val_v);
    }
    if res_p != 0 {
        _napi_write_i64(res_p, handle);
    }
    return NAPI_OK;
}

"""napi_delete_reference — argv[1]=ref (handle int)"""
def:pub _h_delete_reference(argv: int) -> int {
    ref_h: int = _napi_argv_i64(argv, 1);
    if ref_h <= 0 or ref_h >= len(_napi_ref_table) {
        return NAPI_INVALID_ARG;
    }
    # Drop the strong-ref root if this ref was holding one.
    _del_v: int = _napi_ref_table[ref_h];
    if _napi_ref_counts[ref_h] >= 1 and _del_v != 0 {
        gc_unpin_value(_del_v);
    }
    _napi_ref_table[ref_h] = 0;
    _napi_ref_counts[ref_h] = 0;
    return NAPI_OK;
}

"""napi_reference_ref — argv[1]=ref, argv[2]=result* (u32)
   Increments refcount and writes new count."""
def:pub _h_reference_ref(argv: int) -> int {
    ref_h: int = _napi_argv_i64(argv, 1);
    res_p: int = _napi_argv_i64(argv, 2);
    if ref_h <= 0 or ref_h >= len(_napi_ref_table) {
        return NAPI_INVALID_ARG;
    }
    _old_rc: int = _napi_ref_counts[ref_h];
    _napi_ref_counts[ref_h] = _old_rc + 1;
    # 0 → 1 transition: became strong, root the target.
    _ref_v: int = _napi_ref_table[ref_h];
    if _old_rc == 0 and _ref_v != 0 {
        gc_pin_value(_ref_v);
    }
    if res_p != 0 {
        _napi_write_i64(res_p, _napi_ref_counts[ref_h]);
    }
    return NAPI_OK;
}

"""napi_reference_unref — argv[1]=ref, argv[2]=result* (u32)
   Decrements refcount (floor 0) and writes new count."""
def:pub _h_reference_unref(argv: int) -> int {
    ref_h: int = _napi_argv_i64(argv, 1);
    res_p: int = _napi_argv_i64(argv, 2);
    if ref_h <= 0 or ref_h >= len(_napi_ref_table) {
        return NAPI_INVALID_ARG;
    }
    cnt: int = _napi_ref_counts[ref_h];
    if cnt > 0 {
        cnt = cnt - 1;
    }
    _napi_ref_counts[ref_h] = cnt;
    # 1 → 0 transition: became weak, drop the root (target may now be collected).
    _unref_v: int = _napi_ref_table[ref_h];
    if cnt == 0 and _unref_v != 0 {
        gc_unpin_value(_unref_v);
    }
    if res_p != 0 {
        _napi_write_i64(res_p, cnt);
    }
    return NAPI_OK;
}

"""napi_get_reference_value — argv[1]=ref, argv[2]=result*"""
def:pub _h_get_reference_value(argv: int) -> int {
    ref_h: int = _napi_argv_i64(argv, 1);
    res_p: int = _napi_argv_i64(argv, 2);
    if ref_h <= 0 or ref_h >= len(_napi_ref_table) {
        return NAPI_INVALID_ARG;
    }
    if res_p != 0 {
        _napi_write_i64(res_p, _napi_ref_table[ref_h]);
    }
    return NAPI_OK;
}

# ── BigInt ops (115–120) ──────────────────────────────────────────────────────

"""napi_create_bigint_int64 — argv[1]=int64 value, argv[2]=result*"""
def:pub _h_create_bigint_int64(argv: int) -> int {
    val: int = _napi_argv_i64(argv, 1);
    res_p: int = _napi_argv_i64(argv, 2);
    id: int = str_intern(str(val));
    bigv: JSValue = jsv_from_cell_kind(id, JS_CELL_KIND_BIGINT);
    if res_p != 0 {
        _napi_write_i64(res_p, bigv);
    }
    return NAPI_OK;
}

"""napi_create_bigint_uint64 — argv[1]=uint64 (bit-cast as int64), argv[2]=result*"""
def:pub _h_create_bigint_uint64(argv: int) -> int {
    val: int = _napi_argv_i64(argv, 1);
    res_p: int = _napi_argv_i64(argv, 2);
    # For unsigned BigInt, format as unsigned if negative (i.e. high bit set)
    val_str: str = str(val);
    if val < 0 {
        # Two's complement unsigned representation: 2^64 + val
        val_str = str(val + 18446744073709551616);
    }
    id: int = str_intern(val_str);
    bigv: JSValue = jsv_from_cell_kind(id, JS_CELL_KIND_BIGINT);
    if res_p != 0 {
        _napi_write_i64(res_p, bigv);
    }
    return NAPI_OK;
}

"""napi_get_value_bigint_int64 — argv[1]=value (JSValue), argv[2]=result*, argv[3]=lossless*"""
def:pub _h_get_value_bigint_int64(argv: int) -> int {
    val_v: JSValue = _napi_argv_i64(argv, 1);
    res_p: int = _napi_argv_i64(argv, 2);
    loss_p: int = _napi_argv_i64(argv, 3);
    id: int = jsv_to_table_id(val_v);
    s: str = str_from_id(id);
    n: int = int(s);
    if res_p != 0 {
        _napi_write_i64(res_p, n);
    }
    if loss_p != 0 {
        _napi_write_bool(loss_p, 1);
    }
    return NAPI_OK;
}

"""napi_get_value_bigint_uint64 — same layout as int64 variant"""
def:pub _h_get_value_bigint_uint64(argv: int) -> int {
    val_v: JSValue = _napi_argv_i64(argv, 1);
    res_p: int = _napi_argv_i64(argv, 2);
    loss_p: int = _napi_argv_i64(argv, 3);
    id: int = jsv_to_table_id(val_v);
    s: str = str_from_id(id);
    n: int = int(s);
    if res_p != 0 {
        _napi_write_i64(res_p, n);
    }
    if loss_p != 0 {
        _napi_write_bool(loss_p, 1);
    }
    return NAPI_OK;
}

# napi_create_bigint_words / napi_get_value_bigint_words — deferred
def:pub _h_bigint_words_stub(argv: int) -> int {
    return NAPI_GENERIC_FAILURE;
}

# ── Type tagging ops (121–122) ────────────────────────────────────────────────

"""napi_type_tag_object — store two uint64 tag words as BigInt hidden properties.

BigInt cells preserve the full 64-bit value via string-interned decimal
representation.  Using js_int() would truncate to int32."""
def:pub _h_type_tag_object(argv: int) -> int {
    obj_v: JSValue = _napi_argv_i64(argv, 1);
    tag_ptr: int = _napi_argv_i64(argv, 2);
    if tag_ptr == 0 {
        return NAPI_INVALID_ARG;
    }
    lo: int = _napi_argv_i64(tag_ptr, 0);
    hi: int = _napi_argv_i64(tag_ptr, 1);
    lo_jsv: JSValue = jsv_from_cell_kind(str_intern(str(lo)), JS_CELL_KIND_BIGINT);
    hi_jsv: JSValue = jsv_from_cell_kind(str_intern(str(hi)), JS_CELL_KIND_BIGINT);
    js_object_set(obj_v, _KEY_NAPI_TYPE_TAG_LO, lo_jsv);
    js_object_set(obj_v, _KEY_NAPI_TYPE_TAG_HI, hi_jsv);
    return NAPI_OK;
}

"""napi_check_object_type_tag — compare stored BigInt tag words with argv[2] tag.

argv[1]=object, argv[2]=napi_type_tag* (two uint64 words), argv[3]=result*"""
def:pub _h_check_object_type_tag(argv: int) -> int {
    obj_v: JSValue = _napi_argv_i64(argv, 1);
    tag_ptr: int = _napi_argv_i64(argv, 2);
    res_p: int = _napi_argv_i64(argv, 3);
    if res_p == 0 {
        return NAPI_INVALID_ARG;
    }
    # Object must have been tagged (both hidden props present)
    stored_lo_jsv: JSValue = js_object_get(obj_v, _KEY_NAPI_TYPE_TAG_LO);
    stored_hi_jsv: JSValue = js_object_get(obj_v, _KEY_NAPI_TYPE_TAG_HI);
    if jsv_is_undefined(stored_lo_jsv) or jsv_is_undefined(stored_hi_jsv) {
        _napi_write_bool(res_p, 0);
        return NAPI_OK;
    }
    stored_lo: int = int(str_from_id(jsv_to_table_id(stored_lo_jsv)));
    stored_hi: int = int(str_from_id(jsv_to_table_id(stored_hi_jsv)));
    lo_in: int = _napi_argv_i64(tag_ptr, 0);
    hi_in: int = _napi_argv_i64(tag_ptr, 1);
    _napi_write_bool(res_p, int((stored_lo == lo_in) and (stored_hi == hi_in)));
    return NAPI_OK;
}

# ── Cleanup hook ops (123–124) ────────────────────────────────────────────────
# No-ops: single-threaded engine does not call teardown hooks.

def:pub _h_add_env_cleanup_hook(argv: int) -> int {
    return NAPI_OK;
}

def:pub _h_remove_env_cleanup_hook(argv: int) -> int {
    return NAPI_OK;
}

# ── Dispatcher ────────────────────────────────────────────────────────────────

"""Dispatch an error/reference/BigInt/cleanup op.  Called from napi_func.na.jac _dispatch_func for op >= 98."""
def:pub _dispatch_errors(op: int, argv: int) -> int {
    if op == NAPI_OP_CREATE_ERROR {
        return _h_create_error_kind(argv, "Error", get_error_proto());
    } elif op == NAPI_OP_CREATE_TYPE_ERROR {
        return _h_create_error_kind(argv, "TypeError", get_type_error_proto());
    } elif op == NAPI_OP_CREATE_RANGE_ERROR {
        return _h_create_error_kind(argv, "RangeError", get_range_error_proto());
    } elif op == NAPI_OP_CREATE_SYNTAX_ERROR {
        return _h_create_error_kind(argv, "SyntaxError", get_syntax_error_proto());
    } elif op == NAPI_OP_THROW {
        return _h_throw(argv);
    } elif op == NAPI_OP_THROW_ERROR {
        return _h_throw_str_error(argv, "Error", get_error_proto());
    } elif op == NAPI_OP_THROW_TYPE_ERROR {
        return _h_throw_str_error(argv, "TypeError", get_type_error_proto());
    } elif op == NAPI_OP_THROW_RANGE_ERROR {
        return _h_throw_str_error(argv, "RangeError", get_range_error_proto());
    } elif op == NAPI_OP_THROW_SYNTAX_ERROR {
        return _h_throw_str_error(argv, "SyntaxError", get_syntax_error_proto());
    } elif op == NAPI_OP_IS_EXCEPTION_PENDING {
        return _h_is_exception_pending(argv);
    } elif op == NAPI_OP_GET_AND_CLEAR_LAST_EXCEPTION {
        return _h_get_and_clear_last_exception(argv);
    } elif op == NAPI_OP_FATAL_EXCEPTION {
        return _h_fatal_exception(argv);
    } elif op == NAPI_OP_CREATE_REFERENCE {
        return _h_create_reference(argv);
    } elif op == NAPI_OP_DELETE_REFERENCE {
        return _h_delete_reference(argv);
    } elif op == NAPI_OP_REFERENCE_REF {
        return _h_reference_ref(argv);
    } elif op == NAPI_OP_REFERENCE_UNREF {
        return _h_reference_unref(argv);
    } elif op == NAPI_OP_GET_REFERENCE_VALUE {
        return _h_get_reference_value(argv);
    } elif op == NAPI_OP_CREATE_BIGINT_INT64 {
        return _h_create_bigint_int64(argv);
    } elif op == NAPI_OP_CREATE_BIGINT_UINT64 {
        return _h_create_bigint_uint64(argv);
    } elif op == NAPI_OP_CREATE_BIGINT_WORDS {
        return _h_bigint_words_stub(argv);
    } elif op == NAPI_OP_GET_VALUE_BIGINT_INT64 {
        return _h_get_value_bigint_int64(argv);
    } elif op == NAPI_OP_GET_VALUE_BIGINT_UINT64 {
        return _h_get_value_bigint_uint64(argv);
    } elif op == NAPI_OP_GET_VALUE_BIGINT_WORDS {
        return _h_bigint_words_stub(argv);
    } elif op == NAPI_OP_TYPE_TAG_OBJECT {
        return _h_type_tag_object(argv);
    } elif op == NAPI_OP_CHECK_OBJECT_TYPE_TAG {
        return _h_check_object_type_tag(argv);
    } elif op == NAPI_OP_ADD_ENV_CLEANUP_HOOK {
        return _h_add_env_cleanup_hook(argv);
    } elif op == NAPI_OP_REMOVE_ENV_CLEANUP_HOOK {
        return _h_remove_env_cleanup_hook(argv);
    }
    return NAPI_GENERIC_FAILURE;
}
