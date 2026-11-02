"""NAPI binary ops 86–97: ArrayBuffer / TypedArray / DataView / Buffer.

Design (ROLLUP_SUPPORT_PLAN.md R1): the engine's binary types are JS classes
(binary_types.js / buffer.js) carrying JS-side hidden state (_ptr,
_byteLength, _buffer, ...) with a native BackingStore mirror
(binary_state.jac).  Construction therefore happens IN JS via the
globalThis.__napiBinary helper table (plain, never-throwing functions),
called through the shim's VM-call bridge.  Info queries read the native
mirror directly.

External buffers (napi_create_external_buffer / _external_arraybuffer) are
ZERO-COPY: the ArrayBuffer's _ptr / BackingStore.ptr point straight at the
addon-owned memory (rollup's parse() AST lives in a Rust Vec read through
`new Uint32Array(ast.buffer)`).  Finalizers are recorded in the
_EXT_FIN_* tables and fired exactly once from two hooks:
  • gc_sweep_objects (gc.jac) via napi_binary_on_arraybuffer_swept when the
    ArrayBuffer is collected (--gc runs only), and
  • process_do_exit (process.jac) via napi_binary_flush_finalizers at
    teardown (the GC-disabled default path; matches Node env teardown).

Helper-call contract: __napiBinary functions return 0 on any failure, so a
non-object bridge result maps to NAPI_GENERIC_FAILURE (no JS exception ever
crosses the bridge from these helpers).
"""

import from "libjs_native.so" {
    def _napi_argv_i64(argv: int, idx: int) -> int;  def _napi_write_i64(
        p: int, v: int
    ) -> int;  def _napi_write_i32(p: int, v: int) -> int;  def _napi_vm_call_write_arg(
        idx: int, jsval: int
    ) -> None;  def _napi_vm_call_fn(
        vm_ptr: int, fn_val: int, this_val: int, argc: int
    ) -> int;  def _napi_call_finalize(
        cb: int, env: int, data: int, hint: int
    ) -> None;
}

import from napi.src.napi_env { _napi_vm_ptr, _napi_get_global_jsv }

import from napi.src.napi_ops {
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
    NAPI_OK,
    NAPI_INVALID_ARG,
    NAPI_GENERIC_FAILURE
}

import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    js_number,
    jsv_is_object_cell
}
import from engine.src.runtime.jsstring { str_intern }
import from engine.src.runtime.jsobject { js_object_get }
import from engine.src.runtime.binary_state {
    BackingStore,
    BinaryViewWitness,
    binary_backing_store,
    binary_view_witness,
    binary_is_array_buffer,
    binary_is_typed_array,
    binary_is_data_view,
    binary_typed_array_element_kind,
    binary_typed_array_buffer
}
import from engine.src.ffi.libc { memcpy }

# ── External-buffer finalizer records (invoked by R1.2 wiring; see header) ──
glob _EXT_FIN_DATA: list[int] = [],
     _EXT_FIN_CB: list[int] = [],
     _EXT_FIN_HINT: list[int] = [];

def _nb_record_ext_finalizer(data_ptr: int, cb: int, hint: int) -> None {
    if cb == 0 {
        return;
    }
    _EXT_FIN_DATA.append(data_ptr);
    _EXT_FIN_CB.append(cb);
    _EXT_FIN_HINT.append(hint);
}

"""Number of recorded, not-yet-fired external-buffer finalizers."""
def:pub napi_binary_pending_finalizers -> int {
    n: int = 0;
    i: int = 0;
    while i < len(_EXT_FIN_CB) {
        if _EXT_FIN_CB[i] != 0 {
            n = n + 1;
        }
        i = i + 1;
    }
    return n;
}

"""Fire the finalizer registered for `data_ptr`, exactly once (the entry is
tombstoned BEFORE the callback runs, so re-entry cannot double-fire).
Returns True when a finalizer was found and invoked."""
def:pub napi_binary_finalize_for_ptr(data_ptr: int) -> bool {
    if data_ptr == 0 {
        return False;
    }
    i: int = 0;
    while i < len(_EXT_FIN_DATA) {
        if _EXT_FIN_DATA[i] == data_ptr and _EXT_FIN_CB[i] != 0 {
            cb: int = _EXT_FIN_CB[i];
            hint: int = _EXT_FIN_HINT[i];
            _EXT_FIN_CB[i] = 0;
            _napi_call_finalize(cb, _napi_vm_ptr, data_ptr, hint);
            return True;
        }
        i = i + 1;
    }
    return False;
}

"""GC-sweep hook: an ArrayBuffer object whose backing store points at
`store_ptr` was just tombstoned — release addon-owned memory if external."""
def:pub napi_binary_on_arraybuffer_swept(store_ptr: int) {
    napi_binary_finalize_for_ptr(store_ptr);
}

"""Process-teardown flush: fire every still-pending finalizer (Node runs
buffer finalizers at env teardown; with the sweep hook this is the
GC-disabled default path). Returns the number fired."""
def:pub napi_binary_flush_finalizers -> int {
    fired: int = 0;
    i: int = 0;
    while i < len(_EXT_FIN_CB) {
        cb: int = _EXT_FIN_CB[i];
        if cb != 0 {
            _EXT_FIN_CB[i] = 0;
            _napi_call_finalize(cb, _napi_vm_ptr, _EXT_FIN_DATA[i], _EXT_FIN_HINT[i]);
            fired = fired + 1;
        }
        i = i + 1;
    }
    return fired;
}

# ── JS helper-call plumbing ──────────────────────────────────────────────────

def _nb_helper_fn(name: str) -> int {
    g: int = _napi_get_global_jsv();
    tbl: int = js_object_get(g, str_intern("__napiBinary"));
    if not jsv_is_object_cell(tbl) {
        return 0;
    }
    return js_object_get(tbl, str_intern(name));
}

def _nb_call_helper(name: str, args: list[int]) -> int {
    fn: int = _nb_helper_fn(name);
    if fn == 0 {
        return 0;
    }
    i: int = 0;
    n: int = len(args);
    while i < n {
        _napi_vm_call_write_arg(i, args[i]);
        i = i + 1;
    }
    return _napi_vm_call_fn(_napi_vm_ptr, fn, js_undefined(), n);
}

"""Pointers/sizes cross into JS as float64 numbers (same convention as
__buf.alloc — a 48-bit address is exact in a double mantissa)."""
def _nb_num(v: int) -> int {
    return js_number(float(v));
}

"""Data pointer of a TypedArray/DataView: BackingStore.ptr + byteOffset.
Returns 0 when invalid/detached (matching a NULL data out-param)."""
def _nb_view_data_ptr(view: int) -> int {
    w: BinaryViewWitness = binary_view_witness(view);
    if not w.valid or w.detached {
        return 0;
    }
    buf: int = js_object_get(view, str_intern("_buffer"));
    if not binary_is_array_buffer(buf) {
        return 0;
    }
    st: BackingStore = binary_backing_store(buf);
    if st.ptr == 0 {
        return 0;
    }
    return st.ptr + w.byte_offset;
}

# ── Op 86 — napi_create_arraybuffer ──────────────────────────────────────────
# argv: [env, byte_length, data**, result*]
def _h_create_arraybuffer(argv: int) -> int {
    blen: int = _napi_argv_i64(argv, 1);
    data_pp: int = _napi_argv_i64(argv, 2);
    res_p: int = _napi_argv_i64(argv, 3);
    ab: int = _nb_call_helper("createArrayBuffer", [_nb_num(blen)]);
    if not binary_is_array_buffer(ab) {
        return NAPI_GENERIC_FAILURE;
    }
    if data_pp != 0 {
        st: BackingStore = binary_backing_store(ab);
        _napi_write_i64(data_pp, st.ptr);
    }
    if res_p != 0 {
        _napi_write_i64(res_p, ab);
    }
    return NAPI_OK;
}

# ── Op 87 — napi_get_arraybuffer_info ────────────────────────────────────────
# argv: [env, arraybuffer, data**, byte_length*]
def _h_get_arraybuffer_info(argv: int) -> int {
    ab: int = _napi_argv_i64(argv, 1);
    data_pp: int = _napi_argv_i64(argv, 2);
    len_p: int = _napi_argv_i64(argv, 3);
    if not binary_is_array_buffer(ab) {
        return NAPI_INVALID_ARG;
    }
    st: BackingStore = binary_backing_store(ab);
    if data_pp != 0 {
        _napi_write_i64(data_pp, st.ptr);
    }
    if len_p != 0 {
        _napi_write_i64(len_p, st.byte_length);
    }
    return NAPI_OK;
}

# ── Op 88 — napi_detach_arraybuffer ──────────────────────────────────────────
# argv: [env, arraybuffer]
def _h_detach_arraybuffer(argv: int) -> int {
    ab: int = _napi_argv_i64(argv, 1);
    if not binary_is_array_buffer(ab) {
        return NAPI_INVALID_ARG;
    }
    _nb_call_helper("detach", [ab]);
    return NAPI_OK;
}

# ── Op 89 — napi_create_external_arraybuffer ─────────────────────────────────
# argv: [env, external_data, byte_length, finalize_cb, finalize_hint, result*]
def _h_create_external_arraybuffer(argv: int) -> int {
    data: int = _napi_argv_i64(argv, 1);
    blen: int = _napi_argv_i64(argv, 2);
    cb: int = _napi_argv_i64(argv, 3);
    hint: int = _napi_argv_i64(argv, 4);
    res_p: int = _napi_argv_i64(argv, 5);
    ab: int = _nb_call_helper("wrapExternal", [_nb_num(data), _nb_num(blen)]);
    if not binary_is_array_buffer(ab) {
        return NAPI_GENERIC_FAILURE;
    }
    _nb_record_ext_finalizer(data, cb, hint);
    if res_p != 0 {
        _napi_write_i64(res_p, ab);
    }
    return NAPI_OK;
}

# ── Op 90 — napi_create_typedarray ───────────────────────────────────────────
# argv: [env, type, length, arraybuffer, byte_offset, result*]
def _h_create_typedarray(argv: int) -> int {
    ta_type: int = _napi_argv_i64(argv, 1);
    length: int = _napi_argv_i64(argv, 2);
    ab: int = _napi_argv_i64(argv, 3);
    boff: int = _napi_argv_i64(argv, 4);
    res_p: int = _napi_argv_i64(argv, 5);
    if not binary_is_array_buffer(ab) {
        return NAPI_INVALID_ARG;
    }
    view: int = _nb_call_helper(
        "createTypedArray", [_nb_num(ta_type), ab, _nb_num(boff), _nb_num(length)]
    );
    if not binary_is_typed_array(view) {
        return NAPI_GENERIC_FAILURE;
    }
    if res_p != 0 {
        _napi_write_i64(res_p, view);
    }
    return NAPI_OK;
}

# ── Op 91 — napi_get_typedarray_info ─────────────────────────────────────────
# argv: [env, typedarray, type*, length*, data**, arraybuffer*, byte_offset*]
def _h_get_typedarray_info(argv: int) -> int {
    ta: int = _napi_argv_i64(argv, 1);
    type_p: int = _napi_argv_i64(argv, 2);
    len_p: int = _napi_argv_i64(argv, 3);
    data_pp: int = _napi_argv_i64(argv, 4);
    ab_p: int = _napi_argv_i64(argv, 5);
    boff_p: int = _napi_argv_i64(argv, 6);
    if not binary_is_typed_array(ta) {
        return NAPI_INVALID_ARG;
    }
    w: BinaryViewWitness = binary_view_witness(ta);
    if type_p != 0 {
        # engine element kinds are 1..11 (Int8..BigUint64); napi enum is 0..10.
        _napi_write_i32(type_p, binary_typed_array_element_kind(ta) - 1);
    }
    if len_p != 0 {
        _napi_write_i64(len_p, w.length);
    }
    if data_pp != 0 {
        _napi_write_i64(data_pp, _nb_view_data_ptr(ta));
    }
    if ab_p != 0 {
        _napi_write_i64(ab_p, binary_typed_array_buffer(ta));
    }
    if boff_p != 0 {
        _napi_write_i64(boff_p, w.byte_offset);
    }
    return NAPI_OK;
}

# ── Op 92 — napi_create_dataview ─────────────────────────────────────────────
# argv: [env, byte_length, arraybuffer, byte_offset, result*]
def _h_create_dataview(argv: int) -> int {
    blen: int = _napi_argv_i64(argv, 1);
    ab: int = _napi_argv_i64(argv, 2);
    boff: int = _napi_argv_i64(argv, 3);
    res_p: int = _napi_argv_i64(argv, 4);
    if not binary_is_array_buffer(ab) {
        return NAPI_INVALID_ARG;
    }
    dv: int = _nb_call_helper("createDataView", [ab, _nb_num(boff), _nb_num(blen)]);
    if not binary_is_data_view(dv) {
        return NAPI_GENERIC_FAILURE;
    }
    if res_p != 0 {
        _napi_write_i64(res_p, dv);
    }
    return NAPI_OK;
}

# ── Op 93 — napi_get_dataview_info ───────────────────────────────────────────
# argv: [env, dataview, byte_length*, data**, arraybuffer*, byte_offset*]
def _h_get_dataview_info(argv: int) -> int {
    dv: int = _napi_argv_i64(argv, 1);
    len_p: int = _napi_argv_i64(argv, 2);
    data_pp: int = _napi_argv_i64(argv, 3);
    ab_p: int = _napi_argv_i64(argv, 4);
    boff_p: int = _napi_argv_i64(argv, 5);
    if not binary_is_data_view(dv) {
        return NAPI_INVALID_ARG;
    }
    w: BinaryViewWitness = binary_view_witness(dv);
    if len_p != 0 {
        _napi_write_i64(len_p, w.byte_length);
    }
    if data_pp != 0 {
        _napi_write_i64(data_pp, _nb_view_data_ptr(dv));
    }
    if ab_p != 0 {
        _napi_write_i64(ab_p, js_object_get(dv, str_intern("_buffer")));
    }
    if boff_p != 0 {
        _napi_write_i64(boff_p, w.byte_offset);
    }
    return NAPI_OK;
}

# ── Op 94 — napi_create_buffer ───────────────────────────────────────────────
# argv: [env, size, data**, result*]
def _h_create_buffer(argv: int) -> int {
    size: int = _napi_argv_i64(argv, 1);
    data_pp: int = _napi_argv_i64(argv, 2);
    res_p: int = _napi_argv_i64(argv, 3);
    b: int = _nb_call_helper("bufferAllocUnsafe", [_nb_num(size)]);
    if not binary_is_typed_array(b) {
        return NAPI_GENERIC_FAILURE;
    }
    if data_pp != 0 {
        _napi_write_i64(data_pp, _nb_view_data_ptr(b));
    }
    if res_p != 0 {
        _napi_write_i64(res_p, b);
    }
    return NAPI_OK;
}

# ── Op 95 — napi_create_buffer_copy ──────────────────────────────────────────
# argv: [env, length, src_data, result_data**, result*]
def _h_create_buffer_copy(argv: int) -> int {
    length: int = _napi_argv_i64(argv, 1);
    src: int = _napi_argv_i64(argv, 2);
    data_pp: int = _napi_argv_i64(argv, 3);
    res_p: int = _napi_argv_i64(argv, 4);
    b: int = _nb_call_helper("bufferAllocUnsafe", [_nb_num(length)]);
    if not binary_is_typed_array(b) {
        return NAPI_GENERIC_FAILURE;
    }
    dst: int = _nb_view_data_ptr(b);
    if length > 0 and src != 0 and dst != 0 {
        memcpy(dst, src, length);
    }
    if data_pp != 0 {
        _napi_write_i64(data_pp, dst);
    }
    if res_p != 0 {
        _napi_write_i64(res_p, b);
    }
    return NAPI_OK;
}

# ── Op 96 — napi_create_external_buffer ──────────────────────────────────────
# argv: [env, length, data, finalize_cb, finalize_hint, result*]
def _h_create_external_buffer(argv: int) -> int {
    length: int = _napi_argv_i64(argv, 1);
    data: int = _napi_argv_i64(argv, 2);
    cb: int = _napi_argv_i64(argv, 3);
    hint: int = _napi_argv_i64(argv, 4);
    res_p: int = _napi_argv_i64(argv, 5);
    ab: int = _nb_call_helper("wrapExternal", [_nb_num(data), _nb_num(length)]);
    if not binary_is_array_buffer(ab) {
        return NAPI_GENERIC_FAILURE;
    }
    b: int = _nb_call_helper(
        "bufferFromArrayBuffer", [ab, _nb_num(0), _nb_num(length)]
    );
    if not binary_is_typed_array(b) {
        return NAPI_GENERIC_FAILURE;
    }
    _nb_record_ext_finalizer(data, cb, hint);
    if res_p != 0 {
        _napi_write_i64(res_p, b);
    }
    return NAPI_OK;
}

# ── Op 97 — napi_get_buffer_info ─────────────────────────────────────────────
# argv: [env, value, data**, length*]
def _h_get_buffer_info(argv: int) -> int {
    v: int = _napi_argv_i64(argv, 1);
    data_pp: int = _napi_argv_i64(argv, 2);
    len_p: int = _napi_argv_i64(argv, 3);
    if not binary_is_typed_array(v) {
        return NAPI_INVALID_ARG;
    }
    w: BinaryViewWitness = binary_view_witness(v);
    if data_pp != 0 {
        _napi_write_i64(data_pp, _nb_view_data_ptr(v));
    }
    if len_p != 0 {
        _napi_write_i64(len_p, w.byte_length);
    }
    return NAPI_OK;
}

# ── Sub-dispatcher — binary ops 86–97 ────────────────────────────────────────

"""Route binary ops 86–97 to the appropriate handler."""
def:pub _dispatch_binary(op: int, argv: int) -> int {
    if op == NAPI_OP_CREATE_ARRAYBUFFER {
        return _h_create_arraybuffer(argv);
    } elif op == NAPI_OP_GET_ARRAYBUFFER_INFO {
        return _h_get_arraybuffer_info(argv);
    } elif op == NAPI_OP_DETACH_ARRAYBUFFER {
        return _h_detach_arraybuffer(argv);
    } elif op == NAPI_OP_CREATE_EXTERNAL_ARRAYBUFFER {
        return _h_create_external_arraybuffer(argv);
    } elif op == NAPI_OP_CREATE_TYPEDARRAY {
        return _h_create_typedarray(argv);
    } elif op == NAPI_OP_GET_TYPEDARRAY_INFO {
        return _h_get_typedarray_info(argv);
    } elif op == NAPI_OP_CREATE_DATAVIEW {
        return _h_create_dataview(argv);
    } elif op == NAPI_OP_GET_DATAVIEW_INFO {
        return _h_get_dataview_info(argv);
    } elif op == NAPI_OP_CREATE_BUFFER {
        return _h_create_buffer(argv);
    } elif op == NAPI_OP_CREATE_BUFFER_COPY {
        return _h_create_buffer_copy(argv);
    } elif op == NAPI_OP_CREATE_EXTERNAL_BUFFER {
        return _h_create_external_buffer(argv);
    } elif op == NAPI_OP_GET_BUFFER_INFO {
        return _h_get_buffer_info(argv);
    }
    return NAPI_GENERIC_FAILURE;
}
