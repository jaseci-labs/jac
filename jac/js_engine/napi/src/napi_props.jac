"""NAPI props handlers.

Implements NAPI op handlers for:
  • Object / array creation  (ops 42–44)
  • Property get/set/has/del (ops 47–54)
  • Array element ops        (ops 55–59)
  • Property enumeration     (ops 60–61)
  • napi_define_properties   (op  62)
  • Prototype / freeze / seal(ops 63–65)
  • Type coercions           (ops 66–69)

napi_property_descriptor layout (x86-64, 64 bytes):
  offset  0: const char* utf8name   (8 bytes)
  offset  8: napi_value  name       (8 bytes)
  offset 16: napi_callback method   (8 bytes)
  offset 24: napi_callback getter   (8 bytes)
  offset 32: napi_callback setter   (8 bytes)
  offset 40: napi_value  value      (8 bytes)
  offset 48: uint32_t    attributes (4 bytes)
  offset 52: padding                (4 bytes)
  offset 56: void*       data       (8 bytes)

napi_property_attributes (matches PROP_* flags exactly):
  napi_writable    = 1  == PROP_WRITABLE
  napi_enumerable  = 2  == PROP_ENUMERABLE
  napi_configurable= 4  == PROP_CONFIGURABLE
  napi_static      = 1024 (define_class; ignored for define_properties)
  napi_default_method = 7 = PROP_DEFAULT

Bun reference:
  bun/src/bun.js/bindings/JSObject.zig (napi_define_properties)
  bun/src/bun.js/bindings/JSValue.zig  (coercions)
"""

import from "libjs_native.so" {
    def _napi_argv_i64(argv: int, idx: int) -> int;  def _napi_write_i64(
        p: int, v: int
    ) -> int;  def _napi_write_u32(p: int, v: int) -> int;  def _napi_write_bool(
        p: int, v: int
    ) -> int;
}

import from engine.src.runtime.jsvalue {
    jsv_undefined,
    jsv_null,
    jsv_is_undefined,
    jsv_is_string_cell,
    jsv_is_symbol,
    jsv_is_number,
    jsv_is_bool,
    jsv_is_cell,
    jsv_is_object_cell,
    jsv_to_table_id,
    jsv_from_string_id,
    jsv_from_double,
    jsv_from_bool,
    jsv_coerce_to_bool,
    jsv_coerce_to_number,
    jsv_coerce_to_str
}

import from engine.src.runtime.jsobject {
    js_object_new_ordinary,
    js_object_get,
    js_object_set,
    js_object_set_flags,
    js_object_has_own,
    js_object_has,
    js_object_delete,
    js_object_keys,
    js_object_all_keys,
    js_object_get_prototype,
    js_object_freeze,
    js_object_prevent_extensions,
    js_object_define_property,
    js_object_set_accessor_getter,
    js_object_set_accessor_setter,
    js_object_set_accessor_enumerable,
    js_object_set_accessor_configurable
}
import from engine.src.vm.vm_obs {
    js_object_get_observable,
    js_object_set_observable,
    js_object_has_observable,
    js_to_string_observable
}

import from engine.src.runtime.error { vm_has_native_exc }

import from engine.src.runtime.jsobj_type {
    JSProperty,
    PROP_WRITABLE,
    PROP_ENUMERABLE,
    PROP_CONFIGURABLE,
    PROP_DEFAULT
}

import from engine.src.runtime.jsstring { str_intern, str_from_id }

import from engine.src.runtime.mem { read_byte, read_ptr, read_u32, byte_chr }

import from engine.src.builtins.array {
    js_array_create,
    js_array_get,
    js_array_set,
    js_array_len,
    js_is_array
}

import from napi.src.napi_ops {
    NAPI_OK,
    NAPI_INVALID_ARG,
    NAPI_OBJECT_EXPECTED,
    NAPI_GENERIC_FAILURE,
    NAPI_PENDING_EXCEPTION,
    NAPI_OP_CREATE_OBJECT,
    NAPI_OP_CREATE_ARRAY,
    NAPI_OP_CREATE_ARRAY_WITH_LENGTH,
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
    NAPI_OP_COERCE_TO_STRING
}

import from napi.src.napi_func { _napi_make_closure }

# ── Local implementation constants ───────────────────────────────────────────

# napi_key_collection_mode
glob _KEY_INCLUDE_PROTOS: int = 0,
     _KEY_OWN_ONLY: int = 1,
     _PD_UTF8NAME: int = 0,
     _PD_NAME: int = 8,
     _PD_METHOD: int = 16,
     _PD_GETTER: int = 24,
     _PD_SETTER: int = 32,
     _PD_VALUE: int = 40,
     _PD_ATTRIBUTES: int = 48,
     _PD_DATA: int = 56,
     _PD_SIZE: int = 64;

# napi_property_descriptor field offsets (bytes)

# sizeof(napi_property_descriptor)
# ── Helpers ──────────────────────────────────────────────────────────────────

"""Read a null-terminated UTF-8 string from ptr into a Jac str.
Stops at the first zero byte.  For property names (typically ASCII)."""
def _read_cstr(ptr: int) -> str {
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

"""Extract a string-intern key ID from a napi_value (JSValue).
Handles strings and symbols.  Returns -1 for unsupported key types."""
def _key_id_from_jsv(jsval: int) -> int {
    if jsv_is_string_cell(jsval) {
        return jsv_to_table_id(jsval);
    }
    if jsv_is_symbol(jsval) {
        return jsv_to_table_id(jsval);
    }
    # Number or other: coerce to string representation
    if jsv_is_number(jsval) {
        s: str = jsv_coerce_to_str(jsval);
        return str_intern(s);
    }
    return -1;
}

"""Build a JS Array of string JSValues from a list of intern IDs."""
def _ids_to_array(ids: list[int]) -> int {
    elems: list[int] = [];
    for kid in ids {
        elems.append(jsv_from_string_id(kid));
    }
    return js_array_create(elems);
}

# ── Object / array creation (ops 42–44) ─────────────────────────────────────

"""napi_create_object: argv[0]=env, argv[1]=napi_value* out."""
def _h_create_object(argv: int) -> int {
    result_ptr: int = _napi_argv_i64(argv, 1);
    jsobj: int = js_object_new_ordinary();
    _napi_write_i64(result_ptr, jsobj);
    return NAPI_OK;
}

"""napi_create_array: argv[0]=env, argv[1]=napi_value* out."""
def _h_create_array(argv: int) -> int {
    result_ptr: int = _napi_argv_i64(argv, 1);
    empty: list[int] = [];
    arr: int = js_array_create(empty);
    _napi_write_i64(result_ptr, arr);
    return NAPI_OK;
}

"""napi_create_array_with_length: argv[0]=env, argv[1]=length, argv[2]=napi_value* out.
Creates a dense array with 'length' undefined slots."""
def _h_create_array_with_length(argv: int) -> int {
    length: int = _napi_argv_i64(argv, 1);
    result_ptr: int = _napi_argv_i64(argv, 2);
    elems: list[int] = [];
    i: int = 0;
    undef: int = jsv_undefined();
    while i < length {
        elems.append(undef);
        i = i + 1;
    }
    arr: int = js_array_create(elems);
    _napi_write_i64(result_ptr, arr);
    return NAPI_OK;
}

# ── Property get/set/has/delete — JSValue key (ops 47–50, 54) ───────────────

"""napi_get_property: argv[0]=env, argv[1]=object, argv[2]=key, argv[3]=out."""
def _h_get_property(argv: int) -> int {
    jsobj: int = _napi_argv_i64(argv, 1);
    key_jsv: int = _napi_argv_i64(argv, 2);
    result_ptr: int = _napi_argv_i64(argv, 3);
    if not jsv_is_object_cell(jsobj) {
        return NAPI_OBJECT_EXPECTED;
    }
    kid: int = _key_id_from_jsv(key_jsv);
    if kid < 0 {
        return NAPI_INVALID_ARG;
    }
    val: int = js_object_get_observable(jsobj, kid, jsobj);
    if vm_has_native_exc() {
        return NAPI_PENDING_EXCEPTION;
    }
    key_str: str = str_from_id(kid);
    _napi_write_i64(result_ptr, val);
    return NAPI_OK;
}

"""napi_set_property: argv[0]=env, argv[1]=object, argv[2]=key, argv[3]=value."""
def _h_set_property(argv: int) -> int {
    jsobj: int = _napi_argv_i64(argv, 1);
    key_jsv: int = _napi_argv_i64(argv, 2);
    val: int = _napi_argv_i64(argv, 3);
    if not jsv_is_object_cell(jsobj) {
        return NAPI_OBJECT_EXPECTED;
    }
    kid: int = _key_id_from_jsv(key_jsv);
    if kid < 0 {
        return NAPI_INVALID_ARG;
    }
    js_object_set_observable(jsobj, kid, val, jsobj);
    if vm_has_native_exc() {
        return NAPI_PENDING_EXCEPTION;
    }
    return NAPI_OK;
}

"""napi_has_property: argv[0]=env, argv[1]=object, argv[2]=key, argv[3]=bool* out."""
def _h_has_property(argv: int) -> int {
    jsobj: int = _napi_argv_i64(argv, 1);
    key_jsv: int = _napi_argv_i64(argv, 2);
    result_ptr: int = _napi_argv_i64(argv, 3);
    if not jsv_is_object_cell(jsobj) {
        return NAPI_OBJECT_EXPECTED;
    }
    kid: int = _key_id_from_jsv(key_jsv);
    if kid < 0 {
        return NAPI_INVALID_ARG;
    }
    found: bool = js_object_has_observable(jsobj, kid);
    if vm_has_native_exc() {
        return NAPI_PENDING_EXCEPTION;
    }
    _napi_write_bool(result_ptr, int(found));
    return NAPI_OK;
}

"""napi_delete_property: argv[0]=env, argv[1]=object, argv[2]=key, argv[3]=bool* out."""
def _h_delete_property(argv: int) -> int {
    jsobj: int = _napi_argv_i64(argv, 1);
    key_jsv: int = _napi_argv_i64(argv, 2);
    result_ptr: int = _napi_argv_i64(argv, 3);
    if not jsv_is_object_cell(jsobj) {
        return NAPI_OBJECT_EXPECTED;
    }
    kid: int = _key_id_from_jsv(key_jsv);
    if kid < 0 {
        return NAPI_INVALID_ARG;
    }
    ok: bool = js_object_delete(jsobj, kid);
    _napi_write_bool(result_ptr, int(ok));
    return NAPI_OK;
}

"""napi_has_own_property: argv[0]=env, argv[1]=object, argv[2]=key, argv[3]=bool* out."""
def _h_has_own_property(argv: int) -> int {
    jsobj: int = _napi_argv_i64(argv, 1);
    key_jsv: int = _napi_argv_i64(argv, 2);
    result_ptr: int = _napi_argv_i64(argv, 3);
    if not jsv_is_object_cell(jsobj) {
        return NAPI_OBJECT_EXPECTED;
    }
    kid: int = _key_id_from_jsv(key_jsv);
    if kid < 0 {
        return NAPI_INVALID_ARG;
    }
    found: bool = js_object_has_own(jsobj, kid);
    _napi_write_bool(result_ptr, int(found));
    return NAPI_OK;
}

# ── Named property ops — const char* utf8name (ops 51–53) ───────────────────

"""napi_get_named_property: argv[0]=env, argv[1]=object, argv[2]=utf8name ptr, argv[3]=out."""
def _h_get_named_property(argv: int) -> int {
    jsobj: int = _napi_argv_i64(argv, 1);
    name_ptr: int = _napi_argv_i64(argv, 2);
    result_ptr: int = _napi_argv_i64(argv, 3);
    if not jsv_is_object_cell(jsobj) {
        name: str = _read_cstr(name_ptr);
        return NAPI_OBJECT_EXPECTED;
    }
    name: str = _read_cstr(name_ptr);
    kid: int = str_intern(name);
    val: int = js_object_get_observable(jsobj, kid, jsobj);
    if vm_has_native_exc() {
        return NAPI_PENDING_EXCEPTION;
    }
    _napi_write_i64(result_ptr, val);
    return NAPI_OK;
}

"""napi_set_named_property: argv[0]=env, argv[1]=object, argv[2]=utf8name ptr, argv[3]=value."""
def _h_set_named_property(argv: int) -> int {
    jsobj: int = _napi_argv_i64(argv, 1);
    name_ptr: int = _napi_argv_i64(argv, 2);
    val: int = _napi_argv_i64(argv, 3);
    if not jsv_is_object_cell(jsobj) {
        return NAPI_OBJECT_EXPECTED;
    }
    name: str = _read_cstr(name_ptr);
    kid: int = str_intern(name);
    js_object_set_observable(jsobj, kid, val, jsobj);
    if vm_has_native_exc() {
        return NAPI_PENDING_EXCEPTION;
    }
    return NAPI_OK;
}

"""napi_has_named_property: argv[0]=env, argv[1]=object, argv[2]=utf8name ptr, argv[3]=bool* out."""
def _h_has_named_property(argv: int) -> int {
    jsobj: int = _napi_argv_i64(argv, 1);
    name_ptr: int = _napi_argv_i64(argv, 2);
    result_ptr: int = _napi_argv_i64(argv, 3);
    if not jsv_is_object_cell(jsobj) {
        return NAPI_OBJECT_EXPECTED;
    }
    name: str = _read_cstr(name_ptr);
    kid: int = str_intern(name);
    found: bool = js_object_has_observable(jsobj, kid);
    if vm_has_native_exc() {
        return NAPI_PENDING_EXCEPTION;
    }
    _napi_write_bool(result_ptr, int(found));
    return NAPI_OK;
}

# ── Array element ops (ops 55–58) + get_array_length (op 59) ────────────────

"""napi_get_element: argv[0]=env, argv[1]=object, argv[2]=uint32 idx, argv[3]=out."""
def _h_get_element(argv: int) -> int {
    jsobj: int = _napi_argv_i64(argv, 1);
    idx: int = _napi_argv_i64(argv, 2);
    result_ptr: int = _napi_argv_i64(argv, 3);
    if not jsv_is_object_cell(jsobj) {
        return NAPI_OBJECT_EXPECTED;
    }
    val: int = 0;
    if js_is_array(jsobj) {
        val = js_array_get(jsobj, idx);
    } else {
        kid: int = str_intern(str(idx));
        val = js_object_get_observable(jsobj, kid, jsobj);
        if vm_has_native_exc() {
            return NAPI_PENDING_EXCEPTION;
        }
    }
    _napi_write_i64(result_ptr, val);
    return NAPI_OK;
}

"""napi_set_element: argv[0]=env, argv[1]=object, argv[2]=uint32 idx, argv[3]=value."""
def _h_set_element(argv: int) -> int {
    jsobj: int = _napi_argv_i64(argv, 1);
    idx: int = _napi_argv_i64(argv, 2);
    val: int = _napi_argv_i64(argv, 3);
    if not jsv_is_object_cell(jsobj) {
        return NAPI_OBJECT_EXPECTED;
    }
    if js_is_array(jsobj) {
        js_array_set(jsobj, idx, val);
    } else {
        kid: int = str_intern(str(idx));
        js_object_set_observable(jsobj, kid, val, jsobj);
        if vm_has_native_exc() {
            return NAPI_PENDING_EXCEPTION;
        }
    }
    return NAPI_OK;
}

"""napi_has_element: argv[0]=env, argv[1]=object, argv[2]=uint32 idx, argv[3]=bool* out."""
def _h_has_element(argv: int) -> int {
    jsobj: int = _napi_argv_i64(argv, 1);
    idx: int = _napi_argv_i64(argv, 2);
    result_ptr: int = _napi_argv_i64(argv, 3);
    if not jsv_is_object_cell(jsobj) {
        return NAPI_OBJECT_EXPECTED;
    }
    found: bool = False;
    if js_is_array(jsobj) {
        found = idx >= 0 and idx < js_array_len(jsobj);
    } else {
        kid: int = str_intern(str(idx));
        found = js_object_has(jsobj, kid);
    }
    _napi_write_bool(result_ptr, int(found));
    return NAPI_OK;
}

"""napi_delete_element: argv[0]=env, argv[1]=object, argv[2]=uint32 idx, argv[3]=bool* out.
For arrays, sets element to undefined (JS sparse array semantics)."""
def _h_delete_element(argv: int) -> int {
    jsobj: int = _napi_argv_i64(argv, 1);
    idx: int = _napi_argv_i64(argv, 2);
    result_ptr: int = _napi_argv_i64(argv, 3);
    if not jsv_is_object_cell(jsobj) {
        return NAPI_OBJECT_EXPECTED;
    }
    ok: bool = False;
    if js_is_array(jsobj) {
        if idx >= 0 and idx < js_array_len(jsobj) {
            js_array_set(jsobj, idx, jsv_undefined());
            ok = True;
        }
    } else {
        kid: int = str_intern(str(idx));
        ok = js_object_delete(jsobj, kid);
    }
    _napi_write_bool(result_ptr, int(ok));
    return NAPI_OK;
}

"""napi_get_array_length: argv[0]=env, argv[1]=array, argv[2]=uint32_t* out."""
def _h_get_array_length(argv: int) -> int {
    arr: int = _napi_argv_i64(argv, 1);
    result_ptr: int = _napi_argv_i64(argv, 2);
    if not jsv_is_object_cell(arr) {
        return NAPI_OBJECT_EXPECTED;
    }
    n: int = js_array_len(arr);
    _napi_write_u32(result_ptr, n);
    return NAPI_OK;
}

# ── Property enumeration (ops 60–61) ────────────────────────────────────────

"""napi_get_property_names: argv[0]=env, argv[1]=object, argv[2]=napi_value* out.
Returns an Array of own enumerable string-keyed property names."""
def _h_get_property_names(argv: int) -> int {
    jsobj: int = _napi_argv_i64(argv, 1);
    result_ptr: int = _napi_argv_i64(argv, 2);
    if not jsv_is_object_cell(jsobj) {
        return NAPI_OBJECT_EXPECTED;
    }
    ids: list[int] = js_object_keys(jsobj);
    arr: int = _ids_to_array(ids);
    _napi_write_i64(result_ptr, arr);
    return NAPI_OK;
}

"""napi_get_all_property_names: argv[0]=env, argv[1]=object, argv[2]=key_mode,
argv[3]=key_filter, argv[4]=key_conversion, argv[5]=napi_value* out.

Simplified: key_mode selects own-only vs include-prototypes.
key_filter and key_conversion are approximated (return all string keys)."""
def _h_get_all_property_names(argv: int) -> int {
    jsobj: int = _napi_argv_i64(argv, 1);
    key_mode: int = _napi_argv_i64(argv, 2);
    result_ptr: int = _napi_argv_i64(argv, 5);
    if not jsv_is_object_cell(jsobj) {
        return NAPI_OBJECT_EXPECTED;
    }
    ids: list[int] = [];
    if key_mode == _KEY_OWN_ONLY {
        ids = js_object_keys(jsobj);
    } else {
        ids = js_object_all_keys(jsobj);
    }
    arr: int = _ids_to_array(ids);
    _napi_write_i64(result_ptr, arr);
    return NAPI_OK;
}

# ── napi_define_properties (op 62) ──────────────────────────────────────────

"""napi_define_properties: argv[0]=env, argv[1]=object, argv[2]=count,
argv[3]=napi_property_descriptor* properties.

Iterates over the descriptor array and defines each property.
Data properties (value != 0/undefined) are defined with the given attributes.
Method/getter/setter descriptors are stored as a placeholder.
The napi_static attribute (1024) is silently ignored here (used by define_class)."""
def _h_define_properties(argv: int) -> int {
    jsobj: int = _napi_argv_i64(argv, 1);
    count: int = _napi_argv_i64(argv, 2);
    props_ptr: int = _napi_argv_i64(argv, 3);
    if not jsv_is_object_cell(jsobj) {
        return NAPI_OBJECT_EXPECTED;
    }
    if count == 0 {
        return NAPI_OK;
    }
    i: int = 0;
    while i < count {
        pd: int = props_ptr + i * _PD_SIZE;
        # Read name: prefer utf8name, fall back to name JSValue
        utf8name_ptr: int = read_ptr(pd, _PD_UTF8NAME);
        name_jsv: int = read_ptr(pd, _PD_NAME);
        kid: int = -1;
        if utf8name_ptr != 0 {
            name: str = _read_cstr(utf8name_ptr);
            kid = str_intern(name);
        } elif name_jsv != 0 and jsv_is_string_cell(name_jsv) {
            kid = jsv_to_table_id(name_jsv);
        } elif name_jsv != 0 and jsv_is_symbol(name_jsv) {
            kid = jsv_to_table_id(name_jsv);
        }
        if kid >= 0 {
            method_ptr: int = read_ptr(pd, _PD_METHOD);
            getter_ptr: int = read_ptr(pd, _PD_GETTER);
            setter_ptr: int = read_ptr(pd, _PD_SETTER);
            value_jsv: int = read_ptr(pd, _PD_VALUE);
            attrs: int = read_u32(pd, _PD_ATTRIBUTES);
            data_ptr: int = read_ptr(pd, _PD_DATA);
            # Mask off napi_static (1024) — not relevant for define_properties
            flags: int = attrs & 7;
            if getter_ptr != 0 or setter_ptr != 0 {
                # Accessor property: wrap the getter/setter C callbacks as NAPI
                # closures and install them (was dropped as undefined — F5).
                acc_name: str = "";
                if utf8name_ptr != 0 {
                    acc_name = _read_cstr(utf8name_ptr);
                }
                if getter_ptr != 0 {
                    getter_cl: int = _napi_make_closure(acc_name, getter_ptr, data_ptr);
                    js_object_set_accessor_getter(jsobj, kid, getter_cl);
                }
                if setter_ptr != 0 {
                    setter_cl: int = _napi_make_closure(acc_name, setter_ptr, data_ptr);
                    js_object_set_accessor_setter(jsobj, kid, setter_cl);
                }
                js_object_set_accessor_enumerable(
                    jsobj, kid, (flags & PROP_ENUMERABLE) != 0
                );
                js_object_set_accessor_configurable(
                    jsobj, kid, (flags & PROP_CONFIGURABLE) != 0
                );
            } elif method_ptr != 0 {
                # Create a NAPI callback closure for the method
                method_name: str = "";
                if utf8name_ptr != 0 {
                    method_name = _read_cstr(utf8name_ptr);
                }
                method_cl: int = _napi_make_closure(method_name, method_ptr, data_ptr);
                js_object_set_flags(jsobj, kid, method_cl, flags);
            } elif value_jsv != 0 {
                js_object_set_flags(jsobj, kid, value_jsv, flags);
            } else {
                # value=0 and no accessor: define as undefined data property
                js_object_set_flags(jsobj, kid, jsv_undefined(), flags);
            }
        }
        i = i + 1;
    }
    return NAPI_OK;
}

# ── Prototype / freeze / seal (ops 63–65) ───────────────────────────────────

"""napi_get_prototype: argv[0]=env, argv[1]=object, argv[2]=napi_value* out."""
def _h_get_prototype(argv: int) -> int {
    jsobj: int = _napi_argv_i64(argv, 1);
    result_ptr: int = _napi_argv_i64(argv, 2);
    if not jsv_is_object_cell(jsobj) {
        return NAPI_OBJECT_EXPECTED;
    }
    proto: int = js_object_get_prototype(jsobj);
    if jsv_is_undefined(proto) {
        proto = jsv_null();
    }
    _napi_write_i64(result_ptr, proto);
    return NAPI_OK;
}

"""napi_object_freeze: argv[0]=env, argv[1]=object.
Makes all properties non-writable + non-configurable + non-extensible."""
def _h_object_freeze(argv: int) -> int {
    jsobj: int = _napi_argv_i64(argv, 1);
    if not jsv_is_object_cell(jsobj) {
        return NAPI_OBJECT_EXPECTED;
    }
    js_object_freeze(jsobj);
    return NAPI_OK;
}

"""napi_object_seal: argv[0]=env, argv[1]=object.
Approximated as prevent_extensions; marks the object non-extensible."""
def _h_object_seal(argv: int) -> int {
    jsobj: int = _napi_argv_i64(argv, 1);
    if not jsv_is_object_cell(jsobj) {
        return NAPI_OBJECT_EXPECTED;
    }
    js_object_prevent_extensions(jsobj);
    return NAPI_OK;
}

# ── Type coercions (ops 66–69) ───────────────────────────────────────────────

"""napi_coerce_to_bool: argv[0]=env, argv[1]=value, argv[2]=napi_value* out."""
def _h_coerce_to_bool(argv: int) -> int {
    val: int = _napi_argv_i64(argv, 1);
    result_ptr: int = _napi_argv_i64(argv, 2);
    b: bool = jsv_coerce_to_bool(val);
    _napi_write_i64(result_ptr, jsv_from_bool(b));
    return NAPI_OK;
}

"""napi_coerce_to_number: argv[0]=env, argv[1]=value, argv[2]=napi_value* out."""
def _h_coerce_to_number(argv: int) -> int {
    val: int = _napi_argv_i64(argv, 1);
    result_ptr: int = _napi_argv_i64(argv, 2);
    n: float = jsv_coerce_to_number(val);
    _napi_write_i64(result_ptr, jsv_from_double(n));
    return NAPI_OK;
}

"""napi_coerce_to_object: argv[0]=env, argv[1]=value, argv[2]=napi_value* out.
If value is already an object/array/function, returns it as-is.
Primitives are not wrapped (wrapper objects are a v2 feature); return empty object."""
def _h_coerce_to_object(argv: int) -> int {
    val: int = _napi_argv_i64(argv, 1);
    result_ptr: int = _napi_argv_i64(argv, 2);
    if jsv_is_object_cell(val) or (jsv_is_cell(val) and not jsv_is_undefined(val)) {
        _napi_write_i64(result_ptr, val);
    } else {
        jsobj: int = js_object_new_ordinary();
        _napi_write_i64(result_ptr, jsobj);
    }
    return NAPI_OK;
}

"""napi_coerce_to_string: argv[0]=env, argv[1]=value, argv[2]=napi_value* out.
Converts via ToString; result is a string JSValue."""
def _h_coerce_to_string(argv: int) -> int {
    val: int = _napi_argv_i64(argv, 1);
    result_ptr: int = _napi_argv_i64(argv, 2);
    # For strings, return as-is
    if jsv_is_string_cell(val) {
        _napi_write_i64(result_ptr, val);
        return NAPI_OK;
    }
    # ECMAScript ToString: objects run OrdinaryToPrimitive("string") →
    # user toString/valueOf (or @@toPrimitive). jsv_coerce_to_str is the
    # non-observable fallback and yields "[object Object]" for objects, so
    # use the observable path and propagate any thrown completion.
    s: str = js_to_string_observable(val);
    if vm_has_native_exc() {
        return NAPI_PENDING_EXCEPTION;
    }
    sid: int = str_intern(s);
    _napi_write_i64(result_ptr, jsv_from_string_id(sid));
    return NAPI_OK;
}

# ── Sub-dispatcher — props/arrays/coerce (ops 42–69) ───────────────────────────────────────

"""Route ops 42–69 (props/arrays/coerce) to the appropriate handler.
Ops 45–46 (create_date, get_date_value) are not yet implemented."""
def:pub _dispatch_props(op: int, argv: int) -> int {
    if op == NAPI_OP_CREATE_OBJECT {
        return _h_create_object(argv);
    } elif op == NAPI_OP_CREATE_ARRAY {
        return _h_create_array(argv);
    } elif op == NAPI_OP_CREATE_ARRAY_WITH_LENGTH {
        return _h_create_array_with_length(argv);
    }
    # NAPI_OP_CREATE_DATE (45), NAPI_OP_GET_DATE_VALUE (46): not yet implemented
    elif op == NAPI_OP_GET_PROPERTY {
        return _h_get_property(argv);
    } elif op == NAPI_OP_SET_PROPERTY {
        return _h_set_property(argv);
    } elif op == NAPI_OP_HAS_PROPERTY {
        return _h_has_property(argv);
    } elif op == NAPI_OP_DELETE_PROPERTY {
        return _h_delete_property(argv);
    } elif op == NAPI_OP_GET_NAMED_PROPERTY {
        return _h_get_named_property(argv);
    } elif op == NAPI_OP_SET_NAMED_PROPERTY {
        return _h_set_named_property(argv);
    } elif op == NAPI_OP_HAS_NAMED_PROPERTY {
        return _h_has_named_property(argv);
    } elif op == NAPI_OP_HAS_OWN_PROPERTY {
        return _h_has_own_property(argv);
    } elif op == NAPI_OP_GET_ELEMENT {
        return _h_get_element(argv);
    } elif op == NAPI_OP_SET_ELEMENT {
        return _h_set_element(argv);
    } elif op == NAPI_OP_HAS_ELEMENT {
        return _h_has_element(argv);
    } elif op == NAPI_OP_DELETE_ELEMENT {
        return _h_delete_element(argv);
    } elif op == NAPI_OP_GET_ARRAY_LENGTH {
        return _h_get_array_length(argv);
    } elif op == NAPI_OP_GET_PROPERTY_NAMES {
        return _h_get_property_names(argv);
    } elif op == NAPI_OP_GET_ALL_PROPERTY_NAMES {
        return _h_get_all_property_names(argv);
    } elif op == NAPI_OP_DEFINE_PROPERTIES {
        return _h_define_properties(argv);
    } elif op == NAPI_OP_GET_PROTOTYPE {
        return _h_get_prototype(argv);
    } elif op == NAPI_OP_OBJECT_FREEZE {
        return _h_object_freeze(argv);
    } elif op == NAPI_OP_OBJECT_SEAL {
        return _h_object_seal(argv);
    } elif op == NAPI_OP_COERCE_TO_BOOL {
        return _h_coerce_to_bool(argv);
    } elif op == NAPI_OP_COERCE_TO_NUMBER {
        return _h_coerce_to_number(argv);
    } elif op == NAPI_OP_COERCE_TO_OBJECT {
        return _h_coerce_to_object(argv);
    } elif op == NAPI_OP_COERCE_TO_STRING {
        return _h_coerce_to_string(argv);
    }
    return NAPI_GENERIC_FAILURE;
}
