"""Observable property access for native builtins (Issue #15).

Uses a dispatch-table-style Callable registry (same pattern as call_native)
so the VM module can register typed implementations without import cycles
or duck-typing through `object`.
"""

import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    MATH_NAN,
    jsv_is_object_cell,
    jsv_is_any_object,
    jsv_coerce_to_number,
    jsv_is_string_cell,
    jsv_to_table_id,
    jsv_is_int32,
    jsv_to_int32,
    jsv_is_double,
    jsv_to_double,
    jsv_is_bool,
    jsv_to_bool,
    jsv_is_undefined,
    jsv_is_null,
    jsv_is_symbol
}
import from engine.src.runtime.jsstring { str_from_id, str_intern }
import from engine.src.runtime.dtoa { number_to_string_radix10 }
import from engine.src.runtime.jssymbol { SYMBOL_KEY_BASE }
import from engine.src.runtime.obs_context {
    obs_set_vm_handle,
    obs_get_vm_handle,
    obs_is_active
}
import from engine.src.runtime.jsobject {
    js_object_get,
    js_object_set,
    js_object_has,
    js_object_delete
}

# Single-slot tables — same Callable-in-dict pattern as _DISPATCH_TABLE.
glob _OBS_GET_TABLE: dict[int, Callable[[JSValue, int, JSValue], JSValue]] = {},
     _OBS_SET_TABLE: dict[int, Callable[[JSValue, int, JSValue, JSValue], bool]] = {},
     _OBS_HAS_TABLE: dict[int, Callable[[JSValue, int], bool]] = {},
     _OBS_DEL_TABLE: dict[int, Callable[[JSValue, int], bool]] = {},
     _OBS_TONUM_TABLE: dict[int, Callable[[JSValue], float]] = {},
     _OBS_TOSTR_TABLE: dict[int, Callable[[JSValue], str]] = {},
     _OBS_TPK_TABLE: dict[int, Callable[[JSValue], int]] = {},
     _OBS_TOPRIM_TABLE: dict[int, Callable[[JSValue, int], JSValue]] = {},
     _OBS_CALL_TABLE: dict[int, Callable[[JSValue, JSValue, list[JSValue]], JSValue]] = {},
     _OBS_IMPL_READY: bool = False;

"""Register VM-backed observable implementations (called once at startup)."""
def:pub js_object_register_obs_impl(
    get_cb: Callable[[JSValue, int, JSValue], JSValue],
    set_cb: Callable[[JSValue, int, JSValue, JSValue], bool],
    has_cb: Callable[[JSValue, int], bool],
    del_cb: Callable[[JSValue, int], bool],
    tonum_cb: Callable[[JSValue], float],
    tostr_cb: Callable[[JSValue], str],
    tpk_cb: Callable[[JSValue], int] = None,
    toprim_cb: Callable[[JSValue, int], JSValue] = None,
    call_cb: Callable[[JSValue, JSValue, list[JSValue]], JSValue] = None
) {
    _OBS_GET_TABLE = {};
    _OBS_SET_TABLE = {};
    _OBS_HAS_TABLE = {};
    _OBS_DEL_TABLE = {};
    _OBS_TONUM_TABLE = {};
    _OBS_TOSTR_TABLE = {};
    _OBS_TPK_TABLE = {};
    _OBS_TOPRIM_TABLE = {};
    _OBS_CALL_TABLE = {};
    _OBS_GET_TABLE[0] = get_cb;
    _OBS_SET_TABLE[0] = set_cb;
    _OBS_HAS_TABLE[0] = has_cb;
    _OBS_DEL_TABLE[0] = del_cb;
    _OBS_TONUM_TABLE[0] = tonum_cb;
    _OBS_TOSTR_TABLE[0] = tostr_cb;
    if tpk_cb is not None {
        _OBS_TPK_TABLE[0] = tpk_cb;
    }
    if toprim_cb is not None {
        _OBS_TOPRIM_TABLE[0] = toprim_cb;
    }
    if call_cb is not None {
        _OBS_CALL_TABLE[0] = call_cb;
    }
    _OBS_IMPL_READY = True;
}

"""
Call a JS callable `fn` with `this_val` and `args` from native builtin code —
the bridge that lets String.prototype.{match,replace,…} invoke a user
`@@match`/`@@replace` method or a function replaceValue. Requires an active VM
context; abrupt completions propagate via vm_has_native_exc. Returns undefined
if no VM/call impl is available (caller should guard with obs_is_active()).
"""
def:pub js_call_observable(
    fn: JSValue, this_val: JSValue, args: list[JSValue]
) -> JSValue {
    if obs_is_active() and _OBS_IMPL_READY and 0 in _OBS_CALL_TABLE {
        h: Callable[[JSValue, JSValue, list[JSValue]], JSValue] = _OBS_CALL_TABLE[0];
        return h(fn, this_val, args);
    }
    return js_undefined();
}

"""True when a VM call bridge is registered and active (native code may re-enter JS)."""
def:pub js_call_bridge_ready -> bool {
    return obs_is_active() and _OBS_IMPL_READY and (0 in _OBS_CALL_TABLE);
}

# ── WASM host-import callback registry (Phase 3) ──────────────────────────────
# The JS import callbacks for the current instantiate live here (keyed by import
# index). Kept in vm_obs (not vm.na.jac) so the dispatch layer can register them
# without a dispatch→vm import cycle; vm.na.jac reads them from here in the
# host-call trampoline bridge.
glob _WASM_IMPORT_CBS: dict[int, JSValue] = {};

"""Register a JS callback for a host-import index (dispatch layer, at instantiate)."""
def:pub vm_wasm_register_import_cb(import_index: int, fn: JSValue) {
    _WASM_IMPORT_CBS[import_index] = fn;
}

"""Clear all registered import callbacks (fresh instantiate)."""
def:pub vm_wasm_clear_import_cbs {
    _WASM_IMPORT_CBS = {};
}

"""Look up the JS callback for a host-import index (js_undefined if none)."""
def:pub vm_wasm_get_import_cb(import_index: int) -> JSValue {
    if import_index in _WASM_IMPORT_CBS {
        return _WASM_IMPORT_CBS[import_index];
    }
    return js_undefined();
}

"""True if a callback is registered for the import index."""
def:pub vm_wasm_has_import_cb(import_index: int) -> bool {
    return import_index in _WASM_IMPORT_CBS;
}

# ToPrimitive hint constants shared with the VM-side impl.
glob:pub OBS_HINT_DEFAULT: int = 0,
     OBS_HINT_STRING: int = 1,
     OBS_HINT_NUMBER: int = 2;

"""Observable ToPrimitive(value, hint) for native builtins — invokes
@@toPrimitive with the right hint, else OrdinaryToPrimitive. Abrupt completions
propagate via vm_has_native_exc. Primitives pass through unchanged."""
def:pub js_to_primitive_observable(v: JSValue, hint: int) -> JSValue {
    if not jsv_is_any_object(v) {
        return v;
    }
    if obs_is_active() and _OBS_IMPL_READY and 0 in _OBS_TOPRIM_TABLE {
        h: Callable[[JSValue, int], JSValue] = _OBS_TOPRIM_TABLE[0];
        return h(v, hint);
    }
    # Non-observable fallback: objects have no side-effecting conversion here.
    return v;
}

"""Activate observable native context for the given VM handle (0 deactivates)."""
def:pub vm_obs_set_active_handle(handle: int) {
    obs_set_vm_handle(handle);
}

"""Register a VM instance; returns an opaque handle for obs_context."""
def:pub vm_obs_register_vm(vm: object) -> int {
    # Handle allocation lives in vm.na.jac (typed VM map). This stub exists
    # only so older call sites compile; real registration is vm_obs_register_vm_typed.
    return 0;
}

"""
Observable [[Get]] for native builtins — invokes accessors and Proxy get traps.
"""
def:pub js_object_get_observable(
    jsobj: JSValue, key: int, receiver: JSValue
) -> JSValue {
    if obs_is_active() and _OBS_IMPL_READY {
        h: Callable[[JSValue, int, JSValue], JSValue] = _OBS_GET_TABLE[0];
        return h(jsobj, key, receiver);
    }
    return js_object_get(jsobj, key);
}

"""Observable [[Set]] for native builtins."""
def:pub js_object_set_observable(
    jsobj: JSValue, key: int, val: JSValue, receiver: JSValue
) -> bool {
    if obs_is_active() and _OBS_IMPL_READY {
        h: Callable[[JSValue, int, JSValue, JSValue], bool] = _OBS_SET_TABLE[0];
        return h(jsobj, key, val, receiver);
    }
    return js_object_set(jsobj, key, val) == 0;
}

"""Observable [[HasProperty]] for native builtins."""
def:pub js_object_has_observable(jsobj: JSValue, key: int) -> bool {
    if obs_is_active() and _OBS_IMPL_READY {
        h: Callable[[JSValue, int], bool] = _OBS_HAS_TABLE[0];
        return h(jsobj, key);
    }
    return js_object_has(jsobj, key);
}

"""Observable [[Delete]] for native builtins — Proxy deleteProperty traps."""
def:pub js_object_delete_observable(jsobj: JSValue, key: int) -> bool {
    if obs_is_active() and _OBS_IMPL_READY {
        h: Callable[[JSValue, int], bool] = _OBS_DEL_TABLE[0];
        return h(jsobj, key);
    }
    return js_object_delete(jsobj, key);
}

"""
Observable ToNumber for native builtins — OrdinaryToPrimitive(number) then
ToNumber, so valueOf/toString throws propagate via vm_has_native_exc.
"""
def:pub js_to_number_observable(v: JSValue) -> float {
    if obs_is_active() and _OBS_IMPL_READY {
        h: Callable[[JSValue], float] = _OBS_TONUM_TABLE[0];
        return h(v);
    }
    # Non-observable fallback: ToNumber of ANY object — including functions,
    # which are NATIVE cells rather than object cells — is NaN, not 0.
    # jsv_coerce_to_number returns 0.0 for values it does not recognise, so a
    # function slipped through as 0 and made isNaN(function(){}) false.
    if jsv_is_any_object(v) {
        return MATH_NAN;
    }
    return jsv_coerce_to_number(v);
}

def _obs_fallback_str(v: JSValue) -> str {
    if jsv_is_string_cell(v) {
        return str_from_id(jsv_to_table_id(v));
    }
    if jsv_is_int32(v) {
        return str(jsv_to_int32(v));
    }
    if jsv_is_double(v) {
        return str(jsv_to_double(v));
    }
    if jsv_is_bool(v) {
        if jsv_to_bool(v) {
            return "true";
        }
        return "false";
    }
    if jsv_is_null(v) {
        return "null";
    }
    if jsv_is_undefined(v) {
        return "undefined";
    }
    return "";
}

"""
Observable ToString for native builtins — OrdinaryToPrimitive("string") then
ToString, so toString/valueOf throws propagate via vm_has_native_exc.
"""
def:pub js_to_string_observable(v: JSValue) -> str {
    if obs_is_active() and _OBS_IMPL_READY {
        h: Callable[[JSValue], str] = _OBS_TOSTR_TABLE[0];
        return h(v);
    }
    return _obs_fallback_str(v);
}

"""
Observable ToPropertyKey for native builtins — Symbol primitives stay symbols;
objects run ToPrimitive(string) / @@toPrimitive (incl. Symbol wrapper objects).
"""
def:pub js_to_property_key_observable(v: JSValue) -> int {
    if jsv_is_symbol(v) {
        return SYMBOL_KEY_BASE + jsv_to_table_id(v);
    }
    if jsv_is_string_cell(v) {
        return jsv_to_table_id(v);
    }
    if jsv_is_int32(v) {
        return str_intern(str(jsv_to_int32(v)));
    }
    if jsv_is_double(v) {
        return str_intern(number_to_string_radix10(jsv_to_double(v)));
    }
    if obs_is_active() and _OBS_IMPL_READY and len(_OBS_TPK_TABLE) > 0 {
        h: Callable[[JSValue], int] = _OBS_TPK_TABLE[0];
        return h(v);
    }
    if jsv_is_object_cell(v) {
        pk: int = str_intern("[[PrimitiveValue]]");
        if js_object_has(v, pk) {
            inner: JSValue = js_object_get(v, pk);
            if jsv_is_symbol(inner) {
                return SYMBOL_KEY_BASE + jsv_to_table_id(inner);
            }
        }
    }
    return str_intern(_obs_fallback_str(v));
}
