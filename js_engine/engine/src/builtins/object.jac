"""
Built-in: Object constructor and static/prototype methods.

Wraps the primitive js_object_* operations into the JS-callable convention:
each exported function takes and returns JSValue, mirroring the ECMAScript
spec's Object built-in interface and Bun's ObjectConstructor.ts.

Bun reference   : bun/src/js/builtins/ObjectConstructor.ts
                  JSC ObjectConstructor.cpp / ObjectPrototype.cpp
ECMAScript spec : §20.1 — Object Objects
                  https://tc39.es/ecma262/#sec-object-objects
"""

import from engine.src.runtime.js_bigint { js_bigint_cells_equal, js_bigint_get_proto }
import from engine.src.runtime.jsobj_type { PropertyDescriptorRecord }
import from engine.src.runtime.jsvalue {
    JSValue,
    jsv_from_string_id,
    js_undefined,
    js_true,
    js_false,
    js_boolean,
    js_int,
    js_strict_equal,
    jsv_coerce_to_str,
    jsv_is_undefined,
    jsv_is_null,
    jsv_is_bool,
    jsv_is_int32,
    jsv_is_double,
    jsv_is_number,
    jsv_is_object_cell,
    jsv_is_string_cell,
    jsv_is_symbol,
    jsv_is_bigint_cell,
    jsv_is_any_object,
    jsv_to_int32,
    jsv_to_double,
    jsv_to_table_id,
    jsv_coerce_to_bool,
    jsv_from_symbol_id,
    jsv_is_cell,
    jsv_cell_kind,
    JS_CELL_KIND_NATIVE
}
import from engine.src.runtime.dtoa { number_to_string_radix10 }
import from engine.src.runtime.encoding { BUILTIN_BASE }
import from engine.src.builtins.native_registry { is_native_val, native_props_get }
import from engine.src.runtime.jsobject {
    JSProperty,
    KEY_LENGTH,
    KEY_CTOR_KIND,
    SYMBOL_KEY_BASE,
    js_object_create_null,
    js_object_create,
    js_object_new_ordinary,
    js_object_get,
    js_object_set,
    js_object_delete,
    js_object_remove_own_keep_order,
    js_object_has_own,
    js_object_has,
    js_object_has_own_accessor,
    js_object_keys,
    js_object_all_keys,
    js_object_own_key_ids_ordered,
    js_object_own_key_is_enumerable_now,
    js_object_create_data_property_or_throw,
    js_object_assign,
    js_object_freeze,
    js_object_seal,
    js_object_is_frozen,
    js_object_is_sealed,
    js_object_get_prototype,
    js_object_set_prototype,
    js_object_get_ordinary_proto,
    js_object_define_property,
    js_object_apply_validated_descriptor,
    js_function_get_proto,
    js_object_get_own_property_descriptor,
    js_object_set_accessor_getter,
    js_object_set_accessor_setter,
    js_object_set_accessor_enumerable,
    js_object_set_accessor_configurable,
    js_object_get_own_accessor_getter,
    js_object_get_own_accessor_setter,
    js_object_lookup_getter,
    js_object_lookup_setter,
    js_object_prevent_extensions,
    js_object_is_extensible,
    js_is_module_namespace,
    js_object_is_plain_ordinary
}
import from engine.src.runtime.fn_meta {
    fn_meta_is_closure,
    fn_meta_get_object_proto,
    fn_meta_set_object_proto,
    fn_meta_get_fn_props,
    fn_meta_builtin_to_string_tag
}
import from engine.src.vm.vm_obs {
    js_object_get_observable,
    js_object_set_observable,
    js_to_property_key_observable
}
import from engine.src.runtime.jsstring {
    str_intern_index,
    str_intern,
    str_from_id,
    str_substr,
    HEAP_STRING_BASE,
    js_string_utf16_len,
    str_id_is_array_index,
    str_id_is_private_key
}
import from engine.src.runtime.jssymbol { SYMBOL_TO_STRING_TAG, js_symbol_get_proto }
import from engine.src.builtins.array {
    _KEY_IS_ARRAY,
    js_array_create,
    js_array_get,
    js_array_len,
    js_is_array,
    js_array_len_value,
    js_array_define_length_property,
    _array_index_write_allowed,
    _array_grow_length_if_needed,
    _array_index_key_numeric,
    _sort_payload_by_int_key,
    _create_data_property_or_throw,
    js_array_own_key_ids
}
import from engine.src.runtime.error {
    make_type_error,
    vm_throw_native,
    vm_has_native_exc
}
import from engine.src.runtime.proxy {
    js_is_proxy,
    js_proxy_is_revoked,
    js_proxy_is_callable,
    js_proxy_target
}
import from engine.src.builtins.map { js_is_map, js_is_weakmap }
import from engine.src.builtins.set { js_is_set, js_is_weakset }
import from engine.src.builtins.number {
    js_Boolean_new,
    js_Number_new,
    is_number_object,
    is_boolean_object
}
import from engine.src.builtins.string {
    js_String_new,
    is_string_object,
    string_value_of,
    js_string_exotic_has_index,
    js_string_exotic_get_index,
    KEY_IS_STRING_OBJ
}
import from engine.src.runtime.wk_keys {
    WK_IS_CLASS,
    WK_SUPER,
    WK_DEFER_PENDING,
    WK_CTOR,
    WK_CLASS_NAME,
    WK_FIELDS
}
import from engine.src.runtime.spec_ops {
    spec_to_property_descriptor,
    spec_same_value,
    spec_data_record_to_jsproperty,
    spec_is_callable,
    spec_validate_and_apply_descriptor
}

# ══════════════════════════════════════════════════════════════════════════════
# 1.  Internal helpers
# ══════════════════════════════════════════════════════════════════════════════

"""Create a JSString JSValue from a raw Jac string."""
def _obj_js_str(s: str) -> JSValue {
    return jsv_from_string_id(str_intern(s));
}

"""
Build a JS Array JSValue from a list of JSValues.

Uses js_array_create so results inherit %Array.prototype% and pass instanceof Array.
"""
def _make_js_array(items: list[JSValue]) -> JSValue {
    return js_array_create(items);
}

"""
Read element at integer index from a JS Array object.
Returns undefined if out of range or non-array.
"""
def _js_array_get(arr: JSValue, idx: int) -> JSValue {
    return js_array_get(arr, idx);
}

"""
Return the interned key ID for a JS key value.

For String-tagged values, the interned ID is stored directly in as_ptr.
Numbers use ES Number::ToString (dtoa) so keys like 1e+20 become
"100000000000000000000", not a scientific-notation string.
Symbols use SYMBOL_KEY_BASE offset. Other primitives fall back to ToString.
"""
def _key_to_id(key: JSValue) -> int {
    if jsv_is_string_cell(key) {
        kid: int = jsv_to_table_id(key);
        # A heap (computed) string is not interned, so its id is not a canonical
        # property key. Re-intern via its text so `o["a"+"b"]` keys on the same
        # id as `o.ab`. Interned strings (id < HEAP_STRING_BASE) pass through.
        if kid >= HEAP_STRING_BASE {
            return str_intern(str_from_id(kid));
        }
        return kid;
    }
    if jsv_is_symbol(key) {
        return SYMBOL_KEY_BASE + jsv_to_table_id(key);
    }
    if jsv_is_int32(key) {
        return str_intern(str(jsv_to_int32(key)));
    }
    if jsv_is_double(key) {
        return str_intern(number_to_string_radix10(jsv_to_double(key)));
    }
    if jsv_is_bigint_cell(key) {
        return str_intern(str_from_id(jsv_to_table_id(key)));
    }
    if jsv_is_object_cell(key) or is_native_val(key) or fn_meta_is_closure(key) {
        return js_to_property_key_observable(key);
    }
    return str_intern(jsv_coerce_to_str(key));
}

def _is_zero_value(v: JSValue) -> bool {
    if jsv_is_int32(v) {
        return jsv_to_int32(v) == 0;
    }
    if jsv_is_double(v) {
        return jsv_to_double(v) == 0.0;
    }
    return False;
}

def _is_negative_zero(v: JSValue) -> bool {
    if jsv_is_double(v) {
        d: float = jsv_to_double(v);
        if d == 0.0 {
            return str(d).startswith("-");
        }
    }
    return False;
}

"""
ECMAScript SameValue (used by Object.is).

Differs from === in two ways:
  - SameValue(NaN, NaN) is true
  - SameValue(+0, -0) is false (only relevant for Float64 tag)
"""
def _same_value(a: JSValue, b: JSValue) -> bool {
    if _is_zero_value(a) and _is_zero_value(b) {
        return _is_negative_zero(a) == _is_negative_zero(b);
    }
    # NaN check: Float64 where as_float != as_float (NaN is not equal to itself)
    if jsv_is_double(a) and jsv_is_double(b) {
        a_nan: bool = not (jsv_to_double(a) == jsv_to_double(a));
        b_nan: bool = not (jsv_to_double(b) == jsv_to_double(b));
        if a_nan and b_nan {
            return True;
        }
        if a_nan or b_nan {
            return False;
        }
        return jsv_to_double(a) == jsv_to_double(b);
    }
    if jsv_is_bigint_cell(a) and jsv_is_bigint_cell(b) {
        return js_bigint_cells_equal(a, b);
    }
    # Strings compare by content: two heap (computed, non-interned) strings with
    # equal text have different ids, so bit equality alone said
    # Object.is("wor" + "ld", "world") === false.
    if jsv_is_string_cell(a) and jsv_is_string_cell(b) {
        if a == b {
            return True;
        }
        sv_sa: str = str_from_id(jsv_to_table_id(a));
        sv_sb: str = str_from_id(jsv_to_table_id(b));
        return sv_sa == sv_sb;
    }
    # For all other tag combinations fall back to strict equality
    return js_strict_equal(a, b);
}

"""
Build a property descriptor JSObject from a JSProperty struct.

Returns { value, writable, enumerable, configurable }.
ECMAScript §6.2.6 — Property Descriptor
"""
def _descriptor_object(prop: JSProperty) -> JSValue {
    # FromPropertyDescriptor (ES §6.2.6.4): the result is an *ordinary* object with
    # [[Prototype]] = %Object.prototype% (so `desc.hasOwnProperty(...)` etc. work).
    desc: JSValue = js_object_new_ordinary();
    js_object_set(desc, str_intern("value"), prop.value);
    js_object_set(desc, str_intern("writable"), js_boolean(prop.writable));
    js_object_set(desc, str_intern("enumerable"), js_boolean(prop.enumerable));
    js_object_set(desc, str_intern("configurable"), js_boolean(prop.configurable));
    return desc;
}

"""True when Desc is a JS Object (ordinary, native/callable, HTMLDDA) for ToPropertyDescriptor."""
def _is_desc_object(desc: JSValue) -> bool {
    return jsv_is_any_object(desc);
}

"""True when v is callable (closure, native, or KEY_CTOR_KIND object). Undefined is allowed."""
def _accessor_is_callable(v: JSValue) -> bool {
    if jsv_is_undefined(v) {
        return True;
    }
    # Delegate to the canonical IsCallable (§7.2.3): covers closures, natives,
    # callable proxies, htmldda, and class objects. Undefined returns False here;
    # every caller guards undefined explicitly (see _validate_accessor_callables
    # and the __define*Getter__/__define*Setter__ paths).
    return spec_is_callable(v);
}

def _is_array_index_key_id(kid: int) -> bool {
    if kid >= SYMBOL_KEY_BASE {
        return False;
    }
    return str_id_is_array_index(kid);
}

def _array_index_sort_key(kid: int) -> int {
    s: str = str_from_id(kid);
    np: int = 0;
    pi: int = 0;
    sn: int = len(s);
    while pi < sn {
        ch: str = str_substr(s, pi, pi + 1);
        if ch >= "0" and ch <= "9" {
            np = np * 10 + (ord(ch) - 48);
        }
        pi = pi + 1;
    }
    return np;
}

"""Sort `indices` (interned array-index key ids) ascending by numeric value.

Was a selection sort — O(n^2), and it re-parsed each key's number on every
compare — running on EVERY Object.keys / for-in / spread of an object with
several index keys. Now O(n log n): parse each index once into a parallel key
array, then merge sort. Mutates `indices` in place. (`strings` is unused; kept
for the existing call signature.)"""
def _sort_key_id_partitions(indices: list[int], strings: list[int]) -> None {
    n: int = len(indices);
    if n <= 1 {
        return;
    }
    keys: list[int] = [];
    i: int = 0;
    while i < n {
        keys.append(_array_index_sort_key(indices[i]));
        i = i + 1;
    }
    sorted_ids: list[int] = _sort_payload_by_int_key(keys, indices);
    i = 0;
    while i < n {
        indices[i] = sorted_ids[i];
        i = i + 1;
    }
}

"""True for engine marker keys in the BUILTIN_BASE..SYMBOL_KEY_BASE gap
(_KEY_IS_ARRAY, KEY_CTOR_KIND, …).  These are not interned strings; exposing
them via Reflect.ownKeys yields a spurious empty key."""
def _is_engine_marker_key(kid: int) -> bool {
    return kid >= BUILTIN_BASE and kid < SYMBOL_KEY_BASE;
}

def _partition_own_key_ids(
    raw_ids: list[int]
) -> tuple[list[int], list[int], list[int]] {
    indices: list[int] = [];
    strings: list[int] = [];
    symbols: list[int] = [];
    for kid in raw_ids {
        # Negative IDs are engine-only sentinels (string/array wrappers, etc.).
        if kid < 0 {
            continue;
        }
        if _is_engine_marker_key(kid) {
            continue;
        }
        if kid >= SYMBOL_KEY_BASE {
            symbols.append(kid);
        } elif _is_array_index_key_id(kid) {
            indices.append(kid);
        } else {
            strings.append(kid);
        }
    }
    _sort_key_id_partitions(indices, strings);
    return (indices, strings, symbols);
}

"""True for engine-internal mangled keys that must never be spec-visible: private
class state (`__priv_#name@<sid>`), per-instance private-method brand markers
(`__brand@<sid>`), and deferred-module bookkeeping (`__DEFER_PENDING` /
`__DEFER_PATH`).  The `#` / `@` / `__DEFER_` prefixes make these unambiguous vs.
ordinary user keys."""
glob _IPK_DEFER_PATH: int = -1;  # str_intern("__DEFER_PATH"), set on first use
glob _IPK_STATIC_FIELDS: int = -1,
     _IPK_BRANDSID_CUR: int = -1;  # str_intern("__STATIC_FIELDS__")

# str_intern("__brandsid@cur")
def _is_internal_private_key(kid: int) -> bool {
    if kid < 0 or kid >= SYMBOL_KEY_BASE {
        return False;
    }
    # Exact-match internal keys: compare the interned KID (int), NOT
    # str_from_id(kid) == "literal" — that string comparison is unreliable here (a
    # heap-string vs literal mismatch) and silently let __DEFER_* AND the class
    # markers leak into Object.keys/values/entries. Int compare mirrors the working
    # filter in jsobject.js_object_own_key_ids_ordered. The ids are interned once
    # (the WK_* ones at startup): interning the five literals on every call was
    # ~650 instructions per key filtered.
    if _IPK_DEFER_PATH < 0 {
        _IPK_DEFER_PATH = str_intern("__DEFER_PATH");
        _IPK_STATIC_FIELDS = str_intern("__STATIC_FIELDS__");
        _IPK_BRANDSID_CUR = str_intern("__brandsid@cur");
    }
    if kid == WK_DEFER_PENDING or kid == _IPK_DEFER_PATH {
        return True;
    }
    if kid == WK_IS_CLASS or kid == WK_CTOR or kid == WK_CLASS_NAME {
        return True;
    }
    # Class bookkeeping on the class object: the field lists run at construction /
    # class evaluation and the private-scope stamp (`__brand@cur` is caught by the
    # "__brand@" prefix below).
    if kid == _IPK_STATIC_FIELDS or kid == WK_FIELDS or kid == _IPK_BRANDSID_CUR {
        return True;
    }
    # Private-field / brand keys are prefix-matched (variable suffix): the
    # per-id key class cache answers without the key's text.
    return str_id_is_private_key(kid);
}

"""Own enumerable key IDs in ECMAScript [[OwnPropertyKeys]] order (indices, strings, symbols).

Merge note: the merged (adel_fixes) body delegated to js_object_own_key_ids_ordered
and filtered by js_object_own_key_is_enumerable_now, which let a phantom empty-string
key leak into Object.keys([...]) (returned ["0","1","2",""]). Restored to HEAD's
self-contained body: descriptor-based enumerable check + explicit _KEY_IS_ARRAY /
empty-key skip."""
def:pub object_enumerable_own_key_ids_ordered(jsobj: JSValue) -> list[int] {
    raw_ids: list[int] = js_object_all_keys(jsobj);
    indices: list[int] = [];
    strings: list[int] = [];
    symbols: list[int] = [];
    # An ordinary object's [[Enumerable]] is read from its shape / map /
    # elements in place; exotics build the full descriptor (a JSProperty per
    # key was ~720 instructions — for-in over an 8-key object paid it 8x).
    oe_plain: bool = js_object_is_plain_ordinary(jsobj);
    for kid in raw_ids {
        if kid < 0 or _is_engine_marker_key(kid) {
            continue;
        }
        if _is_internal_private_key(kid) {
            continue;
        }
        # Empty-string keys are real (str_intern("")); array markers live in the
        # BUILTIN_BASE range via _is_engine_marker_key and no longer collide.
        if oe_plain {
            if not js_object_own_key_is_enumerable_now(jsobj, kid) {
                continue;
            }
        } else {
            prop: JSProperty = js_object_get_own_property_descriptor(jsobj, kid);
            if prop.deleted or not prop.enumerable {
                continue;
            }
        }
        if kid >= SYMBOL_KEY_BASE {
            symbols.append(kid);
        } elif _is_array_index_key_id(kid) {
            indices.append(kid);
        } else {
            strings.append(kid);
        }
    }
    _sort_key_id_partitions(indices, strings);
    out: list[int] = [];
    for kid in indices {
        out.append(kid);
    }
    for kid in strings {
        out.append(kid);
    }
    for kid in symbols {
        out.append(kid);
    }
    return out;
}

"""All own keys in spec order (not pre-filtered by enumerable)."""
def:pub object_own_key_ids_ordered(jsobj: JSValue) -> list[int] {
    return js_object_own_key_ids_ordered(jsobj);
}

"""Re-check [[Enumerable]] when walking a snapshot of own keys."""
def:pub object_own_key_is_enumerable_now(jsobj: JSValue, kid: int) -> bool {
    return js_object_own_key_is_enumerable_now(jsobj, kid);
}

def _sort_string_keys_by_codepoint(keys: list[int]) -> list[int] {
    n: int = len(keys);
    if n <= 1 {
        return keys;
    }
    strs: list[str] = [];
    ki: int = 0;
    while ki < n {
        strs.append(str_from_id(keys[ki]));
        ki = ki + 1;
    }
    i: int = 0;
    while i < n - 1 {
        j: int = i + 1;
        while j < n {
            if strs[j] < strs[i] {
                tmp_k: int = keys[i];
                keys[i] = keys[j];
                keys[j] = tmp_k;
                tmp_s: str = strs[i];
                strs[i] = strs[j];
                strs[j] = tmp_s;
            }
            j = j + 1;
        }
        i = i + 1;
    }
    return keys;
}

def _own_keys_ordered(jsobj: JSValue) -> list[JSValue] {
    if js_is_array(jsobj) {
        parts_a: tuple[list[int], list[int], list[int]] = _partition_own_key_ids(
            js_array_own_key_ids(jsobj)
        );
        indices: list[int] = parts_a[0];
        strings: list[int] = parts_a[1];
        symbols: list[int] = parts_a[2];
        out_a: list[JSValue] = [];
        for kid in indices {
            out_a.append(jsv_from_string_id(kid));
        }
        for kid in strings {
            if _is_internal_private_key(kid) {
                continue;
            }
            out_a.append(jsv_from_string_id(kid));
        }
        for kid in symbols {
            out_a.append(jsv_from_symbol_id(kid - SYMBOL_KEY_BASE));
        }
        return out_a;
    }
    parts: tuple[list[int], list[int], list[int]] = _partition_own_key_ids(
        js_object_all_keys(jsobj)
    );
    indices: list[int] = parts[0];
    strings: list[int] = parts[1];
    symbols: list[int] = parts[2];
    if js_is_module_namespace(jsobj) {
        strings = _sort_string_keys_by_codepoint(strings);
    }
    out: list[JSValue] = [];
    for kid in indices {
        out.append(jsv_from_string_id(kid));
    }
    for kid in strings {
        # Private class state / brand markers are never spec-visible own keys.
        if _is_internal_private_key(kid) {
            continue;
        }
        out.append(jsv_from_string_id(kid));
    }
    for kid in symbols {
        out.append(jsv_from_symbol_id(kid - SYMBOL_KEY_BASE));
    }
    return out;
}

# Merge note: HEAD's _parse_descriptor / _descriptor_is_invalid /
# _validate_accessor_callables were superseded by adel_fixes' spec_ops-based
# descriptor pipeline (spec_to_property_descriptor + spec_validate_and_apply_
# descriptor + _define_property_record_ordinary) and had no remaining callers,
# so they were removed as dead code.

# ══════════════════════════════════════════════════════════════════════════════
# 2.  Object constructor
# ══════════════════════════════════════════════════════════════════════════════

"""
Object() / new Object() constructor.

  - No args or undefined/null arg → return {}
  - Object arg → return it as-is (identity)
  - Primitive arg → currently returns {} (primitive boxing not yet implemented)

Bun Zig: JSC::objectConstructor, JSValue.zig::toObject()
ECMAScript §20.1.1.1
"""
def _object_wrapper_unbox(v: JSValue) -> JSValue {
    pk: int = str_intern("[[PrimitiveValue]]");
    if jsv_is_object_cell(v) and js_object_has_own(v, pk) {
        return js_object_get(v, pk);
    }
    return js_undefined();
}

def _spec_to_object(v: JSValue) -> JSValue {
    if jsv_is_any_object(v) {
        return v;
    }
    if jsv_is_bool(v) {
        return js_Boolean_new([v]);
    }
    if jsv_is_int32(v) or jsv_is_double(v) {
        return js_Number_new([v]);
    }
    if jsv_is_string_cell(v) {
        return js_String_new([v]);
    }
    pk_so: int = str_intern("[[PrimitiveValue]]");
    if jsv_is_symbol(v) {
        boxed_sy: JSValue = js_object_create(js_symbol_get_proto());
        js_object_define_property(
            boxed_sy,
            pk_so,
            JSProperty(
                key=0,
                value=v,
                writable=False,
                enumerable=False,
                configurable=False,
                deleted=False
            )
        );
        return boxed_sy;
    }
    if jsv_is_bigint_cell(v) {
        boxed_bi: JSValue = js_object_create(js_bigint_get_proto());
        js_object_define_property(
            boxed_bi,
            pk_so,
            JSProperty(
                key=0,
                value=v,
                writable=False,
                enumerable=False,
                configurable=False,
                deleted=False
            )
        );
        return boxed_bi;
    }
    return v;
}

def:pub js_Object(args: list[JSValue]) -> JSValue {
    if len(args) == 0 {
        return js_object_new_ordinary();
    }
    arg: JSValue = args[0];
    if jsv_is_null(arg) or jsv_is_undefined(arg) {
        return js_object_new_ordinary();
    }
    if jsv_is_any_object(arg) {
        return arg;
    }
    if jsv_is_bool(arg) {
        return js_Boolean_new([arg]);
    }
    if jsv_is_int32(arg) or jsv_is_double(arg) {
        return js_Number_new([arg]);
    }
    if jsv_is_string_cell(arg) {
        return js_String_new([arg]);
    }
    if jsv_is_symbol(arg) {
        boxed_sy: JSValue = js_object_create(js_symbol_get_proto());
        pk: int = str_intern("[[PrimitiveValue]]");
        js_object_define_property(
            boxed_sy,
            pk,
            JSProperty(
                key=0,
                value=arg,
                writable=False,
                enumerable=False,
                configurable=False,
                deleted=False
            )
        );
        return boxed_sy;
    }
    if jsv_is_bigint_cell(arg) {
        boxed_bi: JSValue = js_object_create(js_bigint_get_proto());
        pk2: int = str_intern("[[PrimitiveValue]]");
        js_object_define_property(
            boxed_bi,
            pk2,
            JSProperty(
                key=0,
                value=arg,
                writable=False,
                enumerable=False,
                configurable=False,
                deleted=False
            )
        );
        return boxed_bi;
    }
    return js_object_create_null();
}

"""ES §7.1.18 ToObject — throw TypeError on null/undefined, else box primitives."""
def:pub _to_object_or_throw(v: JSValue) -> JSValue {
    if jsv_is_null(v) or jsv_is_undefined(v) {
        vm_throw_native(make_type_error("Cannot convert undefined or null to object"));
        return js_undefined();
    }
    return js_Object([v]);
}

"""
Enumerable own keys of a PropertiesObject for ObjectDefineProperties / Object.create.

Function and native callables store user-defined props on a separate bag; String
exotics expose integer-index code-unit keys that are not materialised as data
entries.  Keep the original `props` value for subsequent Get (receiver/`this`).
"""
def _properties_object_enumerable_key_ids(props: JSValue) -> list[int] {
    bag: JSValue = props;
    if fn_meta_is_closure(props) {
        fp: JSValue = fn_meta_get_fn_props(props);
        if jsv_is_object_cell(fp) {
            bag = fp;
        }
    } elif is_native_val(props) {
        np: JSValue = native_props_get(props);
        if jsv_is_object_cell(np) {
            bag = np;
        }
    }
    out: list[int] = [];
    # Own keys are unique; only a String object's index keys (listed first)
    # can repeat one, so the dedupe set exists only then.
    seen: dict[int, bool] = {};
    str_obj: bool = is_string_object(props);
    if str_obj {
        prim: JSValue = string_value_of(props);
        s: str = str_from_id(jsv_to_table_id(prim));
        n: int = js_string_utf16_len(s);
        si: int = 0;
        while si < n {
            kid: int = str_intern_index(si);
            out.append(kid);
            seen[kid] = True;
            si = si + 1;
        }
    }
    for kid2 in js_object_own_key_ids_ordered(bag) {
        if str_obj and kid2 in seen {
            continue;
        }
        if kid2 < 0 or _is_engine_marker_key(kid2) {
            continue;
        }
        if _is_internal_private_key(kid2) {
            continue;
        }
        if not js_object_own_key_is_enumerable_now(bag, kid2) {
            continue;
        }
        out.append(kid2);
    }
    return out;
}

"""
Shared ObjectDefineProperties collect+apply (ES §20.1.2.3 / §10.1.6).

`props` must already be a ToObject result.  Returns False after throwing on
abrupt Attributes / incompatible redefine; True when all definitions succeed.
"""
def _object_define_properties_apply(jsobj: JSValue, props: JSValue) -> bool {
    bag: JSValue = props;
    if fn_meta_is_closure(props) {
        fp: JSValue = fn_meta_get_fn_props(props);
        if jsv_is_object_cell(fp) {
            bag = fp;
        }
    } elif is_native_val(props) {
        np: JSValue = native_props_get(props);
        if jsv_is_object_cell(np) {
            bag = np;
        }
    }
    pkeys: list[int] = _properties_object_enumerable_key_ids(props);
    is_arraylike_props: bool = (
        js_object_has_own(props, _KEY_IS_ARRAY)
        or js_object_has_own(props, KEY_CTOR_KIND)
        or is_string_object(props)
    );
    collected_keys: list[JSValue] = [];
    collected_descs: list[PropertyDescriptorRecord] = [];
    for pk in pkeys {
        if pk < 0 {
            continue;
        }
        # Skip spurious enumerable `length` on Array/String exotic PropertiesObjects.
        if pk == KEY_LENGTH and is_arraylike_props {
            continue;
        }
        # Lookup on the props bag; keep `props` as Receiver so function getters
        # see `this ===` the callable (e.g. `this instanceof Function`).
        dp: JSValue = js_object_get_observable(bag, pk, props);
        if vm_has_native_exc() {
            return False;
        }
        # String exotic indices are not stored on the bag — read them directly.
        if jsv_is_undefined(dp)
            and is_string_object(props)
            and js_string_exotic_has_index(props, pk) {
            dp = js_string_exotic_get_index(props, pk);
        }
        key_val: JSValue = jsv_from_string_id(pk);
        if pk >= SYMBOL_KEY_BASE {
            key_val = jsv_from_symbol_id(pk - SYMBOL_KEY_BASE);
        }
        if not _is_desc_object(dp) {
            vm_throw_native(make_type_error("Property description must be an object"));
            return False;
        }
        normalized: PropertyDescriptorRecord = spec_to_property_descriptor(dp);
        if vm_has_native_exc() {
            return False;
        }
        if normalized.is_invalid {
            if not vm_has_native_exc() {
                vm_throw_native(
                    make_type_error(
                        "Invalid property descriptor. Cannot both specify accessors and a value or writable attribute"
                    )
                );
            }
            return False;
        }
        collected_keys.append(key_val);
        collected_descs.append(normalized);
    }
    ci: int = 0;
    cn: int = len(collected_keys);
    while ci < cn {
        apply_ok: bool = False;
        if js_is_array(jsobj) {
            apply_ok = _define_property_inner(
                jsobj,
                collected_keys[ci],
                _descriptor_record_to_object(collected_descs[ci])
            );
        } else {
            apply_ok = _define_property_record_ordinary(
                jsobj, _key_to_id(collected_keys[ci]), collected_descs[ci]
            );
        }
        if not apply_ok {
            if not vm_has_native_exc() {
                vm_throw_native(make_type_error("Cannot redefine property"));
            }
            return False;
        }
        ci = ci + 1;
    }
    return True;
}

# ══════════════════════════════════════════════════════════════════════════════
# 3.  Static methods
# ══════════════════════════════════════════════════════════════════════════════

"""
Object.create(proto, propertiesObject?) — create object with given prototype.

Bun Zig: JSValue.createEmptyObjectWithNullPrototype / js_object_create
ECMAScript §20.1.2.2
"""
def:pub js_Object_create(proto: JSValue, props: JSValue) -> JSValue {
    if not (jsv_is_null(proto) or jsv_is_object_cell(proto)) {
        vm_throw_native(
            make_type_error("Object prototype may only be an Object or null")
        );
        return js_undefined();
    }
    jsobj: JSValue = js_object_create_null();
    if jsv_is_object_cell(proto) {
        js_object_set_prototype(jsobj, proto);
    }
    # ES §20.1.2.2 step 3: if Properties is not undefined → ObjectDefineProperties
    # which begins with ToObject(Properties). The two-phase validate-then-apply
    # (adel_fixes' _object_define_properties_apply) is more spec-correct than
    # HEAD's apply-as-you-go loop (which could partially mutate before throwing).
    if not jsv_is_undefined(props) {
        props_obj: JSValue = _to_object_or_throw(props);
        if vm_has_native_exc() {
            return js_undefined();
        }
        if not _object_define_properties_apply(jsobj, props_obj) {
            return js_undefined();
        }
    }
    return jsobj;
}

"""
Object.keys(jsobj) — array of own enumerable string-keyed property names.

Returns a JS Array (JSObject) of string JSValues.
Bun Zig: JSObject.getOwnPropertyNames()
ECMAScript §20.1.2.17
"""
def:pub js_Object_keys(jsobj: JSValue) -> JSValue {
    if jsv_is_null(jsobj) or jsv_is_undefined(jsobj) {
        vm_throw_native(make_type_error("Cannot convert undefined or null to object"));
        return js_undefined();
    }
    if jsv_is_string_cell(jsobj) {
        raw_k: str = str_from_id(jsv_to_table_id(jsobj));
        items_s: list[JSValue] = [];
        ki: int = 0;
        while ki < len(raw_k) {
            items_s.append(_obj_js_str(str(ki)));
            ki = ki + 1;
        }
        return _make_js_array(items_s);
    }
    if not jsv_is_object_cell(jsobj) {
        return _make_js_array([]);
    }
    # Use the descriptor-based enumerable-ordered helper (handles array-exotic
    # indices and skips the empty-string phantom); Object.keys returns only
    # string-keyed enumerable own properties (no symbols).
    key_ids: list[int] = object_enumerable_own_key_ids_ordered(jsobj);
    items: list[JSValue] = [];
    for kid in key_ids {
        if kid >= SYMBOL_KEY_BASE {
            continue;
        }
        ks: str = str_from_id(kid);
        if ks != "" {
            items.append(_obj_js_str(ks));
        }
    }
    return _make_js_array(items);
}

"""
Object.values(jsobj) — array of own enumerable property values.
ECMAScript §20.1.2.22
"""
def:pub js_Object_values(jsobj: JSValue) -> JSValue {
    if jsv_is_null(jsobj) or jsv_is_undefined(jsobj) {
        vm_throw_native(make_type_error("Cannot convert undefined or null to object"));
        return js_undefined();
    }
    if not jsv_is_object_cell(jsobj) {
        return _make_js_array([]);
    }
    key_ids: list[int] = js_object_own_key_ids_ordered(jsobj);
    items: list[JSValue] = [];
    for kid in key_ids {
        if kid >= SYMBOL_KEY_BASE {
            continue;
        }
        if _is_internal_private_key(kid) {
            continue;
        }
        if not js_object_own_key_is_enumerable_now(jsobj, kid) {
            continue;
        }
        val_v: JSValue = js_object_get_observable(jsobj, kid, jsobj);
        if vm_has_native_exc() {
            return js_undefined();
        }
        items.append(val_v);
    }
    return _make_js_array(items);
}

"""
Object.entries(jsobj) — array of [key, value] arrays.
ECMAScript §20.1.2.5
"""
def:pub js_Object_entries(jsobj: JSValue) -> JSValue {
    if jsv_is_null(jsobj) or jsv_is_undefined(jsobj) {
        vm_throw_native(make_type_error("Cannot convert undefined or null to object"));
        return js_undefined();
    }
    if not jsv_is_object_cell(jsobj) {
        return _make_js_array([]);
    }
    key_ids: list[int] = js_object_own_key_ids_ordered(jsobj);
    pairs: list[JSValue] = [];
    for kid in key_ids {
        if kid >= SYMBOL_KEY_BASE {
            continue;
        }
        if _is_internal_private_key(kid) {
            continue;
        }
        if not js_object_own_key_is_enumerable_now(jsobj, kid) {
            continue;
        }
        val_e: JSValue = js_object_get_observable(jsobj, kid, jsobj);
        if vm_has_native_exc() {
            return js_undefined();
        }
        pair: JSValue = _make_js_array([_obj_js_str(str_from_id(kid)), val_e]);
        pairs.append(pair);
    }
    return _make_js_array(pairs);
}

"""
CopyDataProperties(target, source) — §7.3.25 with observable [[Get]] when VM obs is active.
"""
def _object_copy_data_properties(target: JSValue, source: JSValue) -> None {
    if not jsv_is_object_cell(source) {
        return;
    }
    key_ids: list[int] = js_object_own_key_ids_ordered(source);
    for kid in key_ids {
        if kid < 0 {
            continue;
        }
        if not js_object_own_key_is_enumerable_now(source, kid) {
            continue;
        }
        prop_val: JSValue = js_object_get_observable(source, kid, source);
        if vm_has_native_exc() {
            return;
        }
        if js_is_array(target) {
            aidx: int = _array_index_key_numeric(kid);
            if aidx >= 0 {
                if not _create_data_property_or_throw(target, aidx, prop_val) {
                    if not vm_has_native_exc() {
                        vm_throw_native(make_type_error("Cannot create property"));
                    }
                    return;
                }
            } elif js_object_create_data_property_or_throw(target, kid, prop_val)
                != 0 {
                vm_throw_native(make_type_error("Cannot create property"));
                return;
            }
        } elif js_object_create_data_property_or_throw(target, kid, prop_val) != 0 {
            vm_throw_native(make_type_error("Cannot create property"));
            return;
        }
    }
}

"""
Object.assign(target, ...sources) — shallow copy own enumerable properties.
Returns target.  Bun Zig: JSC::objectAssign()
ECMAScript §20.1.2.1
"""
def:pub js_Object_assign(target: JSValue, sources: list[JSValue]) -> JSValue {
    # CopyDataProperties after ToObject(source); skip only null/undefined (§20.1.2.1).
    if not jsv_is_object_cell(target) {
        return target;
    }
    boxed: list[JSValue] = [];
    for s in sources {
        if jsv_is_null(s) or jsv_is_undefined(s) {
            continue;
        }
        if jsv_is_object_cell(s) {
            boxed.append(s);
        } elif jsv_is_string_cell(s) {
            # String primitives expose enumerable index properties when boxed.
            s_obj: JSValue = js_String_new([s]);
            raw: str = str_from_id(jsv_to_table_id(s));
            si: int = 0;
            while si < len(raw) {
                js_object_set(
                    s_obj,
                    str_intern_index(si),
                    _obj_js_str(str_substr(raw, si, si + 1))
                );
                si = si + 1;
            }
            boxed.append(s_obj);
        } else {
            boxed.append(_spec_to_object(s));
        }
    }
    for src in boxed {
        _object_copy_data_properties(target, src);
        if vm_has_native_exc() {
            return target;
        }
    }
    return target;
}

"""
Object.freeze(jsobj) — make all own properties non-writable/non-configurable.
Returns the (now frozen) object.  Bun Zig: JSC::objectFreeze()
ECMAScript §20.1.2.6
"""
def:pub js_Object_freeze(jsobj: JSValue) -> JSValue {
    js_object_freeze(jsobj);
    return jsobj;
}

"""Object.isFrozen(jsobj). ECMAScript §20.1.2.12."""
def:pub js_Object_isFrozen(jsobj: JSValue) -> bool {
    return js_object_is_frozen(jsobj);
}

"""
Object.seal(jsobj) — preventExtensions + make all own properties non-configurable.
ECMAScript §20.1.2.20
"""
def:pub js_Object_seal(jsobj: JSValue) -> JSValue {
    js_object_seal(jsobj);
    return jsobj;
}

"""Object.isSealed(jsobj). ECMAScript §20.1.2.13."""
def:pub js_Object_isSealed(jsobj: JSValue) -> bool {
    return js_object_is_sealed(jsobj);
}

"""
Object.getPrototypeOf(jsobj). ECMAScript §20.1.2.11.
Returns null JSValue if prototype is null.
"""
def:pub js_Object_getPrototypeOf(jsobj: JSValue) -> JSValue {
    if jsv_is_null(jsobj) or jsv_is_undefined(jsobj) {
        te: JSValue = make_type_error(
            "Object.getPrototypeOf called on null or undefined"
        );
        vm_throw_native(te);
        return js_undefined();
    }
    # All callable values (JS closures, built-ins, and native dispatch values)
    # are encoded as JS_CELL_KIND_NATIVE cells — distinguished only by their
    # id range (closures < BUILTIN_BASE <= built-ins < NATIVE_BASE <= natives).
    # Their [[Prototype]] is Function.prototype regardless of range, so test the
    # cell kind directly rather than any id boundary.
    if jsv_is_cell(jsobj) and jsv_cell_kind(jsobj) == JS_CELL_KIND_NATIVE {
        if fn_meta_is_closure(jsobj) {
            custom: JSValue = fn_meta_get_object_proto(jsobj);
            if not jsv_is_undefined(custom) {
                return custom;
            }
        }
        return js_function_get_proto();
    }
    # Native constructors (Array, Object, Map, …) are callable JSObjects tagged
    # with KEY_CTOR_KIND rather than native cells; their [[Prototype]] is also
    # Function.prototype.  (User classes use WK_IS_CLASS + a real proto chain and
    # must NOT be intercepted here.)
    if jsv_is_object_cell(jsobj)
        and jsv_to_table_id(jsobj) > 0
        and js_object_has_own(jsobj, KEY_CTOR_KIND) {
        # %Function.prototype% is itself an object-backed callable, but its [[Prototype]] is
        # %Object.prototype%, NOT itself — so for THAT object read its real prototype instead
        # of the callable fast-path (which returns %Function.prototype% and would self-loop).
        gpo_fnp: JSValue = js_function_get_proto();
        if jsv_is_object_cell(gpo_fnp)
            and jsv_to_table_id(jsobj) == jsv_to_table_id(gpo_fnp) {
            return js_object_get_prototype(jsobj);
        }
        return gpo_fnp;
    }
    # Derived class whose heritage is a plain function (fn_val): MAKE_CLASS stores
    # the parent in WK_SUPER but cannot install it as prototype_idx.  Surface that
    # as [[Prototype]] so Object.getPrototypeOf(class M extends Uint8Array) works
    # and static lookups (BYTES_PER_ELEMENT, etc.) can walk the chain.
    if jsv_is_object_cell(jsobj)
        and jsv_to_table_id(jsobj) > 0
        and js_object_has_own(jsobj, WK_IS_CLASS) {
        cls_proto_g: JSValue = js_object_get_prototype(jsobj);
        if jsv_is_null(cls_proto_g) and js_object_has_own(jsobj, WK_SUPER) {
            return js_object_get(jsobj, WK_SUPER);
        }
        return cls_proto_g;
    }
    if jsv_is_bigint_cell(jsobj) {
        bp: JSValue = js_bigint_get_proto();
        if not jsv_is_undefined(bp) {
            return bp;
        }
    }
    if jsv_is_symbol(jsobj) {
        sp: JSValue = js_symbol_get_proto();
        if not jsv_is_undefined(sp) {
            return sp;
        }
    }
    o: JSValue = jsobj;
    if not jsv_is_object_cell(jsobj) {
        o = _spec_to_object(jsobj);
    }
    return js_object_get_prototype(o);
}

"""
Object.setPrototypeOf(jsobj, proto). Returns jsobj.
ECMAScript §20.1.2.21
"""
def:pub js_Object_setPrototypeOf(jsobj: JSValue, proto: JSValue) -> JSValue {
    if jsv_is_null(jsobj) or jsv_is_undefined(jsobj) {
        vm_throw_native(
            make_type_error("Object.setPrototypeOf called on null or undefined")
        );
        return jsobj;
    }
    if fn_meta_is_closure(jsobj) {
        # A valid [[Prototype]] is null OR any object — and functions ARE objects, so
        # a function/closure proto (e.g. `setPrototypeOf(Ctor, TypedArray)` in
        # binary_types.js) must be accepted. `jsv_is_any_object` only covers
        # object/native cells, not user-function closures, so also allow those.
        if not (
            jsv_is_null(proto) or jsv_is_any_object(proto) or fn_meta_is_closure(proto)
        ) {
            vm_throw_native(
                make_type_error("Object prototype may only be an Object or null")
            );
            return jsobj;
        }
        if fn_meta_set_object_proto(jsobj, proto) != 0 {
            vm_throw_native(
                make_type_error("Object.setPrototypeOf: prototype change rejected")
            );
        }
        return jsobj;
    }
    o: JSValue = jsobj;
    if not jsv_is_object_cell(jsobj) {
        o = _spec_to_object(jsobj);
    }
    if not (
        jsv_is_null(proto) or jsv_is_any_object(proto) or fn_meta_is_closure(proto)
    ) {
        vm_throw_native(
            make_type_error("Object prototype may only be an Object or null")
        );
        return jsobj;
    }
    # Module Namespace Exotic [[SetPrototypeOf]] (ES §10.4.6.3): only null (the
    # current prototype) is accepted; any other value throws.
    if js_is_module_namespace(o) {
        if not jsv_is_null(proto) {
            vm_throw_native(
                make_type_error("Object.setPrototypeOf: prototype change rejected")
            );
        }
        return jsobj;
    }
    if js_object_set_prototype(o, proto) != 0 {
        vm_throw_native(
            make_type_error("Object.setPrototypeOf: prototype change rejected")
        );
    }
    return jsobj;
}

def:pub js_Object_preventExtensions(jsobj: JSValue) -> JSValue {
    if jsv_is_object_cell(jsobj) and jsv_to_table_id(jsobj) > 0 {
        js_object_prevent_extensions(jsobj);
    }
    return jsobj;
}

def:pub js_Object_isExtensible(jsobj: JSValue) -> bool {
    # Built-in / native dispatch functions are NativeFn cells — spec §10.3: extensible.
    if jsv_is_cell(jsobj) and jsv_cell_kind(jsobj) == JS_CELL_KIND_NATIVE {
        return True;
    }
    if not jsv_is_object_cell(jsobj) {
        return False;
    }
    return js_object_is_extensible(jsobj);
}

def:pub js_Reflect_getPrototypeOf(jsobj: JSValue) -> JSValue {
    # Reflect.getPrototypeOf throws on non-Object; Object.getPrototypeOf boxes primitives.
    if not (jsv_is_any_object(jsobj) or fn_meta_is_closure(jsobj)) {
        vm_throw_native(make_type_error("Reflect.getPrototypeOf called on non-object"));
        return js_undefined();
    }
    return js_Object_getPrototypeOf(jsobj);
}

def:pub js_Reflect_setPrototypeOf(jsobj: JSValue, proto: JSValue) -> bool {
    # Reflect.setPrototypeOf throws on non-Object (no boxing).
    if not (jsv_is_any_object(jsobj) or fn_meta_is_closure(jsobj)) {
        vm_throw_native(make_type_error("Reflect.setPrototypeOf called on non-object"));
        return False;
    }
    if not (
        jsv_is_null(proto) or jsv_is_any_object(proto) or fn_meta_is_closure(proto)
    ) {
        vm_throw_native(
            make_type_error("Object prototype may only be an Object or null")
        );
        return False;
    }
    # Module Namespace Exotic [[SetPrototypeOf]] (ES §10.4.6.3): succeeds only when
    # the requested prototype is the current one (null); otherwise returns false.
    if js_is_module_namespace(jsobj) {
        return jsv_is_null(proto);
    }
    if fn_meta_is_closure(jsobj) {
        return fn_meta_set_object_proto(jsobj, proto) == 0;
    }
    return js_object_set_prototype(jsobj, proto) == 0;
}

def:pub js_Reflect_defineProperty(
    jsobj: JSValue, key: JSValue, descriptor: JSValue
) -> bool {
    if not (jsv_is_any_object(jsobj) or fn_meta_is_closure(jsobj)) {
        vm_throw_native(make_type_error("Reflect.defineProperty called on non-object"));
        return False;
    }
    if not _is_desc_object(descriptor) {
        vm_throw_native(make_type_error("Property description must be an object"));
        return False;
    }
    # ToPropertyDescriptor + ValidateAndApply happen inside _define_property_inner
    # (via spec_to_property_descriptor / spec_validate_and_apply_descriptor) before
    # any mutation, so the earlier standalone _descriptor_is_invalid /
    # _validate_accessor_callables pre-checks HEAD had here are redundant.
    return _define_property_inner(jsobj, key, descriptor);
}

def:pub js_Reflect_ownKeys(jsobj: JSValue) -> JSValue {
    if not (jsv_is_any_object(jsobj) or fn_meta_is_closure(jsobj)) {
        vm_throw_native(make_type_error("Reflect.ownKeys called on non-object"));
        return _make_js_array([]);
    }
    return _make_js_array(_own_keys_ordered(jsobj));
}

"""Reflect.get — non-proxy fallback for dispatch (proxies use VM trap path)."""
def:pub js_Reflect_get(target: JSValue, key: JSValue, receiver: JSValue) -> JSValue {
    if not jsv_is_object_cell(target) {
        return js_undefined();
    }
    kid: int = _key_to_id(key);
    if jsv_is_undefined(receiver) {
        receiver = target;
    }
    return js_object_get_observable(target, kid, receiver);
}

"""Reflect.set — non-proxy fallback for dispatch (proxies use VM trap path)."""
def:pub js_Reflect_set(
    target: JSValue, key: JSValue, val: JSValue, receiver: JSValue
) -> bool {
    if not jsv_is_object_cell(target) {
        return False;
    }
    # Module Namespace Exotic Object [[Set]] (ES §10.4.6.9) — always fails.
    if js_is_module_namespace(target) {
        return False;
    }
    kid: int = _key_to_id(key);
    if jsv_is_undefined(receiver) {
        receiver = target;
    }
    return js_object_set_observable(target, kid, val, receiver);
}

"""Reflect.has(target, key) — §28.1.9. [[HasProperty]] including the prototype
chain.  Throws TypeError if target is not an object."""
def:pub js_Reflect_has(target: JSValue, key: JSValue) -> bool {
    if not jsv_is_object_cell(target) {
        vm_throw_native(make_type_error("Reflect.has called on non-object"));
        return False;
    }
    return js_object_has(target, _key_to_id(key));
}

"""Reflect.deleteProperty(target, key) — §28.1.4. [[Delete]]; returns the boolean
success.  Throws TypeError if target is not an object."""
def:pub js_Reflect_deleteProperty(target: JSValue, key: JSValue) -> bool {
    if not jsv_is_object_cell(target) {
        vm_throw_native(make_type_error("Reflect.deleteProperty called on non-object"));
        return False;
    }
    if js_is_module_namespace(target) {
        kid_rd: int = _key_to_id(key);
        if kid_rd >= SYMBOL_KEY_BASE {
            return js_object_delete(target, kid_rd);
        }
        if js_object_has_own(target, kid_rd) {
            return False;
        }
        return True;
    }
    return js_object_delete(target, _key_to_id(key));
}

"""Reflect.isExtensible(target) — §28.1.7.  Throws TypeError if not an object."""
def:pub js_Reflect_isExtensible(target: JSValue) -> bool {
    if not jsv_is_object_cell(target) {
        vm_throw_native(make_type_error("Reflect.isExtensible called on non-object"));
        return False;
    }
    return js_object_is_extensible(target);
}

"""Reflect.preventExtensions(target) — §28.1.11.  Returns boolean success.
Throws TypeError if not an object."""
def:pub js_Reflect_preventExtensions(target: JSValue) -> bool {
    if not jsv_is_object_cell(target) {
        vm_throw_native(
            make_type_error("Reflect.preventExtensions called on non-object")
        );
        return False;
    }
    return js_object_prevent_extensions(target) == 0;
}

"""Reflect.getOwnPropertyDescriptor(target, key) — §28.1.6.  Throws TypeError if
not an object; otherwise same result as Object.getOwnPropertyDescriptor."""
def:pub js_Reflect_getOwnPropertyDescriptor(target: JSValue, key: JSValue) -> JSValue {
    if not jsv_is_object_cell(target) {
        vm_throw_native(
            make_type_error("Reflect.getOwnPropertyDescriptor called on non-object")
        );
        return js_undefined();
    }
    return js_Object_getOwnPropertyDescriptor(target, key);
}

"""
Object.getOwnPropertyNames(jsobj) — array of all own property name strings,
including non-enumerable ones.  ECMAScript §20.1.2.10.
"""
def:pub js_Object_getOwnPropertyNames(jsobj: JSValue) -> JSValue {
    # ES §20.1.2.11: Let obj be ? ToObject(O).
    jsobj = _to_object_or_throw(jsobj);
    if vm_has_native_exc() {
        return js_undefined();
    }
    # ES §10.1.11.1 OrdinaryOwnPropertyKeys order: integer-index keys ascending,
    # then string keys in insertion order. js_object_all_keys returns raw insertion
    # order, so `{a, [1]:…, c, [2]:…}` mis-ordered as [a,1,c,2] instead of [1,2,a,c].
    key_ids: list[int] = js_object_own_key_ids_ordered(jsobj);
    filtered: list[int] = [];
    for kid in key_ids {
        if kid >= 0 and kid < BUILTIN_BASE {
            filtered.append(kid);
        }
    }
    if js_is_module_namespace(jsobj) {
        filtered = _sort_string_keys_by_codepoint(filtered);
    }
    items: list[JSValue] = [];
    for kid in filtered {
        items.append(_obj_js_str(str_from_id(kid)));
    }
    return _make_js_array(items);
}

"""
Object.getOwnPropertyDescriptor(jsobj, key) — descriptor object or undefined.

Returns { value, writable, enumerable, configurable } or undefined.
ECMAScript §20.1.2.9
"""
def:pub js_Object_getOwnPropertyDescriptor(jsobj: JSValue, key: JSValue) -> JSValue {
    # ES §20.1.2.8: Let obj be ? ToObject(O).
    jsobj = _to_object_or_throw(jsobj);
    if vm_has_native_exc() {
        return js_undefined();
    }
    kid: int = _key_to_id(key);
    # Array exotic [[GetOwnProperty]] — only materialized indices (holes → undefined).
    if js_is_array(jsobj) {
        aidx: int = _array_index_key_numeric(kid);
        if aidx >= 0 {
            alen: int = js_array_len(jsobj);
            if vm_has_native_exc() {
                return js_undefined();
            }
            if aidx < alen {
                if js_object_has_own_accessor(jsobj, kid) {
                    own_getter_a: JSValue = js_object_get_own_accessor_getter(
                        jsobj, kid
                    );
                    own_setter_a: JSValue = js_object_get_own_accessor_setter(
                        jsobj, kid
                    );
                    desc_a: JSValue = js_object_new_ordinary();
                    js_object_set(desc_a, str_intern("get"), own_getter_a);
                    js_object_set(desc_a, str_intern("set"), own_setter_a);
                    prop_a: JSProperty = js_object_get_own_property_descriptor(
                        jsobj, kid
                    );
                    js_object_set(
                        desc_a, str_intern("enumerable"), js_boolean(prop_a.enumerable)
                    );
                    js_object_set(
                        desc_a,
                        str_intern("configurable"),
                        js_boolean(prop_a.configurable)
                    );
                    return desc_a;
                }
                # Holes are not own properties — do not synthesize a descriptor.
                if not js_object_has_own(jsobj, kid) {
                    return js_undefined();
                }
                desc_el: JSValue = js_object_new_ordinary();
                js_object_set(desc_el, str_intern("value"), js_array_get(jsobj, aidx));
                if vm_has_native_exc() {
                    return js_undefined();
                }
                prop_el: JSProperty = js_object_get_own_property_descriptor(jsobj, kid);
                js_object_set(
                    desc_el, str_intern("writable"), js_boolean(prop_el.writable)
                );
                js_object_set(
                    desc_el, str_intern("enumerable"), js_boolean(prop_el.enumerable)
                );
                js_object_set(
                    desc_el,
                    str_intern("configurable"),
                    js_boolean(prop_el.configurable)
                );
                return desc_el;
            }
        }
    }
    # String exotic [[GetOwnProperty]] for integer-index code units.
    if is_string_object(jsobj) and js_string_exotic_has_index(jsobj, kid) {
        desc_s: JSValue = js_object_new_ordinary();
        js_object_set(
            desc_s, str_intern("value"), js_string_exotic_get_index(jsobj, kid)
        );
        js_object_set(desc_s, str_intern("writable"), js_false());
        js_object_set(desc_s, str_intern("enumerable"), js_true());
        js_object_set(desc_s, str_intern("configurable"), js_false());
        return desc_s;
    }
    # Own accessor (including get:undefined / set:undefined) before data descriptor.
    if js_object_has_own_accessor(jsobj, kid) {
        own_getter: JSValue = js_object_get_own_accessor_getter(jsobj, kid);
        own_setter: JSValue = js_object_get_own_accessor_setter(jsobj, kid);
        # Accessor descriptor: { get, set, enumerable, configurable }.  Ordinary
        # object (Object.prototype) per FromPropertyDescriptor (ES §6.2.6.4).
        desc: JSValue = js_object_new_ordinary();
        js_object_set(desc, str_intern("get"), own_getter);
        js_object_set(desc, str_intern("set"), own_setter);
        prop2: JSProperty = js_object_get_own_property_descriptor(jsobj, kid);
        js_object_set(desc, str_intern("enumerable"), js_boolean(prop2.enumerable));
        js_object_set(desc, str_intern("configurable"), js_boolean(prop2.configurable));
        return desc;
    }
    if not js_object_has_own(jsobj, kid) {
        return js_undefined();
    }
    prop: JSProperty = js_object_get_own_property_descriptor(jsobj, kid);
    return _descriptor_object(prop);
}

"""
Object.getOwnPropertyDescriptors(jsobj) — object mapping own keys to descriptors.
ECMAScript §20.1.2.10.
"""
def:pub js_Object_getOwnPropertyDescriptors(jsobj: JSValue) -> JSValue {
    # ES §20.1.2.9: Let obj be ? ToObject(O).
    jsobj = _to_object_or_throw(jsobj);
    if vm_has_native_exc() {
        return js_undefined();
    }
    out: JSValue = js_object_create_null();
    key_ids: list[int] = js_object_all_keys(jsobj);
    # String exotic indices are not in the data map — surface them first.
    if is_string_object(jsobj) {
        prim_g: JSValue = string_value_of(jsobj);
        s_g: str = str_from_id(jsv_to_table_id(prim_g));
        n_g: int = js_string_utf16_len(s_g);
        gi: int = 0;
        while gi < n_g {
            gkid: int = str_intern_index(gi);
            gdesc: JSValue = js_Object_getOwnPropertyDescriptor(
                jsobj, jsv_from_string_id(gkid)
            );
            if not jsv_is_undefined(gdesc) {
                js_object_set(out, gkid, gdesc);
            }
            gi = gi + 1;
        }
    }
    for kid in key_ids {
        if kid == _KEY_IS_ARRAY {
            continue;
        }
        if is_string_object(jsobj) and js_string_exotic_has_index(jsobj, kid) {
            continue;
        }
        key_v: JSValue = jsv_from_string_id(kid);
        if kid >= SYMBOL_KEY_BASE {
            key_v = jsv_from_symbol_id(kid - SYMBOL_KEY_BASE);
        }
        desc: JSValue = js_Object_getOwnPropertyDescriptor(jsobj, key_v);
        if not jsv_is_undefined(desc) {
            js_object_set(out, kid, desc);
        }
    }
    return out;
}

"""
OrdinaryDefineOwnProperty path for Object.defineProperty / Reflect.defineProperty.
Supports both data descriptors ({value, writable}) and accessor descriptors
({get, set}).  ECMAScript §10.1.6.
"""
def _current_descriptor_record(
    jsobj: JSValue, kid: int
) -> tuple[bool, PropertyDescriptorRecord] {
    prop: JSProperty = js_object_get_own_property_descriptor(jsobj, kid);
    if prop.deleted {
        return (False, PropertyDescriptorRecord());
    }
    if js_object_has_own_accessor(jsobj, kid) {
        return (
            True,
            PropertyDescriptorRecord(
                has_get=True,
                has_set=True,
                has_enumerable=True,
                has_configurable=True,
                get=js_object_get_own_accessor_getter(jsobj, kid),
                set=js_object_get_own_accessor_setter(jsobj, kid),
                enumerable=prop.enumerable,
                configurable=prop.configurable,
                is_accessor=True
            )
        );
    }
    return (
        True,
        PropertyDescriptorRecord(
            has_value=True,
            has_writable=True,
            has_enumerable=True,
            has_configurable=True,
            value=prop.value,
            writable=prop.writable,
            enumerable=prop.enumerable,
            configurable=prop.configurable,
            is_accessor=False
        )
    );
}

def _define_property_record_ordinary(
    jsobj: JSValue, kid: int, rec: PropertyDescriptorRecord
) -> bool {
    cur_pair: tuple[bool, PropertyDescriptorRecord] = _current_descriptor_record(
        jsobj, kid
    );
    current_exists: bool = cur_pair[0];
    current: PropertyDescriptorRecord = cur_pair[1];
    # ValidateAndApply runs to completion (or rejects) before any storage mutation,
    # so rejected accessor↔data / enumerable changes leave the property intact.
    applied_pair: tuple[bool, PropertyDescriptorRecord] = spec_validate_and_apply_descriptor(
        js_object_is_extensible(jsobj), rec, current, current_exists
    );
    if not applied_pair[0] {
        return False;
    }
    applied: PropertyDescriptorRecord = applied_pair[1];
    if applied.is_accessor {
        if current_exists and not current.is_accessor {
            # Keep key_order position for data→accessor (live Object.entries order).
            if not js_object_remove_own_keep_order(jsobj, kid) {
                return False;
            }
        }
        # ValidateAndApply succeeded — commit merged accessor fields only (no re-validate).
        # Install get/set first, then attributes — _register_accessor_key may seed
        # defaults, so always overwrite with the validated merged flags afterward.
        # Force getter-map presence even when [[Get]] is undefined so own-accessor
        # checks and Proxy get/has invariants see the property (dict stores may
        # drop undefined-valued entries; configurable/enumerable maps are the backup).
        js_object_set_accessor_getter(jsobj, kid, applied.get);
        js_object_set_accessor_setter(jsobj, kid, applied.set);
        js_object_set_accessor_enumerable(jsobj, kid, applied.enumerable);
        js_object_set_accessor_configurable(jsobj, kid, applied.configurable);
        return True;
    }
    if current_exists and current.is_accessor {
        if not js_object_remove_own_keep_order(jsobj, kid) {
            return False;
        }
    }
    prop: JSProperty = spec_data_record_to_jsproperty(applied);
    # Commit only — ValidateAndApply already succeeded; do not re-validate.
    return js_object_apply_validated_descriptor(jsobj, kid, prop) == 0;
}

def _descriptor_record_to_object(rec: PropertyDescriptorRecord) -> JSValue {
    descriptor: JSValue = js_object_create_null();
    if rec.has_enumerable {
        js_object_set(descriptor, str_intern("enumerable"), js_boolean(rec.enumerable));
    }
    if rec.has_configurable {
        js_object_set(
            descriptor, str_intern("configurable"), js_boolean(rec.configurable)
        );
    }
    if rec.has_value {
        js_object_set(descriptor, str_intern("value"), rec.value);
    }
    if rec.has_writable {
        js_object_set(descriptor, str_intern("writable"), js_boolean(rec.writable));
    }
    if rec.has_get {
        js_object_set(descriptor, str_intern("get"), rec.get);
    }
    if rec.has_set {
        js_object_set(descriptor, str_intern("set"), rec.set);
    }
    return descriptor;
}

def _define_property_inner_ordinary(
    jsobj: JSValue, kid: int, descriptor: JSValue
) -> bool {
    rec: PropertyDescriptorRecord = spec_to_property_descriptor(descriptor);
    if vm_has_native_exc() {
        return False;
    }
    if rec.is_invalid {
        if not vm_has_native_exc() {
            vm_throw_native(
                make_type_error(
                    "Invalid property descriptor. Cannot both specify accessors and a value or writable attribute"
                )
            );
        }
        return False;
    }
    # ValidateAndApply (incl. the accessor↔data conversion that preserves omitted
    # enumerable/configurable per §10.1.6.3 step 6.b — the Promise[@@species]
    # round-trip HEAD hand-rolled here) is handled centrally by
    # _define_property_record_ordinary → spec_validate_and_apply_descriptor.
    return _define_property_record_ordinary(jsobj, kid, rec);
}

"""
Module Namespace exotic [[DefineOwnProperty]] (ES §10.4.6.5).
Returns true only when Desc requests no change to an existing export / @@toStringTag.
"""
def _module_ns_define_own_property(
    jsobj: JSValue, kid: int, descriptor: JSValue
) -> bool {
    rec: PropertyDescriptorRecord = spec_to_property_descriptor(descriptor);
    if vm_has_native_exc() {
        return False;
    }
    if rec.is_invalid {
        if not vm_has_native_exc() {
            vm_throw_native(
                make_type_error(
                    "Invalid property descriptor. Cannot both specify accessors and a value or writable attribute"
                )
            );
        }
        return False;
    }
    # Symbol keys: ordinary DefineOwnProperty (only @@toStringTag is present).
    if kid >= SYMBOL_KEY_BASE {
        return _define_property_record_ordinary(jsobj, kid, rec);
    }
    cur_pair: tuple[bool, PropertyDescriptorRecord] = _current_descriptor_record(
        jsobj, kid
    );
    if not cur_pair[0] {
        return False;
    }
    current: PropertyDescriptorRecord = cur_pair[1];
    if rec.is_accessor {
        return False;
    }
    if rec.has_configurable and rec.configurable {
        return False;
    }
    if rec.has_enumerable and not rec.enumerable {
        return False;
    }
    if rec.has_writable and not rec.writable {
        return False;
    }
    if rec.has_value {
        # Resolve current value (data or live accessor getter).
        cur_val: JSValue = current.value;
        if current.is_accessor {
            g: JSValue = current.get;
            if is_native_val(g) {
                # Live ESM getter — read through native dispatch is not available
                # here; compare against the own data snapshot if any, else reject
                # non-SameValue by reading via js_object_get (triggers getter).
                cur_val = js_object_get(jsobj, kid);
            } else {
                cur_val = js_object_get(jsobj, kid);
            }
        }
        if not spec_same_value(rec.value, cur_val) {
            return False;
        }
    }
    return True;
}

"""
Object.defineProperty(jsobj, key, descriptor) — define or modify a property.
Routes Array exotic [[DefineOwnProperty]] for "length" and array-index keys (R6).
"""
def _define_property_inner(jsobj: JSValue, key: JSValue, descriptor: JSValue) -> bool {
    kid: int = _key_to_id(key);
    if js_is_module_namespace(jsobj) {
        return _module_ns_define_own_property(jsobj, kid, descriptor);
    }
    if is_string_object(jsobj) and js_string_exotic_has_index(jsobj, kid) {
        return False;
    }
    if js_is_array(jsobj) {
        # Prefer runtime-interned WK_LENGTH; KEY_LENGTH is the seeded compile-time id.
        if kid == KEY_LENGTH or kid == str_intern("length") {
            return js_array_define_length_property(jsobj, descriptor);
        }
        idx: int = _array_index_key_numeric(kid);
        if idx >= 0 {
            if not _array_index_write_allowed(jsobj, idx) {
                return False;
            }
            ok_idx: bool = _define_property_inner_ordinary(jsobj, kid, descriptor);
            if ok_idx {
                _array_grow_length_if_needed(jsobj, idx);
            }
            return ok_idx;
        }
    }
    return _define_property_inner_ordinary(jsobj, kid, descriptor);
}

def:pub js_Object_defineProperty(
    jsobj: JSValue, key: JSValue, descriptor: JSValue
) -> JSValue {
    if not jsv_is_object_cell(jsobj) {
        vm_throw_native(make_type_error("Object.defineProperty called on non-object"));
        return jsobj;
    }
    # ToPropertyDescriptor (ES §6.2.5.5): the Attributes argument must be an Object.
    if not _is_desc_object(descriptor) {
        vm_throw_native(make_type_error("Property description must be an object"));
        return jsobj;
    }
    # Invalid-descriptor and accessor-callable validation happen inside
    # _define_property_inner (spec_to_property_descriptor) before any mutation.
    if not _define_property_inner(jsobj, key, descriptor) {
        if not vm_has_native_exc() {
            kid: int = _key_to_id(key);
            vm_throw_native(
                make_type_error("Cannot redefine property: " + str_from_id(kid))
            );
        }
    }
    return jsobj;
}

"""
Object.defineProperties(jsobj, props) — define multiple properties.
ECMAScript §20.1.2.3
"""
def:pub js_Object_defineProperties(jsobj: JSValue, props: JSValue) -> JSValue {
    if not jsv_is_object_cell(jsobj) {
        vm_throw_native(
            make_type_error("Object.defineProperties called on non-object")
        );
        return jsobj;
    }
    # ES §20.1.2.3 / ObjectDefineProperties: props = ToObject(Properties), then
    # the shared two-phase collect+apply (validate all descriptors before any
    # mutation). adel_fixes' _object_define_properties_apply centralizes the
    # exotic-props / string-index / enumerable-filter handling HEAD open-coded here.
    props = _to_object_or_throw(props);
    if vm_has_native_exc() {
        return jsobj;
    }
    _ = _object_define_properties_apply(jsobj, props);
    return jsobj;
}

"""
Object.is(a, b) — SameValue comparison (stricter than ===).

NaN is same as NaN; +0 is not same as -0.
Bun Zig: JSC::sameValue()  JSC Operations.h
ECMAScript §20.1.2.13
"""
def:pub js_Object_is(a: JSValue, b: JSValue) -> bool {
    return _same_value(a, b);
}

"""
Object.hasOwn(jsobj, key) — ES2022 equivalent of jsobj.hasOwnProperty(key).
ECMAScript §20.1.2.2 (ES2022)
"""
def:pub js_Object_hasOwn(jsobj: JSValue, key: JSValue) -> bool {
    # ES §20.1.2.2: ToObject(O), then ToPropertyKey(P), then HasOwnProperty.
    jsobj = _to_object_or_throw(jsobj);
    if vm_has_native_exc() {
        return False;
    }
    return js_object_has_own(jsobj, _key_to_id(key));
}

"""
Object.fromEntries(iterable) — inverse of Object.entries().

Accepts a JS Array of [key, value] pair arrays (the format produced by
js_Object_entries) and returns a new object.

Full iterator protocol not yet implemented; this handles the common
array-of-pairs case.
ECMAScript §20.1.2.7
"""
def:pub js_Object_fromEntries(iterable: JSValue) -> JSValue {
    result: JSValue = js_object_create_null();
    if not jsv_is_object_cell(iterable) {
        return result;
    }
    n: int = js_array_len(iterable);
    i: int = 0;
    while i < n {
        pair: JSValue = _js_array_get(iterable, i);
        if jsv_is_object_cell(pair) {
            k: JSValue = _js_array_get(pair, 0);
            v: JSValue = _js_array_get(pair, 1);
            js_object_set(result, _key_to_id(k), v);
        }
        i = i + 1;
    }
    return result;
}

# ══════════════════════════════════════════════════════════════════════════════
# 4.  Prototype methods
# ══════════════════════════════════════════════════════════════════════════════

"""Unwrap Proxy targets for builtin [[Class]] tag detection."""
def _to_string_brand_object(v: JSValue) -> JSValue {
    cur: JSValue = v;
    while js_is_proxy(cur) {
        if js_proxy_is_revoked(cur) {
            return cur;
        }
        cur = js_proxy_target(cur);
    }
    return cur;
}

"""
Object.prototype.toString() — "[object Type]" tag string.

Bun Zig: JSObject::toString()
ECMAScript §20.1.3.6 (@@toStringTag)
"""
def:pub js_Object_prototype_toString(this_val: JSValue) -> JSValue {
    if jsv_is_undefined(this_val) {
        return _obj_js_str("[object Undefined]");
    }
    if jsv_is_null(this_val) {
        return _obj_js_str("[object Null]");
    }
    o: JSValue = this_val;
    if not jsv_is_object_cell(this_val) and not js_is_proxy(this_val) {
        o = js_Object([this_val]);
    }
    # ES §20.1.3.6 steps 14–15: prefer @@toStringTag (incl. inherited / Proxy get)
    # before builtin brand. Revoked proxies throw on [[Get]].
    tag_key: int = SYMBOL_KEY_BASE + SYMBOL_TO_STRING_TAG;
    tv: JSValue = js_object_get_observable(o, tag_key, o);
    if vm_has_native_exc() {
        return js_undefined();
    }
    if jsv_is_string_cell(tv) {
        return _obj_js_str("[object " + str_from_id(jsv_to_table_id(tv)) + "]");
    }
    brand_o: JSValue = _to_string_brand_object(o);
    tag: str = "Object";
    if js_is_proxy(this_val) and js_proxy_is_callable(this_val) {
        ft: str = fn_meta_builtin_to_string_tag(brand_o);
        if ft != "" {
            tag = ft;
        } elif is_native_val(brand_o) or fn_meta_is_closure(brand_o) {
            tag = "Function";
        }
    } elif jsv_is_bool(this_val) or is_boolean_object(o) {
        tag = "Boolean";
    } elif jsv_is_number(this_val) or is_number_object(o) {
        tag = "Number";
    } elif jsv_is_string_cell(this_val) or is_string_object(o) {
        tag = "String";
    } elif jsv_is_bigint_cell(this_val)
        or not jsv_is_undefined(_object_wrapper_unbox(o))
        and jsv_is_bigint_cell(_object_wrapper_unbox(o)) {
        tag = "BigInt";
    } elif jsv_is_symbol(this_val)
        or not jsv_is_undefined(_object_wrapper_unbox(o))
        and jsv_is_symbol(_object_wrapper_unbox(o)) {
        tag = "Symbol";
    } elif jsv_coerce_to_bool(js_is_array(brand_o)) {
        tag = "Array";
    } elif js_is_map(brand_o) {
        tag = "Map";
    } elif js_is_set(brand_o) {
        tag = "Set";
    } elif js_is_weakmap(brand_o) {
        tag = "WeakMap";
    } elif js_is_weakset(brand_o) {
        tag = "WeakSet";
    } elif fn_meta_is_closure(this_val) or is_native_val(this_val) {
        ft2: str = fn_meta_builtin_to_string_tag(this_val);
        if ft2 != "" {
            tag = ft2;
        } else {
            tag = "Function";
        }
    } elif jsv_is_object_cell(o)
        and jsv_to_table_id(o) > 0
        and (
            js_object_has_own(o, KEY_CTOR_KIND) or js_object_has_own(o, WK_IS_CLASS)
        ) {
        tag = "Function";
    } else {
        ta_name_v: JSValue = js_object_get(o, str_intern("_typedArrayName"));
        if jsv_is_string_cell(ta_name_v) {
            return _obj_js_str(
                "[object " + str_from_id(jsv_to_table_id(ta_name_v)) + "]"
            );
        }
    }
    return _obj_js_str("[object " + tag + "]");
}

"""
Object.prototype.hasOwnProperty(key) — own property test.
ECMAScript §20.1.3.2
"""
def:pub js_Object_prototype_hasOwnProperty(this_val: JSValue, key: JSValue) -> JSValue {
    o: JSValue = _proto_to_object(this_val);
    if vm_has_native_exc() {
        return js_undefined();
    }
    return js_boolean(js_object_has_own(o, _key_to_id(key)));
}

"""
ToObject for Annex B Object.prototype methods. Throws TypeError on null/undefined.
"""
def _proto_to_object(v: JSValue) -> JSValue {
    if jsv_is_null(v) or jsv_is_undefined(v) {
        vm_throw_native(make_type_error("Cannot convert undefined or null to object"));
        return js_undefined();
    }
    return _spec_to_object(v);
}

"""
Object.prototype.__lookupGetter__(P) — Annex B.2.2.4
ToObject(this), ToPropertyKey(P), walk [[Prototype]] for an accessor [[Get]].
"""
def:pub js_Object_prototype_lookupGetter(this_val: JSValue, key: JSValue) -> JSValue {
    o: JSValue = _proto_to_object(this_val);
    if vm_has_native_exc() {
        return js_undefined();
    }
    return js_object_lookup_getter(o, _key_to_id(key));
}

"""
Object.prototype.__lookupSetter__(P) — Annex B.2.2.5
ToObject(this), ToPropertyKey(P), walk [[Prototype]] for an accessor [[Set]].
"""
def:pub js_Object_prototype_lookupSetter(this_val: JSValue, key: JSValue) -> JSValue {
    o: JSValue = _proto_to_object(this_val);
    if vm_has_native_exc() {
        return js_undefined();
    }
    return js_object_lookup_setter(o, _key_to_id(key));
}

"""
Object.prototype.__defineGetter__(P, getter) — Annex B.2.2.2
DefinePropertyOrThrow with enumerable/configurable accessor get.
"""
def:pub js_Object_prototype_defineGetter(
    this_val: JSValue, key: JSValue, get_fn: JSValue
) -> JSValue {
    o: JSValue = _proto_to_object(this_val);
    if vm_has_native_exc() {
        return js_undefined();
    }
    if not _accessor_is_callable(get_fn) or jsv_is_undefined(get_fn) {
        vm_throw_native(
            make_type_error(
                "Object.prototype.__defineGetter__: getter must be a function"
            )
        );
        return js_undefined();
    }
    desc: JSValue = js_object_new_ordinary();
    js_object_set(desc, str_intern("get"), get_fn);
    js_object_set(desc, str_intern("enumerable"), js_true());
    js_object_set(desc, str_intern("configurable"), js_true());
    js_Object_defineProperty(o, key, desc);
    return js_undefined();
}

"""
Object.prototype.__defineSetter__(P, setter) — Annex B.2.2.3
DefinePropertyOrThrow with enumerable/configurable accessor set.
"""
def:pub js_Object_prototype_defineSetter(
    this_val: JSValue, key: JSValue, set_fn: JSValue
) -> JSValue {
    o: JSValue = _proto_to_object(this_val);
    if vm_has_native_exc() {
        return js_undefined();
    }
    if not _accessor_is_callable(set_fn) or jsv_is_undefined(set_fn) {
        vm_throw_native(
            make_type_error(
                "Object.prototype.__defineSetter__: setter must be a function"
            )
        );
        return js_undefined();
    }
    desc: JSValue = js_object_new_ordinary();
    js_object_set(desc, str_intern("set"), set_fn);
    js_object_set(desc, str_intern("enumerable"), js_true());
    js_object_set(desc, str_intern("configurable"), js_true());
    js_Object_defineProperty(o, key, desc);
    return js_undefined();
}

# Merge note: a second identical copy of _proto_to_object + the four Annex-B
# __lookup*/__define* methods was auto-merged in here; removed as a duplicate of
# the block above (it caused a native-link symbol collision).

"""
Object.prototype.isPrototypeOf(v) — prototype chain membership test.
ECMAScript §20.1.3.3
"""
def:pub js_Object_prototype_isPrototypeOf(this_val: JSValue, v: JSValue) -> JSValue {
    if not jsv_is_object_cell(this_val) {
        return js_false();
    }
    # Functions / natives are objects for [[Prototype]] purposes (ES §10.2 /
    # Function.prototype.isPrototypeOf(boundFn)).
    current: JSValue = js_undefined();
    if jsv_is_object_cell(v) {
        current = js_object_get_prototype(v);
    } elif fn_meta_is_closure(v) or is_native_val(v) {
        current = js_function_get_proto();
    } else {
        return js_false();
    }
    while jsv_is_object_cell(current) {
        if js_strict_equal(current, this_val) {
            return js_true();
        }
        current = js_object_get_prototype(current);
    }
    return js_false();
}

"""
Object.prototype.propertyIsEnumerable(key) — own enumerable check.
ECMAScript §20.1.3.4
"""
def:pub js_Object_prototype_propertyIsEnumerable(
    this_val: JSValue, key: JSValue
) -> JSValue {
    o: JSValue = _proto_to_object(this_val);
    if vm_has_native_exc() {
        return js_undefined();
    }
    desc: JSValue = js_Object_getOwnPropertyDescriptor(o, key);
    if jsv_is_undefined(desc) {
        return js_false();
    }
    ev: JSValue = js_object_get(desc, str_intern("enumerable"));
    return js_boolean(jsv_coerce_to_bool(ev));
}

"""
Object.getOwnPropertySymbols(jsobj) — array of own symbol property keys.
ECMAScript §20.1.2.11
"""
def:pub js_Object_getOwnPropertySymbols(jsobj: JSValue) -> JSValue {
    # ES §20.1.2.12: Let obj be ? ToObject(O).
    jsobj = _to_object_or_throw(jsobj);
    if vm_has_native_exc() {
        return js_undefined();
    }
    key_ids: list[int] = js_object_all_keys(jsobj);
    items: list[JSValue] = [];
    for kid in key_ids {
        if kid >= SYMBOL_KEY_BASE {
            prop: JSProperty = js_object_get_own_property_descriptor(jsobj, kid);
            if not prop.deleted {
                items.append(jsv_from_symbol_id(kid - SYMBOL_KEY_BASE));
            }
        }
    }
    return _make_js_array(items);
}
