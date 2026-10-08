"""Function-object [[Prototype]] helpers for JS closures (TypedArray ctor chain, etc.)."""

import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    js_null,
    jsv_is_cell,
    jsv_cell_kind,
    jsv_to_table_id,
    JS_CELL_KIND_NATIVE,
    jsv_is_undefined,
    jsv_is_object_cell,
    jsv_is_null,
    jsv_is_any_object
}
import from engine.src.vm.closure_type { JSClosure }

glob _FN_META_CLOSURES: list[JSClosure] = [];

"""Bind the active realm closure table (called from VM bootstrap)."""
def:pub fn_meta_bind_closures(closures: list[JSClosure]) {
    _FN_META_CLOSURES = closures;
}

def:pub fn_meta_is_closure(v: JSValue) -> bool {
    if not jsv_is_cell(v) {
        return False;
    }
    if jsv_cell_kind(v) != JS_CELL_KIND_NATIVE {
        return False;
    }
    return jsv_to_table_id(v) < 1073741824;  # FN_BUILTIN_BASE (runtime/encoding.jac)
}

def:pub fn_meta_closure_idx(v: JSValue) -> int {
    return jsv_to_table_id(v);
}

"""Return closure.object_proto, or undefined if unset (caller applies default)."""
def:pub fn_meta_get_object_proto(v: JSValue) -> JSValue {
    idx: int = fn_meta_closure_idx(v);
    if idx < 0 or idx >= len(_FN_META_CLOSURES) {
        return js_undefined();
    }
    return _FN_META_CLOSURES[idx].object_proto;
}

"""
Set closure.object_proto. Returns 0 on success, 1 if proto invalid or idx OOB.
"""
def:pub fn_meta_set_object_proto(v: JSValue, proto: JSValue) -> int {
    # A valid [[Prototype]] is null OR any object; functions ARE objects, so a
    # function/closure proto (e.g. `setPrototypeOf(Uint8Array, TypedArray)`) is
    # valid too. `object_proto` is a plain JSValue and can hold a closure.
    if not (
        jsv_is_null(proto) or jsv_is_any_object(proto) or fn_meta_is_closure(proto)
    ) {
        return 1;
    }
    idx: int = fn_meta_closure_idx(v);
    if idx < 0 or idx >= len(_FN_META_CLOSURES) {
        return 1;
    }
    _FN_META_CLOSURES[idx].object_proto = proto;
    return 0;
}

"""Return the closure's fn_props bag, or undefined if v is not a live closure."""
def:pub fn_meta_get_fn_props(v: JSValue) -> JSValue {
    if not fn_meta_is_closure(v) {
        return js_undefined();
    }
    idx: int = fn_meta_closure_idx(v);
    if idx < 0 or idx >= len(_FN_META_CLOSURES) {
        return js_undefined();
    }
    return _FN_META_CLOSURES[idx].fn_props;
}

"""Builtin [[Class]] tag for user closures (Object.prototype.toString)."""
def:pub fn_meta_builtin_to_string_tag(v: JSValue) -> str {
    if not fn_meta_is_closure(v) {
        return "";
    }
    idx: int = fn_meta_closure_idx(v);
    if idx < 0 or idx >= len(_FN_META_CLOSURES) {
        return "Function";
    }
    cl: JSClosure = _FN_META_CLOSURES[idx];
    if cl.func.is_generator and cl.func.is_async {
        return "AsyncGeneratorFunction";
    }
    if cl.func.is_generator {
        return "GeneratorFunction";
    }
    if cl.func.is_async {
        return "AsyncFunction";
    }
    return "Function";
}
