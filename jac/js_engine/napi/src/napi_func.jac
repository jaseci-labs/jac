"""NAPI functions, classes, wrap/external, promises.

Design (single-threaded NAPI):
  - napi_callback_info is implemented via module-level globals (_cbinfo_*).
    A fixed sentinel int (NAPI_CBINFO_SENTINEL=1) is passed to C as the
    napi_callback_info opaque handle.  napi_get_cb_info reads from the globals.
  - NAPI closures are JSClosure objects with napi_cb_ptr != 0.  The VM's
    CALL opcode checks this field and calls _napi_invoke_callback_from_vm
    instead of running the Jac interpreter.
  - Promise settle+drain uses scheduler_push_reaction so reactions are
    picked up by the event loop on its next tick.

Bun reference: bun/src/bun.js/bindings/JSNativeFunction.zig
               bun/src/bun.js/bindings/ObjectConstructor.zig
"""

import from engine.src.runtime.encoding { jsv_is_closure_cell }
import from "libjs_native.so" {
    def _napi_argv_i64(argv: int, idx: int) -> int;  def _napi_write_i64(
        p: int, v: int
    ) -> int;  def _napi_write_bool(p: int, v: int) -> int;  def _napi_call_c_callback(
        fn_ptr: int, env_int: int, cbinfo_int: int
    ) -> int;  def _napi_vm_call_write_arg(idx: int, jsval: int) -> None;  def _napi_vm_call_fn(
        vm_ptr: int, fn_val: int, this_val: int, argc: int
    ) -> int;
}

import from engine.src.runtime.mem { read_byte, read_ptr, read_u32, byte_chr }
import from napi.src.napi_binary { _dispatch_binary }

import from napi.src.napi_env { _napi_get_realm, _napi_vm_ptr }
import from napi.src.napi_errors { _dispatch_errors }

import from napi.src.napi_ops {
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
    NAPI_OP_GET_BUFFER_INFO,
    NAPI_OK,
    NAPI_GENERIC_FAILURE,
    NAPI_INVALID_ARG
}

import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    js_null,
    js_true,
    js_int,
    jsv_is_undefined,
    jsv_is_null,
    jsv_is_object_cell,
    jsv_is_int32,
    jsv_to_int32,
    jsv_from_cell_kind,
    jsv_to_table_id,
    jsv_is_string_cell,
    jsv_is_symbol,
    JS_CELL_KIND_NATIVE
}

import from engine.src.runtime.jsobject {
    js_object_create_null,
    js_object_create,
    js_object_set,
    js_object_get,
    js_object_has_own,
    js_object_delete,
    js_object_get_prototype,
    js_object_set_prototype
}

import from engine.src.runtime.jsstring { str_intern }

import from engine.src.runtime.gc_pin { gc_pin_value, gc_unpin_value }

import from engine.src.runtime.realm { Realm }

import from engine.src.vm.closure_type { JSClosure }

import from engine.src.bytecode.op { CompiledFunction, ConstantPool }

import from engine.src.builtins.promise {
    js_promise_create,
    js_promise_settle,
    js_promise_get_state,
    js_promise_get_reactions,
    PROMISE_PENDING,
    PROMISE_FULFILLED,
    PROMISE_REJECTED,
    _RKEY_ONFULFILL,
    _RKEY_ONREJECT,
    _RKEY_NEXT
}
import from engine.src.builtins.markers { _KEY_PREACTIONS }

import from engine.src.builtins.array {
    js_array_create,
    js_array_len,
    js_array_get,
    js_array_push
}

import from engine.src.vm.scheduler { scheduler_push_reaction }

import from engine.src.runtime.wk_keys { WK_PROTOTYPE }

# ── Hidden-property key IDs ──────────────────────────────────────────────────
# MUST NOT clash with any engine-internal key id. The engine reserves the
# 1000020..1005001 range for its own hidden keys (KEY_CTOR_KIND=1000023,
# _KEY_IS_ARGUMENTS=1000024, KEY_HOME_REALM_ID=1000025, _KEY_IS_REGEXP_MARK=
# 1000026, ...). NAPI keys previously sat at 1000023..26 and COLLIDED — most
# damagingly _KEY_NAPI_WRAP==KEY_CTOR_KIND, which made `typeof wrappedObj`
# report "function" (F1). Use a dedicated 1009000+ block clear of that range.

"""Property key used to store the native wrap pointer (napi_wrap)."""
glob:pub _KEY_NAPI_WRAP: int = 1009001;

"""Property key for the raw data pointer stored by napi_create_external."""
glob:pub _KEY_NAPI_EXT_DATA: int = 1009002;

"""Marker property distinguishing external objects from plain JSObjects."""
glob:pub _KEY_NAPI_IS_EXT: int = 1009003;

"""Property key holding the Promise JSValue inside a napi_deferred object."""
glob:pub _KEY_NAPI_DEFERRED_PROMISE: int = 1009004;

# ── cbinfo globals (single-threaded NAPI callback info) ───────────────────────

"""Fixed sentinel passed to C as napi_callback_info (never dereferenced by C)."""
glob NAPI_CBINFO_SENTINEL: int = 1;

"""Number of arguments in the current NAPI callback invocation."""
glob _cbinfo_argc: int = 0;

"""Argument JSValues for the current NAPI callback invocation."""
glob _cbinfo_args: list[int] = [];

"""'this' JSValue for the current NAPI callback invocation."""
glob _cbinfo_this: int = 0;

"""User data pointer for napi_get_cb_info (from the JSClosure.napi_cb_data)."""
glob _cbinfo_data: int = 0;

"""new.target JSValue; 0 means not a [[Construct]] call."""
glob _cbinfo_new_target: int = 0;

# ── Helpers ────────────────────────────────────────────────────────────────────

"""Read a null-terminated C string from ptr into a Jac str."""
def _read_cstr_nf(ptr: int) -> str {
    if ptr == 0 {
        return "";
    }
    result: str = "";
    i: int = 0;
    b: int = read_byte(ptr, i);
    while b != 0 {
        result = result + byte_chr(b);
        i = i + 1;
        b = read_byte(ptr, i);
    }
    return result;
}

"""Read the i-th napi_value from a C napi_value[] array at base ptr."""
def _read_argv_slot(base: int, idx: int) -> int {
    if base == 0 {
        return js_undefined();
    }
    return _napi_argv_i64(base, idx);
}

"""Create a NAPI closure and register it in the realm's closure table.
Returns the JSValue (JS_CELL_KIND_NATIVE tagged int) for the new function."""
def _napi_make_closure(name: str, cb_ptr: int, cb_data: int) -> int {
    r: Realm = _napi_get_realm();
    pool: ConstantPool = ConstantPool(values=[]);
    fn: CompiledFunction = CompiledFunction(
        name=name,
        file="<napi>",
        code=[],
        constants=pool,
        locals=[],
        params=[],
        free_vars=[],
        free_var_slots=[],
        num_locals=0,
        is_strict=False,
        is_async=False,
        is_generator=False,
        has_rest=False,
        arguments_slot=-1
    );
    empty_cf: list[CompiledFunction] = [];
    empty_jsv: list[JSValue] = [];
    cl: JSClosure = JSClosure(
        func=fn,
        free_vals=empty_jsv,
        lexical_this=js_undefined(),
        prototype_obj=js_object_create_null(),
        super_class=js_undefined(),
        fn_props=js_object_create_null(),
        module_fns=empty_cf,
        is_arrow=False,
        napi_cb_ptr=cb_ptr,
        napi_cb_data=cb_data
    );
    r.closures.append(cl);
    r.closures_mark_epoch.append(0);  # G1.1: parallel mark-epoch slot (0 = unmarked)
    return jsv_from_cell_kind(len(r.closures) - 1, JS_CELL_KIND_NATIVE);
}

"""Settle a promise and enqueue its reactions with the scheduler.
Mirrors VM._promise_settle_and_drain but uses the shared realm instead."""
def _napi_promise_settle(p: JSValue, state: int, value: JSValue) -> None {
    if js_promise_get_state(p) != PROMISE_PENDING {
        return;
    }
    js_promise_settle(p, state, value);
    reactions: JSValue = js_promise_get_reactions(p);
    n_r: int = js_array_len(reactions);
    r_realm: Realm = _napi_get_realm();
    i_r: int = 0;
    while i_r < n_r {
        r: JSValue = js_array_get(reactions, i_r);
        on_f: JSValue = js_object_get(r, _RKEY_ONFULFILL);
        on_r: JSValue = js_object_get(r, _RKEY_ONREJECT);
        next_p: JSValue = js_object_get(r, _RKEY_NEXT);
        scheduler_push_reaction(r_realm, on_f, on_r, state, value, next_p);
        i_r = i_r + 1;
    }
    js_object_set(p, _KEY_PREACTIONS, js_array_create([]));
}

# ── Public trampoline (called by vm.na.jac CALL / CALL_METHOD / NEW) ──────────

"""Invoke a NAPI C callback from the JS VM.

Sets the module-level cbinfo globals so that any napi_get_cb_info call from
the C callback body will read the correct arguments.

  cb_ptr    — C function pointer (uintptr_t) for the napi_callback.
  cb_data   — user data pointer passed to napi_create_function.
  this_val  — 'this' JSValue (int).
  args      — argument JSValues.
  new_target — new.target JSValue; 0 means called as a function, not a constructor.

Returns the napi_value (JSValue int) returned by the C callback, or
js_undefined() if the callback returned NULL (0)."""
def:pub _napi_invoke_callback_from_vm(
    cb_ptr: int, cb_data: int, this_val: int, args: list[int], new_target: int
) -> int {
    _cbinfo_argc = len(args);
    _cbinfo_args = args;
    _cbinfo_this = this_val;
    _cbinfo_data = cb_data;
    _cbinfo_new_target = new_target;
    env_int: int = _napi_vm_ptr;
    if env_int == 0 {
        env_int = 1;
    }  # fallback to sentinel
    raw_ret: int = _napi_call_c_callback(cb_ptr, env_int, NAPI_CBINFO_SENTINEL);
    if raw_ret == 0 {
        return js_undefined();
    }
    return raw_ret;
}

"""Return True iff v is a Jac closure (JS_CELL_KIND_NATIVE, table id below
FN_BUILTIN_BASE). Mirrors is_fn_val in vm.na.jac without importing vm."""
def _is_fn_val(v: int) -> bool {
    return jsv_is_closure_cell(v);
}

# ── Op 70 — napi_create_function ──────────────────────────────────────────────
# argv[0]=env, argv[1]=utf8name (char*), argv[2]=length (size_t),
# argv[3]=cb (napi_callback), argv[4]=data (void*), argv[5]=result (napi_value*)

def _h_create_function(argv: int) -> int {
    name_ptr: int = _napi_argv_i64(argv, 1);
    cb_ptr: int = _napi_argv_i64(argv, 3);
    data_ptr: int = _napi_argv_i64(argv, 4);
    result_p: int = _napi_argv_i64(argv, 5);
    if cb_ptr == 0 or result_p == 0 {
        return NAPI_INVALID_ARG;
    }
    name: str = _read_cstr_nf(name_ptr);
    if name == "" {
        name = "anonymous";
    }
    fn_val: int = _napi_make_closure(name, cb_ptr, data_ptr);
    _napi_write_i64(result_p, fn_val);
    return NAPI_OK;
}

# ── Op 71 — napi_call_function ────────────────────────────────────────────────
# argv[0]=env, argv[1]=recv (this), argv[2]=func, argv[3]=argc,
# argv[4]=argv_ptr (napi_value[]), argv[5]=result (napi_value*)

def _h_call_function(argv: int) -> int {
    recv_v: int = _napi_argv_i64(argv, 1);
    func_v: int = _napi_argv_i64(argv, 2);
    argc_v: int = _napi_argv_i64(argv, 3);
    argv_ptr: int = _napi_argv_i64(argv, 4);
    result_p: int = _napi_argv_i64(argv, 5);
    if not _is_fn_val(func_v) {
        return NAPI_GENERIC_FAILURE;
    }
    r: Realm = _napi_get_realm();
    fn_idx: int = jsv_to_table_id(func_v);
    if fn_idx >= len(r.closures) {
        return NAPI_GENERIC_FAILURE;
    }
    cl: JSClosure = r.closures[fn_idx];
    ret: int = 0;
    if cl.napi_cb_ptr != 0 {
        # NAPI C callback: collect args into a Jac list and call directly.
        call_args: list[int] = [];
        ai: int = 0;
        while ai < argc_v {
            call_args.append(_napi_argv_i64(argv_ptr, ai));
            ai = ai + 1;
        }
        ret = _napi_invoke_callback_from_vm(
            cl.napi_cb_ptr, cl.napi_cb_data, recv_v, call_args, 0
        );
    } else {
        # JS closure: route through the C shim's vm-call bridge.
        # Write args into the shim's scratch buffer first.
        ai2: int = 0;
        while ai2 < argc_v {
            _napi_vm_call_write_arg(ai2, _napi_argv_i64(argv_ptr, ai2));
            ai2 = ai2 + 1;
        }
        ret = _napi_vm_call_fn(_napi_vm_ptr, func_v, recv_v, argc_v);
    }
    if result_p != 0 {
        _napi_write_i64(result_p, ret);
    }
    return NAPI_OK;
}

# ── Op 72 — napi_new_instance ─────────────────────────────────────────────────
# argv[0]=env, argv[1]=constructor, argv[2]=argc,
# argv[3]=argv_ptr (napi_value[]), argv[4]=result (napi_value*)

def _h_new_instance(argv: int) -> int {
    ctor_v: int = _napi_argv_i64(argv, 1);
    argc_v: int = _napi_argv_i64(argv, 2);
    argv_ptr: int = _napi_argv_i64(argv, 3);
    result_p: int = _napi_argv_i64(argv, 4);
    call_args: list[int] = [];
    ai: int = 0;
    while ai < argc_v {
        call_args.append(_napi_argv_i64(argv_ptr, ai));
        ai = ai + 1;
    }
    if not _is_fn_val(ctor_v) {
        return NAPI_GENERIC_FAILURE;
    }
    r: Realm = _napi_get_realm();
    fn_idx: int = jsv_to_table_id(ctor_v);
    if fn_idx >= len(r.closures) {
        return NAPI_GENERIC_FAILURE;
    }
    cl: JSClosure = r.closures[fn_idx];
    if cl.napi_cb_ptr == 0 {
        return NAPI_GENERIC_FAILURE;
    }
    # Create a new 'this' object inheriting from constructor.prototype
    new_this: int = js_object_create_null();
    if not jsv_is_undefined(cl.prototype_obj) and not jsv_is_null(cl.prototype_obj) {
        new_this = js_object_create(cl.prototype_obj);
    }
    # new.target = the constructor function itself (per ECMAScript §10.2.5);
    # this_val = the newly allocated object.
    ret: int = _napi_invoke_callback_from_vm(
        cl.napi_cb_ptr, cl.napi_cb_data, new_this, call_args, ctor_v
    );
    # If constructor returned non-null object, use that; otherwise new_this
    result_obj: int = new_this;
    if ret != 0 and jsv_is_object_cell(ret) {
        result_obj = ret;
    }
    if result_p != 0 {
        _napi_write_i64(result_p, result_obj);
    }
    return NAPI_OK;
}

# ── Op 73 — napi_get_cb_info ──────────────────────────────────────────────────
# argv[0]=env, argv[1]=cbinfo (sentinel, ignored),
# argv[2]=argc_out (size_t*, in/out), argv[3]=argv_out (napi_value[]),
# argv[4]=this_arg_out (napi_value*), argv[5]=data_out (void**)

def _h_get_cb_info(argv: int) -> int {
    argc_ptr: int = _napi_argv_i64(argv, 2);
    argv_out_p: int = _napi_argv_i64(argv, 3);
    this_ptr: int = _napi_argv_i64(argv, 4);
    data_ptr: int = _napi_argv_i64(argv, 5);
    # argc is in/out: caller sets it to the max slots in argv_out;
    # we clamp the write count and then store the actual count back.
    # Per spec: if argc_ptr is NULL, we must not write to argv_out either.
    if argc_ptr != 0 {
        req_in: int = _napi_argv_i64(argc_ptr, 0);  # max slots caller allocated
        if argv_out_p != 0 {
            # Node contract: fill ALL req_in slots — actual args first, then
            # `undefined` padding. Callers (napi-rs Option<T> params) read
            # slots past the actual argc and must see undefined, not stack
            # garbage (garbage there surfaced as "Wrap AbortSignal failed"
            # on rollup's parseAsync optional signal argument).
            ai: int = 0;
            while ai < req_in {
                slot: int = argv_out_p + ai * 8;
                val_ai: int = js_undefined();
                if ai < _cbinfo_argc and ai < len(_cbinfo_args) {
                    val_ai = _cbinfo_args[ai];
                }
                _napi_write_i64(slot, val_ai);
                ai = ai + 1;
            }
        }
        _napi_write_i64(argc_ptr, _cbinfo_argc);  # write actual count last
    }
    if this_ptr != 0 {
        _napi_write_i64(this_ptr, _cbinfo_this);
    }
    if data_ptr != 0 {
        _napi_write_i64(data_ptr, _cbinfo_data);
    }
    return NAPI_OK;
}

# ── Op 74 — napi_get_new_target ───────────────────────────────────────────────
# argv[0]=env, argv[1]=cbinfo (ignored), argv[2]=result (napi_value*)

def _h_get_new_target(argv: int) -> int {
    result_p: int = _napi_argv_i64(argv, 2);
    if result_p != 0 {
        _napi_write_i64(result_p, _cbinfo_new_target);
    }
    return NAPI_OK;
}

# ── Op 75 — napi_define_class ─────────────────────────────────────────────────
# argv[0]=env, argv[1]=utf8name, argv[2]=length, argv[3]=ctor_cb,
# argv[4]=data, argv[5]=prop_count, argv[6]=props (napi_property_descriptor*),
# argv[7]=result (napi_value*)
#
# napi_property_descriptor layout (64-bit, 8 bytes each):
#   [0] utf8name ptr, [1] name napi_value, [2] method cb,
#   [3] getter cb,    [4] setter cb,       [5] value napi_value,
#   [6] attributes (uint32 packed),         [7] data ptr

def _h_define_class(argv: int) -> int {
    name_ptr: int = _napi_argv_i64(argv, 1);
    ctor_cb: int = _napi_argv_i64(argv, 3);
    data_ptr: int = _napi_argv_i64(argv, 4);
    prop_count: int = _napi_argv_i64(argv, 5);
    props_ptr: int = _napi_argv_i64(argv, 6);
    result_p: int = _napi_argv_i64(argv, 7);
    if ctor_cb == 0 or result_p == 0 {
        return NAPI_INVALID_ARG;
    }
    name: str = _read_cstr_nf(name_ptr);
    if name == "" {
        name = "constructor";
    }
    # Create constructor NAPI closure
    ctor_val: int = _napi_make_closure(name, ctor_cb, data_ptr);
    # Create prototype object and wire constructor.prototype <-> prototype.constructor
    proto: int = js_object_create_null();
    r: Realm = _napi_get_realm();
    ctor_idx: int = jsv_to_table_id(ctor_val);
    if ctor_idx >= 0 and ctor_idx < len(r.closures) {
        r.closures[ctor_idx].prototype_obj = proto;
    }
    ctor_str_key: int = str_intern("constructor");
    js_object_set(proto, ctor_str_key, ctor_val);
    # napi_property_descriptor layout (64 bytes, 8-byte fields):
    #   [0] utf8name*, [1] name jsv, [2] method cb, [3] getter cb, [4] setter cb,
    #   [5] value jsv, attrs=read_u32(+48), [7] data ptr
    struct_size: int = 64;
    NAPI_STATIC_FLAG: int = 1024;  # napi_static = 1 << 10 — property on ctor, not proto
    pi: int = 0;
    while pi < prop_count {
        base: int = props_ptr + pi * struct_size;
        pname_ptr: int = _napi_argv_i64(base, 0);
        pname_jsv: int = _napi_argv_i64(base, 1);
        method_cb: int = _napi_argv_i64(base, 2);
        # getter_cb / setter_cb (indices 3, 4): not yet implemented
        value_jsv: int = _napi_argv_i64(base, 5);
        attrs: int = read_u32(base, 48);  # napi_property_attributes (uint32)
        pdata_ptr: int = _napi_argv_i64(base, 7);  # per-property data pointer
        is_static: bool = (attrs & NAPI_STATIC_FLAG) != 0;
        # Resolve property key
        prop_key: int = 0;
        if pname_ptr != 0 {
            pname_str: str = _read_cstr_nf(pname_ptr);
            prop_key = str_intern(pname_str);
        } elif jsv_is_string_cell(pname_jsv) or jsv_is_symbol(pname_jsv) {
            prop_key = jsv_to_table_id(pname_jsv);
        }
        if prop_key != 0 {
            if method_cb != 0 {
                method_name: str = _read_cstr_nf(pname_ptr);
                method_val: int = _napi_make_closure(method_name, method_cb, pdata_ptr);
                if is_static {
                    # Static method: goes on the constructor's fn_props JSObject
                    cl_ctor: JSClosure = r.closures[ctor_idx];
                    js_object_set(cl_ctor.fn_props, prop_key, method_val);
                } else {
                    js_object_set(proto, prop_key, method_val);
                }
            } elif not jsv_is_undefined(value_jsv) {
                if is_static {
                    cl_ctor2: JSClosure = r.closures[ctor_idx];
                    js_object_set(cl_ctor2.fn_props, prop_key, value_jsv);
                } else {
                    js_object_set(proto, prop_key, value_jsv);
                }
            }
        }
        pi = pi + 1;
    }
    _napi_write_i64(result_p, ctor_val);
    return NAPI_OK;
}

# ── Op 76 — napi_wrap ────────────────────────────────────────────────────────
# argv[0]=env, argv[1]=js_object, argv[2]=native_ptr,
# argv[3]=finalize_cb, argv[4]=hint: not used; argv[5]=ref_out

def _h_wrap(argv: int) -> int {
    js_obj: int = _napi_argv_i64(argv, 1);
    native_ptr: int = _napi_argv_i64(argv, 2);
    if not jsv_is_object_cell(js_obj) {
        return NAPI_INVALID_ARG;
    }
    js_object_set(js_obj, _KEY_NAPI_WRAP, native_ptr);
    return NAPI_OK;
}

# ── Op 77 — napi_unwrap ──────────────────────────────────────────────────────
# argv[0]=env, argv[1]=js_object, argv[2]=result (void**)

def _h_unwrap(argv: int) -> int {
    js_obj: int = _napi_argv_i64(argv, 1);
    result_p: int = _napi_argv_i64(argv, 2);
    if not jsv_is_object_cell(js_obj) {
        return NAPI_INVALID_ARG;
    }
    if not js_object_has_own(js_obj, _KEY_NAPI_WRAP) {
        return NAPI_INVALID_ARG;
    }
    ptr: int = js_object_get(js_obj, _KEY_NAPI_WRAP);
    if result_p != 0 {
        _napi_write_i64(result_p, ptr);
    }
    return NAPI_OK;
}

# ── Op 78 — napi_remove_wrap ─────────────────────────────────────────────────
# argv[0]=env, argv[1]=js_object, argv[2]=result (void**)

def _h_remove_wrap(argv: int) -> int {
    js_obj: int = _napi_argv_i64(argv, 1);
    result_p: int = _napi_argv_i64(argv, 2);
    if not jsv_is_object_cell(js_obj) {
        return NAPI_INVALID_ARG;
    }
    ptr: int = js_object_get(js_obj, _KEY_NAPI_WRAP);
    js_object_delete(js_obj, _KEY_NAPI_WRAP);
    if result_p != 0 {
        _napi_write_i64(result_p, ptr);
    }
    return NAPI_OK;
}

# ── Op 79 — napi_add_finalizer ───────────────────────────────────────────────
# argv[0]=env, argv[1]=js_object, argv[2]=native_ptr,
# argv[3]=finalize_cb, argv[4]=hint, argv[5]=ref_out

def _h_add_finalizer(argv: int) -> int {
    # napi_add_finalizer registers a callback to fire when the JS object is GC'd.
    # Under reference-count GC there is no deferred finalization notification;
    # calling the finalizer at object creation time would be wrong
    # (the native data is still live and owned by the caller).
    return NAPI_OK;
}

# ── Op 80 — napi_instanceof ──────────────────────────────────────────────────
# argv[0]=env, argv[1]=object, argv[2]=constructor, argv[3]=result (bool*)

def _h_instanceof(argv: int) -> int {
    obj_v: int = _napi_argv_i64(argv, 1);
    ctor_v: int = _napi_argv_i64(argv, 2);
    result_p: int = _napi_argv_i64(argv, 3);
    # Get constructor.prototype
    ctor_proto: int = js_undefined();
    if _is_fn_val(ctor_v) {
        r_ii: Realm = _napi_get_realm();
        fn_idx_ii: int = jsv_to_table_id(ctor_v);
        if fn_idx_ii < len(r_ii.closures) {
            ctor_proto = r_ii.closures[fn_idx_ii].prototype_obj;
        }
    } elif jsv_is_object_cell(ctor_v) {
        proto_key: int = str_intern("prototype");
        ctor_proto = js_object_get(ctor_v, proto_key);
    }
    # Walk prototype chain
    found: bool = False;
    if jsv_is_object_cell(ctor_proto) {
        cur: int = obj_v;
        step: int = 0;
        while step < 100 {
            step = step + 1;
            cur_proto: int = js_object_get_prototype(cur);
            if jsv_is_null(cur_proto) or jsv_is_undefined(cur_proto) {
                break;
            }
            if jsv_to_table_id(cur_proto) == jsv_to_table_id(ctor_proto) {
                found = True;
                break;
            }
            cur = cur_proto;
        }
    }
    if result_p != 0 {
        _napi_write_bool(result_p, int(found));
    }
    return NAPI_OK;
}

# ── Op 81 — napi_create_external ─────────────────────────────────────────────
# argv[0]=env, argv[1]=data (void*), argv[2]=finalize_cb,
# argv[3]=hint, argv[4]=result (napi_value*)

def _h_create_external(argv: int) -> int {
    data_ptr: int = _napi_argv_i64(argv, 1);
    # finalize_cb and hint are accepted but ignored under RC-GC (no deferred finalization).
    result_p: int = _napi_argv_i64(argv, 4);
    if result_p == 0 {
        return NAPI_INVALID_ARG;
    }
    ext_obj: int = js_object_create_null();
    js_object_set(ext_obj, _KEY_NAPI_EXT_DATA, data_ptr);
    js_object_set(ext_obj, _KEY_NAPI_IS_EXT, js_true());
    _napi_write_i64(result_p, ext_obj);
    return NAPI_OK;
}

# ── Op 82 — napi_get_value_external ─────────────────────────────────────────
# argv[0]=env, argv[1]=value (napi_value), argv[2]=result (void**)

def _h_get_value_external(argv: int) -> int {
    value_v: int = _napi_argv_i64(argv, 1);
    result_p: int = _napi_argv_i64(argv, 2);
    if not jsv_is_object_cell(value_v) {
        return NAPI_INVALID_ARG;
    }
    if not js_object_has_own(value_v, _KEY_NAPI_IS_EXT) {
        return NAPI_INVALID_ARG;
    }
    data_ptr: int = js_object_get(value_v, _KEY_NAPI_EXT_DATA);
    if result_p != 0 {
        _napi_write_i64(result_p, data_ptr);
    }
    return NAPI_OK;
}

# ── Op 83 — napi_create_promise ──────────────────────────────────────────────
# argv[0]=env, argv[1]=deferred_out (napi_deferred*), argv[2]=promise_out

def _h_create_promise(argv: int) -> int {
    deferred_p: int = _napi_argv_i64(argv, 1);
    promise_p: int = _napi_argv_i64(argv, 2);
    if deferred_p == 0 or promise_p == 0 {
        return NAPI_INVALID_ARG;
    }
    p: JSValue = js_promise_create();
    # Create a deferred object that holds the promise reference
    deferred_obj: int = js_object_create_null();
    js_object_set(deferred_obj, _KEY_NAPI_DEFERRED_PROMISE, p);
    # The native caller keeps `deferred_obj` only as a raw i64 (napi_deferred
    # handle); the precise GC mark cannot enumerate it, so a collection between
    # create_promise and resolve/reject would sweep it (and its promise) while
    # live — surfacing as NAPI_INVALID_ARG in _h_resolve_deferred. Pin it (which
    # transitively roots the promise) until the deferred is settled. This
    # mirrors Node's persistent-reference-until-settled semantics.
    gc_pin_value(deferred_obj);
    _napi_write_i64(deferred_p, deferred_obj);
    _napi_write_i64(promise_p, p);
    return NAPI_OK;
}

# ── Op 84 — napi_resolve_deferred ────────────────────────────────────────────
# argv[0]=env, argv[1]=deferred (napi_deferred = JSValue of deferred object),
# argv[2]=resolution (napi_value)

def _h_resolve_deferred(argv: int) -> int {
    deferred_v: int = _napi_argv_i64(argv, 1);
    resolution: int = _napi_argv_i64(argv, 2);
    if not jsv_is_object_cell(deferred_v) {
        return NAPI_INVALID_ARG;
    }
    p: JSValue = js_object_get(deferred_v, _KEY_NAPI_DEFERRED_PROMISE);
    if jsv_is_undefined(p) {
        return NAPI_INVALID_ARG;
    }
    _napi_promise_settle(p, PROMISE_FULFILLED, resolution);
    # Settled: reactions are enqueued on the (GC-traced) microtask queue, so the
    # promise stays reachable; release the create-time pin on the deferred.
    gc_unpin_value(deferred_v);
    return NAPI_OK;
}

# ── Op 85 — napi_reject_deferred ─────────────────────────────────────────────
# argv[0]=env, argv[1]=deferred (napi_deferred), argv[2]=rejection (napi_value)

def _h_reject_deferred(argv: int) -> int {
    deferred_v: int = _napi_argv_i64(argv, 1);
    rejection: int = _napi_argv_i64(argv, 2);
    if not jsv_is_object_cell(deferred_v) {
        return NAPI_INVALID_ARG;
    }
    p: JSValue = js_object_get(deferred_v, _KEY_NAPI_DEFERRED_PROMISE);
    if jsv_is_undefined(p) {
        return NAPI_INVALID_ARG;
    }
    _napi_promise_settle(p, PROMISE_REJECTED, rejection);
    # Settled (rejected): release the create-time pin on the deferred; the
    # rejection reaction is enqueued on the GC-traced microtask queue.
    gc_unpin_value(deferred_v);
    return NAPI_OK;
}

# ── Sub-dispatcher ────────────────────────────────────────────────────────────

"""Route ops 70–85 (functions, classes, wrap, promise) to their handlers.
Called by _napi_dispatch in napi_dispatch.na.jac."""
def:pub _dispatch_func(op: int, argv: int) -> int {
    if op == NAPI_OP_CREATE_FUNCTION {
        return _h_create_function(argv);
    } elif op == NAPI_OP_CALL_FUNCTION {
        return _h_call_function(argv);
    } elif op == NAPI_OP_NEW_INSTANCE {
        return _h_new_instance(argv);
    } elif op == NAPI_OP_GET_CB_INFO {
        return _h_get_cb_info(argv);
    } elif op == NAPI_OP_GET_NEW_TARGET {
        return _h_get_new_target(argv);
    } elif op == NAPI_OP_DEFINE_CLASS {
        return _h_define_class(argv);
    } elif op == NAPI_OP_WRAP {
        return _h_wrap(argv);
    } elif op == NAPI_OP_UNWRAP {
        return _h_unwrap(argv);
    } elif op == NAPI_OP_REMOVE_WRAP {
        return _h_remove_wrap(argv);
    } elif op == NAPI_OP_ADD_FINALIZER {
        return _h_add_finalizer(argv);
    } elif op == NAPI_OP_INSTANCEOF {
        return _h_instanceof(argv);
    } elif op == NAPI_OP_CREATE_EXTERNAL {
        return _h_create_external(argv);
    } elif op == NAPI_OP_GET_VALUE_EXTERNAL {
        return _h_get_value_external(argv);
    } elif op == NAPI_OP_CREATE_PROMISE {
        return _h_create_promise(argv);
    } elif op == NAPI_OP_RESOLVE_DEFERRED {
        return _h_resolve_deferred(argv);
    } elif op == NAPI_OP_REJECT_DEFERRED {
        return _h_reject_deferred(argv);
    }
    # Buffers / TypedArrays / DataViews (ops 86–97) — napi_binary.na.jac
    elif op >= NAPI_OP_CREATE_ARRAYBUFFER and op <= NAPI_OP_GET_BUFFER_INFO {
        return _dispatch_binary(op, argv);
    }
    # Errors, references, BigInt, cleanup hooks (ops 98–124)
    elif op >= 98 and op <= 124 {
        return _dispatch_errors(op, argv);
    }
    return NAPI_GENERIC_FAILURE;
}
