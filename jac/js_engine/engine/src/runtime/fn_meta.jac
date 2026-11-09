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
import from engine.src.vm.closure_type {
    _JC_FUNC,
    jc_count,
    jc_fn_props,
    jc_object_proto,
    jc_set_fn_props,
    jc_set_object_proto,
    jc_wb
}
import from engine.src.runtime.jsobject { js_object_create_null, js_object_get, js_object_has_own }


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
    if idx < 0 or idx >= jc_count() {
        return js_undefined();
    }
    return jc_object_proto(idx);
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
    if idx < 0 or idx >= jc_count() {
        return 1;
    }
    jc_set_object_proto(idx, proto);
    jc_wb(idx, jc_object_proto(idx));
    return 0;
}

"""A closure's own-property bag (user properties, materialised name/length,
engine tags), created on first use: make_closure leaves fn_props undefined
because most closures never get one. Writers and anything that hands the bag
on use this; plain lookups use cl_props_get / cl_props_has_own."""
def:pub cl_props(cl: int) -> JSValue {
    if not jsv_is_object_cell(jc_fn_props(cl)) {
        jc_set_fn_props(cl, js_object_create_null());
        jc_wb(cl, jc_fn_props(cl));
    }
    return jc_fn_props(cl);
}

"""Own data value of `key` in the closure's bag (undefined when it has none)."""
def:pub cl_props_get(cl: int, key: int) -> JSValue {
    if not jsv_is_object_cell(jc_fn_props(cl)) {
        return js_undefined();
    }
    return js_object_get(jc_fn_props(cl), key);
}

"""Whether the closure's bag has own `key` (False when it has none)."""
def:pub cl_props_has_own(cl: int, key: int) -> bool {
    return jsv_is_object_cell(jc_fn_props(cl)) and js_object_has_own(jc_fn_props(cl), key);
}

"""Return the closure's fn_props bag, or undefined if v is not a live closure."""
def:pub fn_meta_get_fn_props(v: JSValue) -> JSValue {
    if not fn_meta_is_closure(v) {
        return js_undefined();
    }
    idx: int = fn_meta_closure_idx(v);
    if idx < 0 or idx >= jc_count() {
        return js_undefined();
    }
    return cl_props(idx);
}

"""Builtin [[Class]] tag for user closures (Object.prototype.toString)."""
def:pub fn_meta_builtin_to_string_tag(v: JSValue) -> str {
    if not fn_meta_is_closure(v) {
        return "";
    }
    idx: int = fn_meta_closure_idx(v);
    if idx < 0 or idx >= jc_count() {
        return "Function";
    }
    cl: int = idx;
    if _JC_FUNC[cl].is_generator and _JC_FUNC[cl].is_async {
        return "AsyncGeneratorFunction";
    }
    if _JC_FUNC[cl].is_generator {
        return "GeneratorFunction";
    }
    if _JC_FUNC[cl].is_async {
        return "AsyncFunction";
    }
    return "Function";
}
