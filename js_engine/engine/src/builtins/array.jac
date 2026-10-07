"""
Built-in: Array constructor, static methods, and prototype methods.

Internally, an Array is a regular JSObject (tag=Object, stored in _OBJECT_TABLE)
distinguished from plain objects by a hidden IS_ARRAY marker property.

Element storage layout:
  - Index i is stored at property key str_intern(str(i))  (e.g. str_intern("0") = 0)
    matching the VM's GET_INDEX / SET_INDEX opcode semantics.
  - KEY_LENGTH (= 3, pre-seeded as KEY_LENGTH) stores the length as a JSInt.
  - _KEY_IS_ARRAY (= 1_000_001) is a hidden Boolean marker written at creation
    so that js_is_array() can distinguish arrays from plain objects without
    touching JSObject.class_id.

Callback-taking methods (forEach, map, filter, reduce, find*, some, every,
flatMap) are stubbed — they accept a JSValue callback parameter but cannot
invoke it integrates the VM dispatcher.  The stubs return
semantically-correct empty results (see individual doc comments).

Bun reference   : bun/src/js/builtins/ArrayConstructor.ts
                  JSC JSArray.cpp / ArrayPrototype.cpp
ECMAScript spec : §23.1 — Array Objects
                  https://tc39.es/ecma262/#sec-array-objects
"""

import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    js_true,
    js_false,
    js_boolean,
    js_int,
    js_number,
    MATH_INF,
    MATH_NEG_INF,
    MATH_NAN,
    js_strict_equal,
    jsv_undefined,
    jsv_hole,
    jsv_is_undefined,
    jsv_is_null,
    jsv_is_bool,
    jsv_is_int32,
    jsv_is_double,
    jsv_is_hole,
    jsv_is_number,
    jsv_is_object_cell,
    jsv_is_string_cell,
    jsv_is_symbol,
    jsv_is_cell,
    jsv_cell_kind,
    JS_CELL_KIND_NATIVE,
    jsv_is_bigint_cell,
    jsv_to_bool,
    jsv_to_int32,
    jsv_to_double,
    jsv_to_table_id,
    jsv_from_string_id,
    jsv_coerce_to_bool
}
import from engine.src.runtime.jsobject {
    js_object_create_null,
    js_object_create,
    js_object_get,
    js_object_set,
    js_object_set_flags,
    js_object_delete,
    js_object_has_own,
    js_object_define_property,
    js_object_all_keys,
    js_object_get_own_property_descriptor,
    js_object_table_get,
    js_object_elems_kind_id,
    js_object_brand,
    js_object_dense_elem,
    KEY_LENGTH,
    js_object_dense_set_present
}
import from engine.src.runtime.jsobj_type {
    JSObject,
    ELEMS_NONE,
    ELEMS_DENSE,
    ELEMS_HOLEY,
    dense_gate_enabled,
    idx_protector_ok,
    MAP_MODE_SHAPE,
    BRAND_ARRAY
}
import from engine.src.runtime.shape { shape_lookup, SHAPE_ATTR_ACCESSOR }
import from engine.src.runtime.wk_keys { WK_LENGTH }
import from engine.src.runtime.obs_context { obs_is_active }
import from engine.src.vm.vm_obs {
    js_object_get_observable,
    js_object_set_observable,
    js_object_has_observable,
    js_object_delete_observable,
    js_to_number_observable
}
import from engine.src.runtime.jsobj_type {
    PROP_WRITABLE,
    PROP_ENUMERABLE,
    PROP_CONFIGURABLE,
    PROP_DEFAULT,
    JSProperty
}
import from engine.src.runtime.jsstring {
    str_intern_index,
    str_intern,
    str_heap,
    str_from_id,
    str_to_float,
    str_substr
}
import from engine.src.runtime.error {
    make_range_error,
    make_type_error,
    vm_throw_native,
    vm_has_native_exc
}
import from engine.src.runtime.encoding { SYMBOL_KEY_BASE }
import from engine.src.runtime.jssymbol { SYMBOL_ISOONCATSPREADABLE }
import from engine.src.builtins.native_registry { is_native_val }
import from engine.src.builtins.markers { KEY_CTOR_KIND }
import from engine.src.runtime.proxy {
    js_is_proxy,
    js_proxy_is_revoked,
    js_proxy_target
}
import from engine.src.runtime.dtoa { number_to_string_radix10 }

# ══════════════════════════════════════════════════════════════════════════════
# 1.  Constants
# ══════════════════════════════════════════════════════════════════════════════

import from engine.src.builtins.markers { _KEY_IS_ARRAY }
import from engine.src.runtime.gc_pin { gc_pin_value }

"""Internal: object-table index of Array.prototype, wired by init_global."""
glob _ARRAY_PROTO: JSValue = jsv_undefined();

"""Called once by init_global to wire Array.prototype onto all future arrays."""
def:pub js_array_set_proto(proto: JSValue) {
    _ARRAY_PROTO = proto;
    gc_pin_value(proto);  # glob-held singleton — invisible to the GC root walk
}

"""Return the canonical Array.prototype handle (or undefined before bootstrap).
Used by the VM iterator fast paths to consult the live @@iterator slot so that
`delete`/override of `Array.prototype[Symbol.iterator]` is honoured even though
arrays are created null-proto for performance."""
def:pub js_array_get_proto -> JSValue {
    return _ARRAY_PROTO;
}

# ══════════════════════════════════════════════════════════════════════════════
# 2.  Core array primitives
# ══════════════════════════════════════════════════════════════════════════════

"""
Create a JS Array JSValue from a list of JSValues.

Sets _KEY_IS_ARRAY marker, stores elements at str_intern(str(i)), and sets
KEY_LENGTH.  Returns a JSValue with tag=Object pointing into _OBJECT_TABLE.
ECMAScript §23.1.1.1
"""
def:pub js_array_create(elements: list[JSValue]) -> JSValue {
    arr: JSValue = js_object_create(_ARRAY_PROTO)
        if jsv_is_object_cell(_ARRAY_PROTO)
        else js_object_create_null();
    js_object_set(arr, _KEY_IS_ARRAY, js_true());
    n: int = len(elements);
    if dense_gate_enabled() {
        arr_raw: JSObject = js_object_table_get(jsv_to_table_id(arr));
        arr_raw.elems_kind = ELEMS_DENSE;
        di: int = 0;
        while di < n {
            if jsv_is_hole(elements[di]) {
                arr_raw.elems_kind = ELEMS_HOLEY;
            }
            arr_raw.elems_rw().append(elements[di]);
            di = di + 1;
        }
    } else {
        i: int = 0;
        # Store elements at str_intern("0"), str_intern("1"), ... to match VM GET_INDEX
        while i < n {
            if not jsv_is_hole(elements[i]) {
                js_object_set(arr, str_intern_index(i), elements[i]);
            }
            i = i + 1;
        }
    }
    js_object_set_flags(arr, WK_LENGTH, js_array_len_value(n), PROP_WRITABLE);
    return arr;
}

"""Create a sparse array with the given length and no indexed properties."""
def:pub js_array_create_with_length(length: int) -> JSValue {
    arr: JSValue = js_object_create(_ARRAY_PROTO)
        if jsv_is_object_cell(_ARRAY_PROTO)
        else js_object_create_null();
    js_object_set(arr, _KEY_IS_ARRAY, js_true());
    if dense_gate_enabled() {
        arr_raw2: JSObject = js_object_table_get(jsv_to_table_id(arr));
        arr_raw2.elems_kind = ELEMS_DENSE;  # empty dense range; length prop carries the holes
    }
    js_object_set_flags(arr, KEY_LENGTH, js_array_len_value(length), PROP_WRITABLE);
    return arr;
}

"""
Promote an existing object (already created with the subclass prototype) to
Array-exotic in place — used when class Sub extends Array calls super().
Mirrors js_Array(args) element/length semantics without replacing this.
"""
def:pub js_array_init_exotic_from_args(o: JSValue, args: list[JSValue]) {
    js_object_set(o, _KEY_IS_ARRAY, js_true());
    if len(args) == 0 {
        js_object_set_flags(o, KEY_LENGTH, js_array_len_value(0), PROP_WRITABLE);
        return;
    }
    if len(args) == 1 {
        singlearg: JSValue = args[0];
        if jsv_is_int32(singlearg) {
            n: int = jsv_to_int32(singlearg);
            if n < 0 {
                vm_throw_native(make_range_error("Invalid array length"));
                return;
            }
            js_object_set_flags(o, KEY_LENGTH, js_array_len_value(n), PROP_WRITABLE);
            return;
        }
        if jsv_is_double(singlearg) {
            dv: float = jsv_to_double(singlearg);
            iv: int = int(dv) & 4294967295;
            if float(iv) != dv {
                vm_throw_native(make_range_error("Invalid array length"));
                return;
            }
            js_object_set_flags(o, KEY_LENGTH, js_array_len_value(iv), PROP_WRITABLE);
            return;
        }
    }
    n: int = len(args);
    if dense_gate_enabled() {
        o_raw: JSObject = js_object_table_get(jsv_to_table_id(o));
        if o_raw.elems_kind == ELEMS_NONE and len(o_raw.elems_ro()) == 0 {
            o_raw.elems_kind = ELEMS_DENSE;
            xi: int = 0;
            while xi < n {
                if jsv_is_hole(args[xi]) {
                    o_raw.elems_kind = ELEMS_HOLEY;
                }
                o_raw.elems_rw().append(args[xi]);
                xi = xi + 1;
            }
            js_object_set_flags(o, KEY_LENGTH, js_array_len_value(n), PROP_WRITABLE);
            return;
        }
    }
    i: int = 0;
    while i < n {
        if not jsv_is_hole(args[i]) {
            js_object_set(o, str_intern_index(i), args[i]);
        }
        i = i + 1;
    }
    js_object_set_flags(o, KEY_LENGTH, js_array_len_value(n), PROP_WRITABLE);
}

"""Return True if the array has an own property at index idx (not a hole)."""
def:pub js_array_has_index(arr: JSValue, idx: int) -> bool {
    return js_object_has_own(arr, str_intern_index(idx));
}

"""Return the element at index idx (0-based), or undefined if out of bounds."""
def:pub js_array_get(arr: JSValue, idx: int) -> JSValue {
    if idx >= 0 and jsv_is_object_cell(arr) {
        ag_id: int = jsv_to_table_id(arr);
        if ag_id > 0 {
            ag_raw: JSObject = js_object_table_get(ag_id);
            if ag_raw.elems_kind != ELEMS_NONE {
                if idx < len(ag_raw.elems_ro()) {
                    ag_v: JSValue = ag_raw.elems_ro()[idx];
                    if not jsv_is_hole(ag_v) {
                        return ag_v;
                    }
                }
                # Hole / past the dense range: undefined without a prototype
                # walk while no prototype anywhere carries index props.
                if idx_protector_ok() {
                    return jsv_undefined();
                }
            }
        }
    }
    return js_object_get_observable(arr, str_intern_index(idx), arr);
}

"""Set the element at index idx.  Grows the array if idx >= length."""
def:pub js_array_set(arr: JSValue, idx: int, val: JSValue) {
    if idx >= 0 and jsv_is_object_cell(arr) {
        as_id: int = jsv_to_table_id(arr);
        if as_id > 0 {
            as_raw: JSObject = js_object_table_get(as_id);
            if as_raw.elems_kind != ELEMS_NONE
                and idx < len(as_raw.elems_ro())
                and not jsv_is_hole(as_raw.elems_ro()[idx]) {
                # Own writable data element: no length change, no prototype
                # consultation possible.
                as_raw.elems_rw()[idx] = val;
                return;
            }
        }
    }
    if js_is_array(arr) and not _array_index_write_allowed(arr, idx) {
        return;
    }
    ik: int = str_intern_index(idx);
    js_object_set_observable(arr, ik, val, arr);
    if vm_has_native_exc() {
        return;
    }
    if js_is_array(arr) {
        _array_grow_length_if_needed(arr, idx);
    }
}

"""Append a single item to the end of an array (push one element).

Internal-only: this is CreateDataProperty, not Set. Callers are engine
bookkeeping structures — most importantly a promise's reaction list — whose
writes must not be observable by user code. Routing through js_array_set called
js_object_set_observable, so an accessor installed on Array.prototype (e.g.
`Object.defineProperty(Array.prototype, 0, {set(){}})`) swallowed the element:
the reaction stored at index 0 was silently dropped and the first `then` handler
registered on any pending promise never ran."""
def:pub js_array_push(arr: JSValue, item: JSValue) -> None {
    if jsv_is_object_cell(arr) and idx_protector_ok() {
        ap_id: int = jsv_to_table_id(arr);
        if ap_id > 0 {
            ap_raw: JSObject = js_object_table_get(ap_id);
            if ap_raw.elems_kind != ELEMS_NONE
                and ap_raw.is_ext()
                and ap_raw.mode == MAP_MODE_SHAPE {
                ap_pk: int = shape_lookup(ap_raw.shape_id, WK_LENGTH);
                if ap_pk >= 0
                    and (ap_pk & SHAPE_ATTR_ACCESSOR) == 0
                    and (ap_pk & 1) != 0 {
                    ap_len_v: JSValue = ap_raw.slots[ap_pk // 16];
                    # Push appends at `length` — only a pure append when the
                    # dense range reaches exactly that far (no trailing holes).
                    if jsv_is_int32(ap_len_v)
                        and jsv_to_int32(ap_len_v) == len(ap_raw.elems_ro()) {
                        ap_raw.elems_rw().append(item);
                        ap_raw.slots[ap_pk // 16] = js_array_len_value(
                            len(ap_raw.elems_ro())
                        );
                        return;
                    }
                }
            }
        }
    }
    n: int = js_array_len(arr);
    ik: int = str_intern_index(n);
    js_object_define_property(
        arr,
        ik,
        JSProperty(
            key=ik,
            value=item,
            writable=True,
            enumerable=True,
            configurable=True,
            deleted=False
        )
    );
    if js_is_array(arr) {
        _array_grow_length_if_needed(arr, n);
    }
}

"""Return the length of the array as a Jac int (LengthOfArrayLike)."""
def:pub js_array_len(arr: JSValue) -> int {
    return _length_of(arr);
}

"""Return True if v is a JS Array (has the _KEY_IS_ARRAY marker)."""
def:pub js_is_array(v: JSValue) -> bool {
    if not jsv_is_object_cell(v) {
        return False;
    }
    # Dense/holey elems exist only on arrays — O(1) for the common case;
    # sparse (ensure_sparse'd) arrays still answer via the marker probe.
    ia_id: int = jsv_to_table_id(v);
    if ia_id <= 0 {
        return False;
    }
    # Scalar field reads — no JSObject reference taken.
    return js_object_elems_kind_id(ia_id) != ELEMS_NONE
        or (js_object_brand(v) & BRAND_ARRAY) != 0;
}

"""
IsArray(argument) — ECMAScript §7.2.2.

Recurses through Proxy targets. Throws TypeError via the native exception
channel for a revoked Proxy. Shared by Array.isArray and VM species/flat paths.
"""
def:pub js_is_array_spec(v: JSValue) -> bool {
    if js_is_array(v) {
        return True;
    }
    if js_is_proxy(v) {
        if js_proxy_is_revoked(v) {
            vm_throw_native(
                make_type_error(
                    "Cannot perform 'IsArray' on a proxy that has been revoked"
                )
            );
            return False;
        }
        return js_is_array_spec(js_proxy_target(v));
    }
    return False;
}

# ══════════════════════════════════════════════════════════════════════════════
# 2b.  Array exotic length / index helpers (R6 — §10.4.2.1 / §10.4.2.4)
# ══════════════════════════════════════════════════════════════════════════════

"""Pack an array length as a JS number exact for every valid length in [0, 2^32-1].

Values that fit in int32 use the int32 tag; larger values (up to 2^32-1) use
float64 so they are not sign-extended on read (js_int(4294967295) → -1).
"""
def:pub js_array_len_value(n: int) -> JSValue {
    if n >= 0 and n <= 2147483647 {
        return js_int(n);
    }
    return js_number(float(n));
}

"""Read a stored length property value back to a Jac int (int32 or float64)."""
def:pub _array_len_from_value(v: JSValue) -> int {
    if jsv_is_int32(v) {
        iv: int = jsv_to_int32(v);
        if iv < 0 {
            return 0;
        }
        return iv;
    }
    if jsv_is_double(v) {
        d: float = jsv_to_double(v);
        if not (d == d) {
            return 0;
        }
        if d <= 0.0 {
            return 0;
        }
        return int(d);
    }
    return 0;
}

"""Canonical array-index key → numeric index, or -1 if not an array index.

An array index is a canonical decimal string for an integer in [0, 2^32-2]
(ECMAScript §6.1.7: array index < 2^32-1).
"""
def:pub _array_index_key_numeric(kid: int) -> int {
    if kid < 0 {
        return -1;
    }
    s: str = str_from_id(kid);
    sn: int = len(s);
    if sn == 0 {
        return -1;
    }
    # Byte reads, no substrings: this runs on every property get on a string
    # (String-exotic index check) and on array index probes, and a method name
    # like `charCodeAt` used to cost two 1-char substring allocations to reject.
    c0: int = ord(s[0]);
    if c0 < 48 or c0 > 57 {
        return -1;
    }
    if c0 == 48 {
        return 0 if sn == 1 else -1;
    }  # "0" only; no leading zeros
    np: int = 0;
    pi: int = 0;
    while pi < sn {
        pc: int = ord(s[pi]);
        if pc < 48 or pc > 57 {
            return -1;
        }
        np = np * 10 + (pc - 48);
        if np >= 4294967295 {
            return -1;
        }
        pi = pi + 1;
    }
    return np;
}

"""Stable ascending merge sort of `payload` by parallel integer `keys`.

O(n log n). Both lists must be the same length; `keys[i]` is the sort key of
`payload[i]`. Returns the payload reordered by ascending key (stable on ties).
Keys are precomputed ints, so the comparator is a plain `<` — no per-compare
re-parsing. Shared by array-length truncation and Object own-key ordering, both
of which previously used O(n^2) insertion/selection sorts."""
def:pub _sort_payload_by_int_key(keys: list[int], payload: list[int]) -> list[int] {
    n: int = len(payload);
    if n <= 1 {
        return payload;
    }
    # Bottom-up merge sort over index positions, carrying (key, payload) together.
    ks: list[int] = [];
    ps: list[int] = [];
    i: int = 0;
    while i < n {
        ks.append(keys[i]);
        ps.append(payload[i]);
        i = i + 1;
    }
    tmp_k: list[int] = [];
    tmp_p: list[int] = [];
    i = 0;
    while i < n {
        tmp_k.append(0);
        tmp_p.append(0);
        i = i + 1;
    }
    width: int = 1;
    while width < n {
        lo: int = 0;
        while lo < n {
            mid: int = lo + width;
            hi: int = lo + width + width;
            if mid > n {
                mid = n;
            }
            if hi > n {
                hi = n;
            }
            a: int = lo;
            b: int = mid;
            o: int = lo;
            while a < mid and b < hi {
                # `<=` on the left key keeps the sort stable.
                if ks[a] <= ks[b] {
                    tmp_k[o] = ks[a];
                    tmp_p[o] = ps[a];
                    a = a + 1;
                } else {
                    tmp_k[o] = ks[b];
                    tmp_p[o] = ps[b];
                    b = b + 1;
                }
                o = o + 1;
            }
            while a < mid {
                tmp_k[o] = ks[a];
                tmp_p[o] = ps[a];
                a = a + 1;
                o = o + 1;
            }
            while b < hi {
                tmp_k[o] = ks[b];
                tmp_p[o] = ps[b];
                b = b + 1;
                o = o + 1;
            }
            lo = lo + width + width;
        }
        # Swap buffers: tmp becomes the sorted source for the next pass.
        j: int = 0;
        while j < n {
            ks[j] = tmp_k[j];
            ps[j] = tmp_p[j];
            j = j + 1;
        }
        width = width + width;
    }
    return ps;
}

"""
Array exotic [[OwnPropertyKeys]] — virtual indices 0..length-1, then other own keys.
"""
def:pub js_array_own_key_ids(arr: JSValue) -> list[int] {
    out: list[int] = [];
    n: int = _length_of(arr);
    if vm_has_native_exc() {
        return [];
    }
    i: int = 0;
    while i < n {
        out.append(str_intern_index(i));
        i = i + 1;
    }
    extra_indices: list[int] = [];
    strings: list[int] = [];
    symbols: list[int] = [];
    for key in js_object_all_keys(arr) {
        if key == _KEY_IS_ARRAY or key < 0 {
            continue;
        }
        if key >= SYMBOL_KEY_BASE {
            symbols.append(key);
            continue;
        }
        idx: int = _array_index_key_numeric(key);
        if idx >= 0 {
            if idx >= n {
                extra_indices.append(key);
            }
            continue;
        }
        strings.append(key);
    }
    if len(extra_indices) > 0 {
        # Ascending numeric order for own index keys at or beyond length.
        ei: int = 1;
        en: int = len(extra_indices);
        while ei < en {
            ej: int = ei - 1;
            while ej >= 0
                and _array_index_key_numeric(extra_indices[ej + 1])
                    < _array_index_key_numeric(extra_indices[ej]) {
                tmp: int = extra_indices[ej];
                extra_indices[ej] = extra_indices[ej + 1];
                extra_indices[ej + 1] = tmp;
                ej = ej - 1;
            }
            ei = ei + 1;
        }
        for ek in extra_indices {
            out.append(ek);
        }
    }
    for sk in strings {
        out.append(sk);
    }
    for sym in symbols {
        out.append(sym);
    }
    return out;
}

"""Own array-index keys with numeric value >= threshold, sorted descending."""
def:pub _array_collect_index_keys_desc(arr: JSValue, threshold: int) -> list[int] {
    all_ks: list[int] = js_object_all_keys(arr);
    idxs: list[int] = [];
    kids: list[int] = [];
    for kid in all_ks {
        ni: int = _array_index_key_numeric(kid);
        if ni >= threshold {
            idxs.append(ni);
            kids.append(kid);
        }
    }
    m: int = len(idxs);
    if m <= 1 {
        return kids;
    }
    # Descending-by-index deletion order (ES §10.4.2.4 step 17). Sort ascending in
    # O(m log m), then reverse — regardless of array density. The prior insertion
    # sort was O(m^2), which made `arr.length = 0` on a large array quadratic.
    asc: list[int] = _sort_payload_by_int_key(idxs, kids);
    out: list[int] = [];
    r: int = len(asc) - 1;
    while r >= 0 {
        out.append(asc[r]);
        r = r - 1;
    }
    return out;
}

"""True if defining/setting index `idx` is allowed by the length writable flag."""
def:pub _array_index_write_allowed(arr: JSValue, idx: int) -> bool {
    k_len: int = KEY_LENGTH;
    desc: JSProperty = js_object_get_own_property_descriptor(arr, k_len);
    if desc.key == 0 {
        return True;
    }
    cur: int = _array_len_from_value(desc.value);
    if idx < cur {
        return True;
    }
    return desc.writable;
}

"""Grow length to idx+1 when idx >= current length (preserves length flags)."""
def:pub _array_grow_length_if_needed(arr: JSValue, idx: int) -> None {
    k_len: int = KEY_LENGTH;
    desc: JSProperty = js_object_get_own_property_descriptor(arr, k_len);
    if desc.key == 0 {
        return;
    }
    cur: int = _array_len_from_value(desc.value);
    if idx < cur {
        return;
    }
    new_len: int = idx + 1;
    # Do not grow past 2^32-1 here; explicit ArraySetLength (e.g. push step 8) throws RangeError.
    if new_len > 4294967295 {
        return;
    }
    flags: int = 0;
    if desc.writable {
        flags = flags | PROP_WRITABLE;
    }
    if desc.enumerable {
        flags = flags | PROP_ENUMERABLE;
    }
    if desc.configurable {
        flags = flags | PROP_CONFIGURABLE;
    }
    js_object_set_flags(arr, k_len, js_array_len_value(idx + 1), flags);
}

"""ToNumber for ArraySetLength — primitives + observable object coercion."""
def _to_number_for_length(v: JSValue) -> float {
    if jsv_is_undefined(v) {
        return MATH_NAN;
    }
    if jsv_is_null(v) {
        return 0.0;
    }
    if jsv_is_bool(v) {
        if jsv_to_bool(v) {
            return 1.0;
        }
        return 0.0;
    }
    if jsv_is_int32(v) {
        return float(jsv_to_int32(v));
    }
    if jsv_is_double(v) {
        return jsv_to_double(v);
    }
    if jsv_is_symbol(v) {
        vm_throw_native(make_type_error("Cannot convert a Symbol value to a number"));
        return 0.0;
    }
    if jsv_is_bigint_cell(v) {
        vm_throw_native(make_type_error("Cannot convert a BigInt value to a number"));
        return 0.0;
    }
    if jsv_is_string_cell(v) {
        return str_to_float(str_from_id(jsv_to_table_id(v)));
    }
    if jsv_is_object_cell(v) {
        return js_to_number_observable(v);
    }
    return 0.0;
}

"""ToUint32 from an already-computed Number (ECMAScript §7.1.6)."""
def _float_to_uint32(n: float) -> int {
    if not (n == n) {
        return 0;
    }
    if n == MATH_INF or n == MATH_NEG_INF {
        return 0;
    }
    ti: int = int(n);
    u: int = ti & 4294967295;
    if u < 0 {
        u = u + 4294967296;
    }
    return u;
}

"""Apply a length data descriptor (enumerable/configurable always false)."""
def _array_apply_length_desc(arr: JSValue, new_len: int, writable: bool) -> int {
    k_len: int = KEY_LENGTH;
    desc: JSProperty = JSProperty(
        key=k_len,
        value=js_array_len_value(new_len),
        writable=writable,
        enumerable=False,
        configurable=False,
        deleted=False
    );
    return js_object_define_property(arr, k_len, desc);
}

"""
Validate non-value length attributes against the non-configurable length descriptor.
Called only after value coercion (when present) so RangeError precedes TypeError.
"""
def _array_length_attrs_ok(
    has_writable: bool,
    writable: bool,
    has_enumerable: bool,
    enumerable: bool,
    has_configurable: bool,
    configurable: bool,
    old_writable: bool
) -> bool {
    if has_configurable and configurable {
        return False;
    }
    if has_enumerable and enumerable {
        return False;
    }
    if not old_writable and has_writable and writable {
        return False;
    }
    return True;
}

"""
ArraySetLength(A, Desc) — ECMAScript §10.4.2.4.

Returns 0 on success, 1 on rejection. RangeError is raised via vm_throw_native
(callers must check vm_has_native_exc() before treating 1 as a plain reject).

When [[Value]] is present, ToUint32/ToNumber run before any descriptor validation
so invalid lengths throw RangeError even if Desc also has illegal attributes.
"""
def:pub _array_set_length(
    arr: JSValue,
    has_value: bool,
    value: JSValue,
    has_writable: bool,
    writable: bool,
    has_enumerable: bool,
    enumerable: bool,
    has_configurable: bool,
    configurable: bool
) -> int {
    k_len: int = KEY_LENGTH;
    if not has_value {
        old_desc: JSProperty = js_object_get_own_property_descriptor(arr, k_len);
        if old_desc.key == 0 {
            return 1;
        }
        if not _array_length_attrs_ok(
            has_writable,
            writable,
            has_enumerable,
            enumerable,
            has_configurable,
            configurable,
            old_desc.writable
        ) {
            return 1;
        }
        new_w: bool = old_desc.writable;
        if has_writable {
            new_w = writable;
        }
        if not old_desc.writable {
            return 0;
        }
        return _array_apply_length_desc(
            arr, _array_len_from_value(old_desc.value), new_w
        );
    }

    # Steps 3–4: independent ToUint32 / ToNumber coercions (observable side effects).
    num1: float = _to_number_for_length(value);
    if vm_has_native_exc() {
        return 1;
    }
    new_len: int = _float_to_uint32(num1);
    number_len: float = _to_number_for_length(value);
    if vm_has_native_exc() {
        return 1;
    }

    # Step 5: SameValueZero(newLen, numberLen) — before descriptor validation.
    if not (number_len == number_len) {
        vm_throw_native(make_range_error("Invalid array length"));
        return 1;
    }
    if float(new_len) != number_len {
        vm_throw_native(make_range_error("Invalid array length"));
        return 1;
    }

    # Step 7: re-read length descriptor AFTER coercion side effects.
    old_desc2: JSProperty = js_object_get_own_property_descriptor(arr, k_len);
    if old_desc2.key == 0 {
        return 1;
    }
    old_len: int = _array_len_from_value(old_desc2.value);

    # OrdinaryDefineOwnProperty attribute validation (after coercion).
    if not _array_length_attrs_ok(
        has_writable,
        writable,
        has_enumerable,
        enumerable,
        has_configurable,
        configurable,
        old_desc2.writable
    ) {
        return 1;
    }

    # Step 11: newLen >= oldLen → OrdinaryDefineOwnProperty.
    if new_len >= old_len {
        apply_w: bool = old_desc2.writable;
        if has_writable {
            apply_w = writable;
        }
        if not old_desc2.writable {
            if old_len != new_len {
                return 1;
            }
            return 0;
        }
        return _array_apply_length_desc(arr, new_len, apply_w);
    }

    # Step 12: non-writable length rejects shrink.
    if not old_desc2.writable {
        return 1;
    }

    # Steps 13–14: defer writable:false until after successful deletes.
    new_writable: bool = True;
    if has_writable and not writable {
        new_writable = False;
    }

    # Step 15: tentatively set length = newLen with writable true.
    if _array_apply_length_desc(arr, new_len, True) != 0 {
        return 1;
    }

    # Step 17: delete own index keys >= newLen in descending order.
    del_keys: list[int] = _array_collect_index_keys_desc(arr, new_len);
    for dkid in del_keys {
        didx: int = _array_index_key_numeric(dkid);
        if not js_object_delete(arr, dkid) {
            fail_w: bool = True;
            if not new_writable {
                fail_w = False;
            }
            _array_apply_length_desc(arr, didx + 1, fail_w);
            return 1;
        }
    }

    # Step 18: apply deferred writable:false.
    if not new_writable {
        return _array_apply_length_desc(arr, new_len, False);
    }
    return 0;
}

"""
Object.defineProperty / Reflect.defineProperty entry for array "length".
Returns True on success. RangeError is raised via vm_throw_native.
"""
def:pub js_array_define_length_property(arr: JSValue, descriptor: JSValue) -> bool {
    if not jsv_is_object_cell(descriptor) {
        return False;
    }
    gk: int = str_intern("get");
    sk: int = str_intern("set");
    # Accessor Desc with no [[Value]]: OrdinaryDefineOwnProperty rejects (non-configurable data).
    if js_object_has_own(descriptor, gk) or js_object_has_own(descriptor, sk) {
        return False;
    }
    vk: int = str_intern("value");
    wk: int = str_intern("writable");
    ek: int = str_intern("enumerable");
    ck: int = str_intern("configurable");
    has_value: bool = js_object_has_own(descriptor, vk);
    has_writable: bool = js_object_has_own(descriptor, wk);
    has_enumerable: bool = js_object_has_own(descriptor, ek);
    has_configurable: bool = js_object_has_own(descriptor, ck);
    value: JSValue = js_undefined();
    writable: bool = False;
    enumerable: bool = False;
    configurable: bool = False;
    if has_value {
        value = js_object_get(descriptor, vk);
    }
    if has_writable {
        writable = jsv_coerce_to_bool(js_object_get(descriptor, wk));
    }
    if has_enumerable {
        enumerable = jsv_coerce_to_bool(js_object_get(descriptor, ek));
    }
    if has_configurable {
        configurable = jsv_coerce_to_bool(js_object_get(descriptor, ck));
    }
    rc: int = _array_set_length(
        arr,
        has_value,
        value,
        has_writable,
        writable,
        has_enumerable,
        enumerable,
        has_configurable,
        configurable
    );
    if vm_has_native_exc() {
        return False;
    }
    return rc == 0;
}

"""Plain assignment `arr.length = val` — ArraySetLength with only [[Value]]."""
def:pub js_array_set_length_via_set(arr: JSValue, val: JSValue) -> int {
    return _array_set_length(arr, True, val, False, False, False, False, False, False);
}

# ══════════════════════════════════════════════════════════════════════════════
# 3.  Internal utilities
# ══════════════════════════════════════════════════════════════════════════════

"""Extract all elements of an array into a Jac list."""
def _to_list(arr: JSValue) -> list[JSValue] {
    n: int = js_array_len(arr);
    result: list[JSValue] = [];
    i: int = 0;
    while i < n {
        result.append(js_array_get(arr, i));
        i = i + 1;
    }
    return result;
}

"""Extract elements preserving sparse holes as jsv_hole() markers.

Uses own-property checks (not HasProperty) so inherited prototype indices
remain holes — intentional sparse-array semantics for internal callers.
"""
def _to_list_with_holes(arr: JSValue) -> list[JSValue] {
    n: int = js_array_len(arr);
    result: list[JSValue] = [];
    i: int = 0;
    while i < n {
        # Own-only: treat inherited indices as holes (sparse semantics).
        if js_object_has_own(arr, str_intern_index(i)) {
            result.append(js_array_get(arr, i));
        } else {
            result.append(js_undefined());
        }
        i = i + 1;
    }
    return result;
}

"""Overwrite array contents from a Jac list; delete stale indices above new length."""
def _from_list(arr: JSValue, items: list[JSValue]) {
    old_n: int = js_array_len(arr);
    n: int = len(items);
    i: int = 0;
    while i < n {
        if not _set_or_throw(arr, i, items[i]) {
            return;
        }
        i = i + 1;
    }
    if old_n > n {
        di: int = n;
        while di < old_n {
            if not _delete_or_throw(arr, str_intern_index(di)) {
                return;
            }
            di = di + 1;
        }
    }
    rc: int = js_array_set_length_via_set(arr, js_array_len_value(n));
    if vm_has_native_exc() {
        return;
    }
    if rc != 0 {
        vm_throw_native(
            make_type_error("Cannot assign to read only property 'length'")
        );
    }
}

"""Throw TypeError if arr is null or undefined; return True if caller should abort."""
def:pub _require_object(arr: JSValue) -> bool {
    if jsv_is_null(arr) or jsv_is_undefined(arr) {
        vm_throw_native(make_type_error("Array method called on null or undefined"));
        return True;
    }
    return False;
}

"""Return True if v encodes a JS-defined closure (mirrors vm.is_fn_val)."""
def _is_fn_val_local(v: JSValue) -> bool {
    if not jsv_is_cell(v) {
        return False;
    }
    if jsv_cell_kind(v) != JS_CELL_KIND_NATIVE {
        return False;
    }
    return jsv_to_table_id(v) < 1000000;
}

"""Return True if v is a callable (function, native, or callable JSObject)."""
def _is_callable(v: JSValue) -> bool {
    if _is_fn_val_local(v) or is_native_val(v) {
        return True;
    }
    if jsv_is_object_cell(v) and js_object_has_own(v, KEY_CTOR_KIND) {
        return True;
    }
    return False;
}

"""Validate compareFn for sort/toSorted; throw TypeError if non-callable non-undefined."""
def _validate_compare_fn(compare_fn: JSValue) -> bool {
    if jsv_is_undefined(compare_fn) {
        return False;
    }
    if not _is_callable(compare_fn) {
        vm_throw_native(
            make_type_error(
                "The comparison function must be either a function or undefined"
            )
        );
        return True;
    }
    return False;
}

"""Truncate toward zero for ToIntegerOrInfinity; preserve ±Infinity."""
def _truncate_toward_zero(d: float) -> float {
    if not (d == d) {
        return 0.0;
    }
    if d == MATH_INF or d == -1.0 * MATH_INF {
        return d;
    }
    return float(int(d));
}

"""
ECMAScript ToIntegerOrInfinity (§7.1.5).
Returns 0 for null/undefined/NaN; passes ±Infinity through; throws for Symbol.
Objects go through observable ToNumber (valueOf/toString) so abrupt completions propagate.
Finite results are truncated toward zero.
"""
def:pub _to_integer_or_infinity(v: JSValue) -> float {
    if jsv_is_undefined(v) or jsv_is_null(v) {
        return 0.0;
    }
    if jsv_is_bool(v) {
        if jsv_to_bool(v) {
            return 1.0;
        }
        return 0.0;
    }
    if jsv_is_int32(v) {
        return float(jsv_to_int32(v));
    }
    if jsv_is_double(v) {
        return _truncate_toward_zero(jsv_to_double(v));
    }
    if jsv_is_symbol(v) {
        vm_throw_native(make_type_error("Cannot convert a Symbol value to a number"));
        return 0.0;
    }
    if jsv_is_bigint_cell(v) {
        vm_throw_native(make_type_error("Cannot convert a BigInt value to a number"));
        return 0.0;
    }
    if jsv_is_string_cell(v) {
        return _truncate_toward_zero(str_to_float(str_from_id(jsv_to_table_id(v))));
    }
    if jsv_is_object_cell(v) {
        on: float = js_to_number_observable(v);
        if vm_has_native_exc() {
            return 0.0;
        }
        return _truncate_toward_zero(on);
    }
    return 0.0;
}

"""ArrayCreate length limit: throw RangeError if len > 2^32 - 1. Returns True if ok."""
def:pub _array_create_len_ok(len_: int) -> bool {
    if len_ > 4294967295 {
        vm_throw_native(make_range_error("Invalid array length"));
        return False;
    }
    return True;
}

"""
CreateDataPropertyOrThrow(O, ToString(idx), val) — §7.3.7.
Defines an own data property {writable, enumerable, configurable}=true.
Distinct from Set: overwrites configurable non-writable properties and does
not invoke setters. Returns False (and throws TypeError) on failure.
"""
def:pub _create_data_property_or_throw(arr: JSValue, idx: int, val: JSValue) -> bool {
    if js_is_array(arr) and not _array_index_write_allowed(arr, idx) {
        vm_throw_native(make_type_error("Cannot create property"));
        return False;
    }
    key: int = str_intern_index(idx);
    desc: JSProperty = JSProperty(
        key=key,
        value=val,
        writable=True,
        enumerable=True,
        configurable=True,
        deleted=False
    );
    rc: int = js_object_define_property(arr, key, desc);
    if rc != 0 {
        vm_throw_native(make_type_error("Cannot create property"));
        return False;
    }
    if js_is_array(arr) {
        _array_grow_length_if_needed(arr, idx);
    }
    return True;
}

"""Dense Get of indices 0..len-1 via observable [[Get]]. Empty list on abrupt."""
def _to_list_checked(arr: JSValue) -> list[JSValue] {
    n: int = _length_of(arr);
    if vm_has_native_exc() {
        return [];
    }
    result: list[JSValue] = [];
    i: int = 0;
    while i < n {
        result.append(js_array_get(arr, i));
        if vm_has_native_exc() {
            return [];
        }
        i = i + 1;
    }
    return result;
}

"""Lexicographic list sort with undefineds last (default SortCompare)."""
def:pub _list_sort_default(items: list[JSValue]) -> list[JSValue] {
    defined: list[JSValue] = [];
    undefs: list[JSValue] = [];
    for v in items {
        if jsv_is_undefined(v) {
            undefs.append(js_undefined());
        } else {
            defined.append(v);
        }
    }
    dn: int = len(defined);
    si: int = 1;
    while si < dn {
        key_val: JSValue = defined[si];
        sj: int = si - 1;
        while sj >= 0
            and not _default_less(defined[sj], key_val)
            and not js_strict_equal(defined[sj], key_val) {
            defined[sj + 1] = defined[sj];
            sj = sj - 1;
        }
        defined[sj + 1] = key_val;
        si = si + 1;
    }
    return defined + undefs;
}

"""
LengthOfArrayLike(O) — ToLength(Get(O, "length")).
ECMAScript §7.3.19. Propagates abrupt completions from Get and ToNumber.
For TypedArray receivers, uses observable `.length` only (never reads backing buffer).
"""
def:pub _length_of(arr: JSValue) -> int {
    lv: JSValue = js_object_get_observable(arr, WK_LENGTH, arr);
    if vm_has_native_exc() {
        return 0;
    }
    f: float = _to_integer_or_infinity(lv);
    if vm_has_native_exc() {
        return 0;
    }
    if f <= 0.0 {
        return 0;
    }
    # ToLength: clamp to 2^53 - 1 (LengthOfArrayLike must not throw).
    max_len: float = 9007199254740991.0;
    if f > max_len {
        f = max_len;
    }
    return int(f);
}

"""
DeletePropertyOrThrow(O, key) — [[Delete]] then TypeError if rejected.
ECMAScript §7.3.10.
"""
def:pub _delete_or_throw(arr: JSValue, key: int) -> bool {
    ok: bool = js_object_delete_observable(arr, key);
    if vm_has_native_exc() {
        return False;
    }
    if not ok {
        vm_throw_native(make_type_error("Cannot delete property"));
        return False;
    }
    return True;
}

"""
Set(O, idx, val, true) — [[Set]] then TypeError if rejected.
For Array exotic objects, extends length when idx >= length (§10.4.2.1).
"""
def:pub _set_or_throw(arr: JSValue, idx: int, val: JSValue) -> bool {
    # a present dense element: an own writable data property — stored (V4.21)
    if js_object_dense_set_present(arr, idx, val) {
        return True;
    }
    if js_is_array(arr) and not _array_index_write_allowed(arr, idx) {
        vm_throw_native(make_type_error("Cannot assign to property"));
        return False;
    }
    key: int = str_intern_index(idx);
    ok: bool = js_object_set_observable(arr, key, val, arr);
    if vm_has_native_exc() {
        return False;
    }
    if not ok {
        vm_throw_native(make_type_error("Cannot assign to property"));
        return False;
    }
    if js_is_array(arr) {
        _array_grow_length_if_needed(arr, idx);
    }
    return True;
}

"""
Set(O, key, val, true) for an arbitrary (non-index) key — e.g. "length".
ECMAScript §7.3.4 Set with Throw=true.
"""
def:pub _set_named_or_throw(o: JSValue, key: int, val: JSValue) -> bool {
    ok: bool = js_object_set_observable(o, key, val, o);
    if vm_has_native_exc() {
        return False;
    }
    if not ok {
        vm_throw_native(make_type_error("Cannot assign to property"));
        return False;
    }
    return True;
}

"""Clamp a ToIntegerOrInfinity result into [0, len_] for forward indices."""
def:pub _clamp_float(f: float, len_: int) -> int {
    if f >= float(len_) {
        return len_;
    }
    neg_inf: float = -1.0 * MATH_INF;
    if f <= neg_inf or f < -1.0 * float(len_) {
        return 0;
    }
    if f < 0.0 {
        res: int = len_ + int(f);
        if res < 0 {
            return 0;
        }
        return res;
    }
    return int(f);
}

"""Clamp fromIndex for lastIndexOf: +Infinity → len-1, -Infinity → -1."""
def _clamp_float_last(f: float, len_: int) -> int {
    if len_ == 0 {
        return -1;
    }
    neg_inf: float = -1.0 * MATH_INF;
    if f >= float(len_) or f == MATH_INF {
        return len_ - 1;
    }
    if f <= neg_inf {
        return -1;
    }
    if f < 0.0 {
        res: int = len_ + int(f);
        if res < 0 {
            return -1;
        }
        return res;
    }
    return int(f);
}

"""Clamp fromIndex for indexOf/includes: +Infinity → len (search finds nothing)."""
def _clamp_float_from(f: float, len_: int) -> int {
    if f >= float(len_) or f == MATH_INF {
        return len_;
    }
    return _clamp_float(f, len_);
}

"""
Stringify a JSValue for use in join() / toString().
Null and Undefined become ""; everything else uses to_string().
"""
def _elem_str(v: JSValue) -> str {
    if jsv_is_null(v) or jsv_is_undefined(v) {
        return "";
    }
    if jsv_is_bool(v) {
        if jsv_to_bool(v) {
            return "true";
        } else {
            return "false";
        }
    }
    if jsv_is_int32(v) {
        return str(jsv_to_int32(v));
    }
    if jsv_is_double(v) {
        n: float = jsv_to_double(v);
        return number_to_string_radix10(n);
    }
    if jsv_is_string_cell(v) {
        return str_from_id(jsv_to_table_id(v));
    }
    if js_is_array(v) {
        ts_v: JSValue = js_Array_toString(v);
        if jsv_is_string_cell(ts_v) {
            return str_from_id(jsv_to_table_id(ts_v));
        }
        return "";
    }
    if jsv_is_object_cell(v) {
        return "[object Object]";
    }
    return "";
}

"""
Return a JSString JSValue (tag=String) from a raw Jac string.
"""
def _arr_js_str(s: str) -> JSValue {
    return jsv_from_string_id(str_heap(s));  # G1.5: array join result is a transient value
}

"""
Convert a JSValue to a float for numeric comparison.
Non-numeric values → +Infinity so they sort last.
"""
def _to_float(v: JSValue) -> float {
    if jsv_is_int32(v) {
        return float(jsv_to_int32(v));
    }
    if jsv_is_double(v) {
        return jsv_to_double(v);
    }
    return MATH_INF;
}

"""
Default sort comparator (no JS callback).
Always lexicographic on ToString(element) per §23.1.3.29 step 5.c.
Returns True if a should come before b.
"""
def _default_less(a: JSValue, b: JSValue) -> bool {
    return _elem_str(a) < _elem_str(b);
}

"""Clamp a possibly-negative index into [0, len].  Negative = from end."""
def _clamp_idx(idx: int, len_: int) -> int {
    if idx < 0 {
        res: int = len_ + idx;
        if res < 0 {
            return 0;
        }
        return res;
    }
    if idx > len_ {
        return len_;
    }
    return idx;
}

"""
SortIndexedProperties(obj, len, default SortCompare, skip-holes) — §23.1.3.30.1.

Captures `len` once, collects present elements via observable HasProperty/Get,
sorts (undefineds last, lexicographic ToString), writes back via Set(..., true),
then DeletePropertyOrThrow on trailing slots. Preserves accessors and observes
setter/getter side-effects (precise-* tests).
"""
def:pub _array_sort_default(arr: JSValue) -> None {
    n: int = _length_of(arr);
    if vm_has_native_exc() {
        return;
    }
    items: list[JSValue] = [];
    i: int = 0;
    while i < n {
        ik: int = str_intern_index(i);
        if js_object_has_observable(arr, ik) {
            if vm_has_native_exc() {
                return;
            }
            v: JSValue = js_object_get_observable(arr, ik, arr);
            if vm_has_native_exc() {
                return;
            }
            items.append(v);
        } else {
            if vm_has_native_exc() {
                return;
            }
        }
        i = i + 1;
        n = _length_of(arr);
        if vm_has_native_exc() {
            return;
        }
    }
    sorted_items: list[JSValue] = _list_sort_default(items);
    item_count: int = len(sorted_items);
    j: int = 0;
    while j < item_count {
        if not _set_or_throw(arr, j, sorted_items[j]) {
            return;
        }
        j = j + 1;
    }
    while j < n {
        if not _delete_or_throw(arr, str_intern_index(j)) {
            return;
        }
        j = j + 1;
    }
}

"""Spread an element for concat() per §23.1.3.1 / @@isConcatSpreadable."""
def _concat_spread(itm: JSValue) -> list[JSValue] {
    should_spread: bool = js_is_array(itm);
    if jsv_is_object_cell(itm) {
        cs_v: JSValue = js_object_get_observable(
            itm, SYMBOL_KEY_BASE + SYMBOL_ISOONCATSPREADABLE, itm
        );
        if vm_has_native_exc() {
            return [itm];
        }
        if not jsv_is_undefined(cs_v) {
            should_spread = jsv_coerce_to_bool(cs_v);
        }
    }
    if should_spread {
        els: list[JSValue] = [];
        n: int = js_array_len(itm);
        if vm_has_native_exc() {
            return [itm];
        }
        i: int = 0;
        while i < n {
            ik: int = str_intern_index(i);
            if js_object_has_observable(itm, ik) {
                if vm_has_native_exc() {
                    return [itm];
                }
                els.append(js_array_get(itm, i));
                if vm_has_native_exc() {
                    return [itm];
                }
            } else {
                if vm_has_native_exc() {
                    return [itm];
                }
                # Hole: keep slot so result length matches source length.
                els.append(js_undefined());
            }
            i = i + 1;
        }
        return els;
    }
    return [itm];
}

# ══════════════════════════════════════════════════════════════════════════════
# 4.  Constructor
# ══════════════════════════════════════════════════════════════════════════════

"""
Array() / new Array() constructor.

  - No args          → []
  - Single int arg n → sparse array of length n (elements are undefined)
  - Multiple args    → array of those values
ECMAScript §23.1.1.1
"""
def:pub js_Array(args: list[JSValue]) -> JSValue {
    if len(args) == 0 {
        return js_array_create([]);
    }
    if len(args) == 1 {
        singlearg: JSValue = args[0];
        if jsv_is_int32(singlearg) {
            n: int = jsv_to_int32(singlearg);
            if n < 0 {
                vm_throw_native(make_range_error("Invalid array length"));
                return js_undefined();
            }
            if not _array_create_len_ok(n) {
                return js_undefined();
            }
            return js_array_create_with_length(n);
        }
        if jsv_is_double(singlearg) {
            dv: float = jsv_to_double(singlearg);
            iv: int = int(dv) & 4294967295;
            if float(iv) != dv {
                vm_throw_native(make_range_error("Invalid array length"));
                return js_undefined();
            }
            if not _array_create_len_ok(iv) {
                return js_undefined();
            }
            return js_array_create_with_length(iv);
        }
    }
    return js_array_create(args);
}

# ══════════════════════════════════════════════════════════════════════════════
# 5.  Static methods
# ══════════════════════════════════════════════════════════════════════════════

"""
Array.isArray(v) — true iff IsArray(v) (§7.2.2 / §23.1.2.2).
Proxy-aware; throws TypeError for a revoked Proxy.
"""
def:pub js_Array_isArray(v: JSValue) -> JSValue {
    return js_boolean(js_is_array_spec(v));
}

"""
Array.of(...items) — create array from argument list.
ECMAScript §23.1.2.3

Authoritative path is `_vm_array_of` in vm.na.jac (Construct(this),
CreateDataPropertyOrThrow). This native fallback is only reached if the
VM-threaded branch in `_vm_call_native_proxy_aware` is bypassed.
"""
def:pub js_Array_of(args: list[JSValue]) -> JSValue {
    return js_array_create(args);
}

"""
Array.from(arrayLike) — create array from array-like or existing array.
ECMAScript §23.1.2.1

Authoritative path is `_vm_array_from` in vm.na.jac (iterator protocol,
mapFn, Construct(this)). This native fallback is only reached if the
VM-threaded branch in `_vm_call_native_proxy_aware` is bypassed.
"""
def:pub js_Array_from(arraylike: JSValue) -> JSValue {
    # Null/undefined → TypeError
    if jsv_is_null(arraylike) or jsv_is_undefined(arraylike) {
        vm_throw_native(
            make_type_error("Array.from requires an array-like or iterable object")
        );
        return js_undefined();
    }
    # String → iterate characters
    if jsv_is_string_cell(arraylike) {
        s: str = str_from_id(jsv_to_table_id(arraylike));
        chars: list[JSValue] = [];
        ci: int = 0;
        while ci < len(s) {
            chars.append(jsv_from_string_id(str_intern(s[ci])));
            ci = ci + 1;
        }
        return js_array_create(chars);
    }
    if js_is_array(arraylike) {
        items: list[JSValue] = _to_list(arraylike);
        return js_array_create(items);
    }
    if jsv_is_object_cell(arraylike) {
        lv: JSValue = js_object_get_observable(arraylike, KEY_LENGTH, arraylike);
        if vm_has_native_exc() {
            return js_undefined();
        }
        n: int = 0;
        if jsv_is_int32(lv) {
            n = jsv_to_int32(lv);
        }
        if jsv_is_double(lv) {
            n = int(jsv_to_double(lv));
        }
        items2: list[JSValue] = [];
        i: int = 0;
        while i < n {
            items2.append(
                js_object_get_observable(arraylike, str_intern_index(i), arraylike)
            );
            if vm_has_native_exc() {
                return js_undefined();
            }
            i = i + 1;
        }
        return js_array_create(items2);
    }
    return js_array_create([]);
}

# ══════════════════════════════════════════════════════════════════════════════
# 6.  Mutating prototype methods
# ══════════════════════════════════════════════════════════════════════════════

"""
Array.prototype.push(...items) — append one or more elements, return new length.
ECMAScript §23.1.3.23

VM path uses `_vm_array_push` (throwing Set + 2^53-1 guard). This native
implementation remains as a unit-test / dispatch fallback only.
"""
def:pub js_Array_push(arr: JSValue, items: list[JSValue]) -> JSValue {
    if _require_object(arr) {
        return js_undefined();
    }
    # Dense fast arm: appends at length == dense end are pure list appends +
    # one length-slot write (same conditions as the VM SET_INDEX append arm;
    # safe under obs scopes — no accessor/proxy can be involved).
    if jsv_is_object_cell(arr) and idx_protector_ok() {
        jp_id: int = jsv_to_table_id(arr);
        if jp_id > 0 {
            jp_raw: JSObject = js_object_table_get(jp_id);
            if jp_raw.elems_kind != ELEMS_NONE
                and jp_raw.is_ext()
                and jp_raw.mode == MAP_MODE_SHAPE {
                jp_pk: int = shape_lookup(jp_raw.shape_id, WK_LENGTH);
                if jp_pk >= 0
                    and (jp_pk & SHAPE_ATTR_ACCESSOR) == 0
                    and (jp_pk & 1) != 0 {
                    jp_lv: JSValue = jp_raw.slots[jp_pk // 16];
                    if jsv_is_int32(jp_lv)
                        and jsv_to_int32(jp_lv) == len(jp_raw.elems_ro()) {
                        for jp_itm in items {
                            jp_raw.elems_rw().append(jp_itm);
                        }
                        jp_raw.slots[jp_pk // 16] = js_array_len_value(
                            len(jp_raw.elems_ro())
                        );
                        return js_array_len_value(len(jp_raw.elems_ro()));
                    }
                }
            }
        }
    }
    n: int = js_array_len(arr);
    for itm in items {
        if not _set_or_throw(arr, n, itm) {
            return js_undefined();
        }
        n = n + 1;
    }
    # Set(length) — TypeError when length is non-writable / frozen.
    rc: int = js_array_set_length_via_set(arr, js_array_len_value(n));
    if vm_has_native_exc() {
        return js_undefined();
    }
    if rc != 0 {
        vm_throw_native(
            make_type_error("Cannot assign to read only property 'length'")
        );
        return js_undefined();
    }
    return js_array_len_value(n);
}

"""
Array.prototype.pop() — remove and return last element.
ECMAScript §23.1.3.22

VM path uses `_vm_array_pop` (throwing Delete/Set). This native
implementation remains as a unit-test / dispatch fallback only.
"""
def:pub js_Array_pop(arr: JSValue) -> JSValue {
    if _require_object(arr) {
        return js_undefined();
    }
    n: int = js_array_len(arr);
    if n == 0 {
        return js_undefined();
    }
    last_idx: int = n - 1;
    last: JSValue = js_array_get(arr, last_idx);
    js_object_delete(arr, str_intern_index(last_idx));
    rc: int = js_array_set_length_via_set(arr, js_array_len_value(last_idx));
    if vm_has_native_exc() {
        return js_undefined();
    }
    if rc != 0 {
        vm_throw_native(
            make_type_error("Cannot assign to read only property 'length'")
        );
        return js_undefined();
    }
    return last;
}

"""
Array.prototype.shift() — remove and return first element; shift rest left.
ECMAScript §23.1.3.25

VM path uses `_vm_array_shift` (observable Has/Get/Set/Delete). This native
implementation remains as a unit-test / dispatch fallback only.
"""
def:pub js_Array_shift(arr: JSValue) -> JSValue {
    if _require_object(arr) {
        return js_undefined();
    }
    n: int = js_array_len(arr);
    if n == 0 {
        return js_undefined();
    }
    first: JSValue = js_array_get(arr, 0);
    i: int = 1;
    while i < n {
        if not _set_or_throw(arr, i - 1, js_array_get(arr, i)) {
            return js_undefined();
        }
        i = i + 1;
    }
    js_object_delete(arr, str_intern(str(n - 1)));
    rc: int = js_array_set_length_via_set(arr, js_array_len_value(n - 1));
    if vm_has_native_exc() {
        return js_undefined();
    }
    if rc != 0 {
        vm_throw_native(
            make_type_error("Cannot assign to read only property 'length'")
        );
        return js_undefined();
    }
    return first;
}

"""
Array.prototype.unshift(...items) — insert items at front, shift rest right.
Returns new length.  ECMAScript §23.1.3.32

VM path uses `_vm_array_unshift` (throwing Set/Delete + 2^53-1 guard). This
native implementation remains as a unit-test / dispatch fallback only.
"""
def:pub js_Array_unshift(arr: JSValue, items: list[JSValue]) -> JSValue {
    if _require_object(arr) {
        return js_undefined();
    }
    existing: list[JSValue] = _to_list(arr);
    combined: list[JSValue] = items + existing;
    _from_list(arr, combined);
    return js_int(len(combined));
}

"""
Array.prototype.splice(start, deleteCount, ...items) — mutate in place.

Returns an array of removed elements.
ECMAScript §23.1.3.30

VM path uses `_vm_array_splice` (species + observable Set/Delete). This native
implementation remains as a unit-test / dispatch fallback only.
"""
def:pub js_Array_splice(
    arr: JSValue,
    start_v: JSValue,
    delete_count_v: JSValue,
    new_items: list[JSValue],
    dc_provided: bool
) -> JSValue {
    if _require_object(arr) {
        return js_undefined();
    }
    n: int = js_array_len(arr);
    start_f: float = _to_integer_or_infinity(start_v);
    if vm_has_native_exc() {
        return js_undefined();
    }
    st: int = _clamp_float(start_f, n);
    dc: int = 0;
    if not dc_provided {
        dc = n - st;
    } else {
        dc_f: float = _to_integer_or_infinity(delete_count_v);
        if vm_has_native_exc() {
            return js_undefined();
        }
        dc = int(dc_f);
        if dc < 0 {
            dc = 0;
        }
        if dc > n - st {
            dc = n - st;
        }
    }
    removed: list[JSValue] = [];
    kept_before: list[JSValue] = [];
    kept_after: list[JSValue] = [];
    i: int = 0;
    while i < n {
        ik: int = str_intern_index(i);
        if not js_object_has_observable(arr, ik) {
            if vm_has_native_exc() {
                return js_undefined();
            }
            if i < st {
                kept_before.append(js_undefined());
            } elif i < st + dc {
                removed.append(js_undefined());
            } else {
                kept_after.append(js_undefined());
            }
        } else {
            if vm_has_native_exc() {
                return js_undefined();
            }
            v: JSValue = js_array_get(arr, i);
            if vm_has_native_exc() {
                return js_undefined();
            }
            if i < st {
                kept_before.append(v);
            } elif i < st + dc {
                removed.append(v);
            } else {
                kept_after.append(v);
            }
        }
        i = i + 1;
    }
    merged: list[JSValue] = kept_before + new_items + kept_after;
    _from_list(arr, merged);
    return js_array_create(removed);
}

"""
Array.prototype.reverse() — reverse in place, return array.
ECMAScript §23.1.3.24

VM path uses `_vm_array_reverse` (HasProperty four-case swap). This native
implementation remains as a unit-test / dispatch fallback only.
"""
def:pub js_Array_reverse(arr: JSValue) -> JSValue {
    if _require_object(arr) {
        return js_undefined();
    }
    els: list[JSValue] = _to_list(arr);
    n: int = len(els);
    rev: list[JSValue] = [];
    i: int = n - 1;
    while i >= 0 {
        rev.append(els[i]);
        i = i - 1;
    }
    _from_list(arr, rev);
    return arr;
}

"""
Array.prototype.sort(compareFn?) — sort in place using default numeric/string
comparator.  compareFn (JS callback) is accepted but IGNORED —  will
wire it to the VM dispatcher.  ECMAScript §23.1.3.29
"""
def:pub js_Array_sort(arr: JSValue, compare_fn: JSValue) -> JSValue {
    if _require_object(arr) {
        return js_undefined();
    }
    if _validate_compare_fn(compare_fn) {
        return js_undefined();
    }
    vm_throw_native(make_type_error("Array.prototype.sort requires VM threading"));
    return js_undefined();
}

"""
Array.prototype.fill(value, start?, end?) — fill [start, end) with value.
ECMAScript §23.1.3.7
"""
def:pub js_Array_fill(
    arr: JSValue, fill_val: JSValue, start_v: JSValue, end_v: JSValue
) -> JSValue {
    if _require_object(arr) {
        return js_undefined();
    }
    n: int = _length_of(arr);
    if vm_has_native_exc() {
        return js_undefined();
    }
    st: int = _clamp_float(_to_integer_or_infinity(start_v), n);
    if vm_has_native_exc() {
        return js_undefined();
    }
    en: int = n;
    if not jsv_is_undefined(end_v) {
        en = _clamp_float(_to_integer_or_infinity(end_v), n);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    i: int = st;
    while i < en {
        if not _set_or_throw(arr, i, fill_val) {
            return js_undefined();
        }
        i = i + 1;
    }
    return arr;
}

"""
Array.prototype.copyWithin(target, start, end?) — copy a slice within the
array without changing length.  ECMAScript §23.1.3.4
"""
def:pub js_Array_copyWithin(
    arr: JSValue, target_v: JSValue, start_v: JSValue, end_v: JSValue
) -> JSValue {
    if _require_object(arr) {
        return js_undefined();
    }
    len_: int = _length_of(arr);
    if vm_has_native_exc() {
        return js_undefined();
    }
    to: int = _clamp_float(_to_integer_or_infinity(target_v), len_);
    if vm_has_native_exc() {
        return js_undefined();
    }
    from_i: int = _clamp_float(_to_integer_or_infinity(start_v), len_);
    if vm_has_native_exc() {
        return js_undefined();
    }
    final: int = len_;
    if not jsv_is_undefined(end_v) {
        final = _clamp_float(_to_integer_or_infinity(end_v), len_);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    count: int = final - from_i;
    if count > len_ - to {
        count = len_ - to;
    }
    if count <= 0 {
        return arr;
    }
    direction: int = 1;
    if from_i < to and to < from_i + count {
        direction = -1;
        from_i = from_i + count - 1;
        to = to + count - 1;
    }
    while count > 0 {
        from_key: int = str_intern_index(from_i);
        to_key: int = str_intern_index(to);
        from_present: bool = js_object_has_observable(arr, from_key);
        if vm_has_native_exc() {
            return js_undefined();
        }
        if from_present {
            from_val: JSValue = js_object_get_observable(arr, from_key, arr);
            if vm_has_native_exc() {
                return js_undefined();
            }
            if not _set_or_throw(arr, to, from_val) {
                return js_undefined();
            }
        } else {
            if not _delete_or_throw(arr, to_key) {
                return js_undefined();
            }
        }
        from_i = from_i + direction;
        to = to + direction;
        count = count - 1;
    }
    return arr;
}

# ══════════════════════════════════════════════════════════════════════════════
# 7.  Non-mutating prototype methods
# ══════════════════════════════════════════════════════════════════════════════

"""
Array.prototype.concat(...items) — return new array with appended items.

Each item is either spread (if it is an array) or appended as-is.
ECMAScript §23.1.3.1
"""
def:pub js_Array_concat(arr: JSValue, items: list[JSValue]) -> JSValue {
    if _require_object(arr) {
        return js_undefined();
    }
    result_els: list[JSValue] = _concat_spread(arr);
    for itm in items {
        result_els = result_els + _concat_spread(itm);
    }
    return js_array_create(result_els);
}

"""
Array.prototype.slice(start?, end?) — return shallow copy of [start, end).
ECMAScript §23.1.3.27
"""
def:pub js_Array_slice(arr: JSValue, start_v: JSValue, end_v: JSValue) -> JSValue {
    if _require_object(arr) {
        return js_undefined();
    }
    n: int = js_array_len(arr);
    st: int = _clamp_float(_to_integer_or_infinity(start_v), n);
    if vm_has_native_exc() {
        return js_undefined();
    }
    en: int = _clamp_float(_to_integer_or_infinity(end_v), n);
    if vm_has_native_exc() {
        return js_undefined();
    }
    out_len: int = en - st;
    result: JSValue = js_array_create_with_length(out_len);
    i: int = st;
    while i < en {
        src_key: int = str_intern_index(i);
        if js_object_has_observable(arr, src_key) {
            if vm_has_native_exc() {
                return js_undefined();
            }
            js_object_set(
                result,
                str_intern(str(i - st)),
                js_object_get_observable(arr, src_key, arr)
            );
            if vm_has_native_exc() {
                return js_undefined();
            }
        } else {
            if vm_has_native_exc() {
                return js_undefined();
            }
        }
        i = i + 1;
    }
    return result;
}

"""
Array.prototype.join(separator?) — join elements into a string.
Default separator is ",".  ECMAScript §23.1.3.15
"""
def:pub js_Array_join(arr: JSValue, sep_v: JSValue) -> JSValue {
    if _require_object(arr) {
        return js_undefined();
    }
    sep: str = ",";
    if jsv_is_string_cell(sep_v) {
        sep = str_from_id(jsv_to_table_id(sep_v));
    }
    n: int = js_array_len(arr);
    # Build via list[str] + join — host `s = s + x` bypasses JS ropes and is
    # O(n^2) for large arrays; join is a single allocate/copy.
    parts: list[str] = [];
    i: int = 0;
    while i < n {
        if i > 0 {
            parts.append(sep);
        }
        parts.append(_elem_str(js_array_get(arr, i)));
        i = i + 1;
    }
    return _arr_js_str("".join(parts));
}

"""Strict equality that is correct for computed strings.

js_strict_equal compares cells bitwise, which is only right for *interned*
strings: two heap strings (built at runtime by concatenation, slicing, etc.)
with identical text carry different ids, so it reports them unequal. The VM's
STRICT_EQ has its own content-comparing wrapper for this reason; the array
search methods need the same, otherwise `["x"+"=y"].indexOf("x=y")` is -1 even
though `arr[0] === "x=y"` is true. Equal ids short-circuit, so the text
comparison only runs for the differing-id case."""
def _array_strict_eq(a: JSValue, b: JSValue) -> bool {
    if jsv_is_string_cell(a) and jsv_is_string_cell(b) {
        aid: int = jsv_to_table_id(a);
        bid: int = jsv_to_table_id(b);
        if aid == bid {
            return True;
        }
        return str_from_id(aid) == str_from_id(bid);
    }
    return js_strict_equal(a, b);
}

"""
Array.prototype.indexOf(searchElement, fromIndex?) — first index of strict-equal
element, or -1.  ECMAScript §23.1.3.14

Length is checked before ToIntegerOrInfinity so empty arrays never evaluate
fromIndex. Found indices use js_array_len_value so values >= 2^31 are not
truncated through int32.
"""
def:pub js_Array_indexOf(arr: JSValue, search: JSValue, from_v: JSValue) -> JSValue {
    if _require_object(arr) {
        return js_int(-1);
    }
    n: int = js_array_len(arr);
    if vm_has_native_exc() {
        return js_int(-1);
    }
    if n == 0 {
        return js_int(-1);
    }
    from_f: float = _to_integer_or_infinity(from_v);
    if vm_has_native_exc() {
        return js_int(-1);
    }
    start: int = _clamp_float_from(from_f, n);
    if start >= n {
        return js_int(-1);
    }
    i: int = start;
    while i < n {
        # a present dense element: HasProperty true, Get = the element
        io_d: JSValue = js_object_dense_elem(arr, i);
        if not jsv_is_hole(io_d) {
            if _array_strict_eq(io_d, search) {
                return js_array_len_value(i);
            }
        } elif js_object_has_observable(arr, str_intern_index(i)) {
            if vm_has_native_exc() {
                return js_int(-1);
            }
            if _array_strict_eq(js_array_get(arr, i), search) {
                return js_array_len_value(i);
            }
            if vm_has_native_exc() {
                return js_int(-1);
            }
        } else {
            if vm_has_native_exc() {
                return js_int(-1);
            }
        }
        i = i + 1;
    }
    return js_int(-1);
}

"""
Array.prototype.lastIndexOf(searchElement, fromIndex?) — last index or -1.
ECMAScript §23.1.3.20.

from_provided distinguishes an absent fromIndex (default len-1) from an
explicit undefined (ToIntegerOrInfinity → 0). Length is checked before
ToIntegerOrInfinity so empty arrays never evaluate fromIndex. Found indices
use js_array_len_value so values >= 2^31 are not truncated through int32.
"""
def:pub js_Array_lastIndexOf(
    arr: JSValue, search: JSValue, from_v: JSValue, from_provided: bool
) -> JSValue {
    if _require_object(arr) {
        return js_int(-1);
    }
    n: int = js_array_len(arr);
    if vm_has_native_exc() {
        return js_int(-1);
    }
    if n == 0 {
        return js_int(-1);
    }
    from_f: float = float(n - 1);
    if from_provided {
        from_f = _to_integer_or_infinity(from_v);
        if vm_has_native_exc() {
            return js_int(-1);
        }
    }
    start: int = _clamp_float_last(from_f, n);
    if start < 0 {
        return js_int(-1);
    }
    i: int = start;
    while i >= 0 {
        lio_d: JSValue = js_object_dense_elem(arr, i);
        if not jsv_is_hole(lio_d) {
            if _array_strict_eq(lio_d, search) {
                return js_array_len_value(i);
            }
        } elif js_object_has_observable(arr, str_intern_index(i)) {
            if vm_has_native_exc() {
                return js_int(-1);
            }
            if _array_strict_eq(js_array_get(arr, i), search) {
                return js_array_len_value(i);
            }
            if vm_has_native_exc() {
                return js_int(-1);
            }
        } else {
            if vm_has_native_exc() {
                return js_int(-1);
            }
        }
        i = i - 1;
    }
    return js_int(-1);
}

"""
Array.prototype.includes(searchElement, fromIndex?) — SameValueZero membership.
ECMAScript §23.1.3.13

Unlike indexOf, includes always performs Get (no HasProperty gate), so sparse
holes read as undefined and match searchElement === undefined. Length is
checked before ToIntegerOrInfinity so empty arrays never evaluate fromIndex.
"""
def:pub js_Array_includes(arr: JSValue, search: JSValue, from_v: JSValue) -> JSValue {
    if _require_object(arr) {
        return js_false();
    }
    n: int = js_array_len(arr);
    if vm_has_native_exc() {
        return js_false();
    }
    if n == 0 {
        return js_false();
    }
    from_f: float = _to_integer_or_infinity(from_v);
    if vm_has_native_exc() {
        return js_false();
    }
    start: int = _clamp_float_from(from_f, n);
    if start >= n {
        return js_false();
    }
    # SameValueZero: like strict equal but NaN === NaN. Always Get (no HasProperty).
    i: int = start;
    while i < n {
        elem: JSValue = js_array_get(arr, i);
        if vm_has_native_exc() {
            return js_false();
        }
        if _array_strict_eq(elem, search) {
            return js_true();
        }
        # NaN check for SameValueZero
        if jsv_is_double(elem) and jsv_is_double(search) {
            e_nan: bool = not (jsv_to_double(elem) == jsv_to_double(elem));
            s_nan: bool = not (jsv_to_double(search) == jsv_to_double(search));
            if e_nan and s_nan {
                return js_true();
            }
        }
        i = i + 1;
    }
    return js_false();
}

"""
Array.prototype.at(index) — element at relative index (negative counts from end).
ECMAScript §23.1.3.1 (ES2022)
"""
def:pub js_Array_at(arr: JSValue, index_v: JSValue) -> JSValue {
    if _require_object(arr) {
        return js_undefined();
    }
    n: int = js_array_len(arr);
    idx: int = _clamp_float(_to_integer_or_infinity(index_v), n);
    if vm_has_native_exc() {
        return js_undefined();
    }
    if idx < 0 or idx >= n {
        return js_undefined();
    }
    return js_array_get(arr, idx);
}

"""
Array.prototype.flat(depth?) — flatten nested arrays up to depth levels.
depth defaults to 1.  ECMAScript §23.1.3.9

VM path uses `_vm_array_flat` (species + FlattenIntoArray). This native
implementation remains as a unit-test / dispatch fallback only.
"""
def:pub js_Array_flat(arr: JSValue, depth_v: JSValue) -> JSValue {
    if _require_object(arr) {
        return js_undefined();
    }
    depth: int = 1;
    if jsv_is_int32(depth_v) {
        depth = jsv_to_int32(depth_v);
    }
    if jsv_is_double(depth_v) {
        dv: float = jsv_to_double(depth_v);
        if dv == MATH_INF {
            depth = 1073741824;
        } else {
            depth = int(dv);
        }
    }
    return _flat_into(arr, depth);
}

"""Recursive helper for flat()."""
def _flat_into(arr: JSValue, depth: int) -> JSValue {
    result_els: list[JSValue] = [];
    n: int = js_array_len(arr);
    i: int = 0;
    while i < n {
        elem: JSValue = js_array_get(arr, i);
        if depth > 0 and js_is_array(elem) {
            nested: JSValue = _flat_into(elem, depth - 1);
            nn: int = js_array_len(nested);
            j: int = 0;
            while j < nn {
                result_els.append(js_array_get(nested, j));
                j = j + 1;
            }
        } else {
            result_els.append(elem);
        }
        i = i + 1;
    }
    return js_array_create(result_els);
}

"""
Array.prototype.toString() — equivalent to join(",").
ECMAScript §23.1.3.31
"""
def:pub js_Array_toString(arr: JSValue) -> JSValue {
    if _require_object(arr) {
        return js_undefined();
    }
    return js_Array_join(arr, _arr_js_str(","));
}

"""
Array.prototype.toLocaleString(locales?, options?) — locale-aware string
representation.  Behaves identically to toString() in environments without
an Intl implementation.  ECMAScript §23.1.3.31
"""
def:pub js_Array_toLocaleString(arr: JSValue) -> JSValue {
    if _require_object(arr) {
        return js_undefined();
    }
    # No Intl yet; fall back to comma-joined toString for each element.
    return js_Array_join(arr, _arr_js_str(","));
}

# ══════════════════════════════════════════════════════════════════════════════
# 7b.  ES2023 change-by-copy methods (non-mutating counterparts)
#
#  toReversed, toSorted, toSpliced, with — each returns a NEW array without
#  modifying the original.  Bun and JSC both ship these; they are part of the
#  "Change Array by Copy" TC39 proposal promoted to ES2024 §23.1.3.
# ══════════════════════════════════════════════════════════════════════════════

"""
Array.prototype.toReversed() — return a new reversed array, leaving original
unchanged.  Gets indices in descending order.  ECMAScript §23.1.3.34 (ES2023)
"""
def:pub js_Array_toReversed(arr: JSValue) -> JSValue {
    if _require_object(arr) {
        return js_undefined();
    }
    n: int = _length_of(arr);
    if vm_has_native_exc() {
        return js_undefined();
    }
    if not _array_create_len_ok(n) {
        return js_undefined();
    }
    rev: list[JSValue] = [];
    k: int = 0;
    while k < n {
        # Spec: Get(O, ToString(len - k - 1)) — descending order is observable.
        v: JSValue = js_array_get(arr, n - k - 1);
        if vm_has_native_exc() {
            return js_undefined();
        }
        rev.append(v);
        k = k + 1;
    }
    return js_array_create(rev);
}

"""
Array.prototype.toSorted(compareFn?) — return a new sorted array, leaving
original unchanged.  Validates comparefn before LengthOfArrayLike.
JS comparefn is handled by the VM inline path; this is the default-sort path.
ECMAScript §23.1.3.35 (ES2023)
"""
def:pub js_Array_toSorted(arr: JSValue, compare_fn: JSValue) -> JSValue {
    if _require_object(arr) {
        return js_undefined();
    }
    # Step 1: IsCallable(comparefn) before reading length.
    if _validate_compare_fn(compare_fn) {
        return js_undefined();
    }
    # Step 2–3: LengthOfArrayLike then ArrayCreate limit (before any Get).
    n: int = _length_of(arr);
    if vm_has_native_exc() {
        return js_undefined();
    }
    if not _array_create_len_ok(n) {
        return js_undefined();
    }
    els: list[JSValue] = [];
    i: int = 0;
    while i < n {
        els.append(js_array_get(arr, i));
        if vm_has_native_exc() {
            return js_undefined();
        }
        i = i + 1;
    }
    sorted_els: list[JSValue] = _list_sort_default(els);
    return js_array_create(sorted_els);
}

"""
Array.prototype.toSpliced(start, deleteCount, ...items) — return a new array
with the splice applied, leaving original unchanged.
start_provided / dc_provided distinguish missing args from explicit undefined.
ECMAScript §23.1.3.36 (ES2023)
"""
def:pub js_Array_toSpliced(
    arr: JSValue,
    start_v: JSValue,
    delete_count_v: JSValue,
    new_items: list[JSValue],
    start_provided: bool,
    dc_provided: bool
) -> JSValue {
    if _require_object(arr) {
        return js_undefined();
    }
    len_: int = _length_of(arr);
    if vm_has_native_exc() {
        return js_undefined();
    }
    actual_start: int = 0;
    actual_dc: int = 0;
    if start_provided {
        rs: float = _to_integer_or_infinity(start_v);
        if vm_has_native_exc() {
            return js_undefined();
        }
        actual_start = _clamp_float(rs, len_);
        if not dc_provided {
            actual_dc = len_ - actual_start;
        } else {
            dc_f: float = _to_integer_or_infinity(delete_count_v);
            if vm_has_native_exc() {
                return js_undefined();
            }
            dc: int = int(dc_f);
            if dc < 0 {
                dc = 0;
            }
            if dc > len_ - actual_start {
                dc = len_ - actual_start;
            }
            actual_dc = dc;
        }
    }
    insert_count: int = len(new_items);
    new_len: int = len_ + insert_count - actual_dc;
    # Spec: newLen > 2^53 - 1 → TypeError; ArrayCreate: newLen > 2^32 - 1 → RangeError.
    if new_len > 9007199254740991 {
        vm_throw_native(make_type_error("Invalid array length"));
        return js_undefined();
    }
    if not _array_create_len_ok(new_len) {
        return js_undefined();
    }
    out: list[JSValue] = [];
    i: int = 0;
    while i < actual_start {
        out.append(js_array_get(arr, i));
        if vm_has_native_exc() {
            return js_undefined();
        }
        i = i + 1;
    }
    for itm in new_items {
        out.append(itm);
    }
    r: int = actual_start + actual_dc;
    while r < len_ {
        out.append(js_array_get(arr, r));
        if vm_has_native_exc() {
            return js_undefined();
        }
        r = r + 1;
    }
    return js_array_create(out);
}

"""
Array.prototype.with(index, value) — return a new array with the element at
index replaced by value, leaving original unchanged.
Does not [[Get]] the replaced index.  ECMAScript §23.1.3.39 (ES2023)
"""
def:pub js_Array_with(arr: JSValue, index_v: JSValue, val: JSValue) -> JSValue {
    if _require_object(arr) {
        return js_undefined();
    }
    n: int = _length_of(arr);
    if vm_has_native_exc() {
        return js_undefined();
    }
    if not _array_create_len_ok(n) {
        return js_undefined();
    }
    rel: float = _to_integer_or_infinity(index_v);
    if vm_has_native_exc() {
        return js_undefined();
    }
    actual_f: float = rel;
    if rel < 0.0 {
        actual_f = float(n) + rel;
    }
    if actual_f < 0.0 or actual_f >= float(n) {
        vm_throw_native(make_range_error("Invalid index"));
        return js_undefined();
    }
    ai: int = int(actual_f);
    out: list[JSValue] = [];
    k: int = 0;
    while k < n {
        if k == ai {
            out.append(val);
        } else {
            out.append(js_array_get(arr, k));
            if vm_has_native_exc() {
                return js_undefined();
            }
        }
        k = k + 1;
    }
    return js_array_create(out);
}

# ══════════════════════════════════════════════════════════════════════════════
# 8.  Callback-taking prototype methods (fallbacks — VM handles dispatch)
# ══════════════════════════════════════════════════════════════════════════════

"""Array.prototype.forEach(callback) — fallback. ECMAScript §23.1.3.12"""
def:pub js_Array_forEach(arr: JSValue, callback: JSValue) -> JSValue {
    return js_undefined();
}

"""Array.prototype.map(callback) — fallback. ECMAScript §23.1.3.17"""
def:pub js_Array_map(arr: JSValue, callback: JSValue) -> JSValue {
    return js_array_create([]);
}

"""Array.prototype.filter(callback) — fallback. ECMAScript §23.1.3.8"""
def:pub js_Array_filter(arr: JSValue, callback: JSValue) -> JSValue {
    return js_array_create([]);
}

"""Array.prototype.reduce(callback, initialValue?) — fallback. ECMAScript §23.1.3.23"""
def:pub js_Array_reduce(arr: JSValue, callback: JSValue, init_val: JSValue) -> JSValue {
    if not jsv_is_undefined(init_val) {
        return init_val;
    }
    if js_array_len(arr) == 0 {
        return js_undefined();
    }
    return js_array_get(arr, 0);
}

"""Array.prototype.reduceRight(callback, initialValue?) — fallback. ECMAScript §23.1.3.24"""
def:pub js_Array_reduceRight(
    arr: JSValue, callback: JSValue, init_val: JSValue
) -> JSValue {
    if not jsv_is_undefined(init_val) {
        return init_val;
    }
    n: int = js_array_len(arr);
    if n == 0 {
        return js_undefined();
    }
    return js_array_get(arr, n - 1);
}

"""Array.prototype.find(predicate) — fallback. ECMAScript §23.1.3.9"""
def:pub js_Array_find(arr: JSValue, predicate: JSValue) -> JSValue {
    return js_undefined();
}

"""Array.prototype.findIndex(predicate) — fallback. ECMAScript §23.1.3.10"""
def:pub js_Array_findIndex(arr: JSValue, predicate: JSValue) -> JSValue {
    return js_int(-1);
}

"""Array.prototype.findLast(predicate) — fallback. ECMAScript §23.1.3.11"""
def:pub js_Array_findLast(arr: JSValue, predicate: JSValue) -> JSValue {
    return js_undefined();
}

"""Array.prototype.findLastIndex(predicate) — fallback. ECMAScript §23.1.3.12"""
def:pub js_Array_findLastIndex(arr: JSValue, predicate: JSValue) -> JSValue {
    return js_int(-1);
}

"""Array.prototype.some(predicate) — fallback. ECMAScript §23.1.3.28"""
def:pub js_Array_some(arr: JSValue, predicate: JSValue) -> JSValue {
    return js_false();
}

"""Array.prototype.every(predicate) — fallback. ECMAScript §23.1.3.5"""
def:pub js_Array_every(arr: JSValue, predicate: JSValue) -> JSValue {
    if js_array_len(arr) == 0 {
        return js_true();
    }
    return js_false();
}

"""Array.prototype.flatMap(callback) — fallback. ECMAScript §23.1.3.10"""
def:pub js_Array_flatMap(arr: JSValue, callback: JSValue) -> JSValue {
    return js_array_create([]);
}

"""Array.prototype.group(callback) — fallback. ES2024 §23.1.3.21"""
def:pub js_Array_group(arr: JSValue, callback: JSValue) -> JSValue {
    return js_object_create_null();
}

"""Array.fromAsync(asyncIterable) — fallback. ES2024 §23.1.2.1"""
def:pub js_Array_fromAsync(asyncIterable: JSValue) -> JSValue {
    # Authoritative path: `_vm_array_from_async` in vm.na.jac.
    if jsv_is_null(asyncIterable) or jsv_is_undefined(asyncIterable) {
        vm_throw_native(
            make_type_error("Array.fromAsync requires an array-like or iterable object")
        );
        return js_undefined();
    }
    vm_throw_native(make_type_error("Array.fromAsync requires VM threading"));
    return js_undefined();
}

# R15: Array.prototype.keys / values / entries are VM-threaded
# (_vm_array_create_iterator → CreateArrayIterator). Legacy snapshot-array
# helpers removed.
