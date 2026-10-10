"""Built-in: Set constructor, prototype methods, and WeakSet.

Storage design
──────────────
JSSetStorage:
  - nodes / key_index / live_count — ordered hash table for Set (live iterators)
  - items — parallel list retained for WeakSet

ECMAScript spec : §24.2 — Set Objects
"""

import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    js_true,
    js_false,
    js_int,
    jsv_hole,
    jsv_is_hole,
    jsv_is_object_cell,
    jsv_is_null,
    jsv_is_undefined,
    jsv_is_int32,
    jsv_to_int32,
    jsv_to_table_id,
    jsv_from_string_id,
    jsv_is_double,
    jsv_to_double,
    jsv_is_string_cell
}
import from engine.src.builtins.set_type { JSSetStorage, SET_NO_VALS, SET_NO_INDEX }
import from engine.src.runtime.realm { Realm, gc_note_alloc }
import from engine.src.runtime.jsobject {
    js_object_create_null,
    js_object_create,
    js_object_set,
    js_object_get,
    js_object_has_own,
    js_object_define_property,
    js_object_get_ordinary_proto,
    js_object_brand
}
import from engine.src.runtime.jsobj_type { JSProperty, BRAND_SET, BRAND_WEAKSET }
import from engine.src.runtime.jsstring {
    str_intern,
    str_from_id,
    str_substr,
    HEAP_STRING_BASE
}
import from engine.src.runtime.encoding { SYMBOL_KEY_BASE }
import from engine.src.runtime.jssymbol { SYMBOL_ITERATOR, SYMBOL_TO_STRING_TAG }
import from engine.src.runtime.wk_keys { WK_NEXT }
import from engine.src.builtins.array {
    js_array_create,
    js_is_array,
    js_array_len,
    js_array_get
}
import from engine.src.builtins.map {
    _same_value_zero,
    _can_be_held_weakly,
    MAP_SET_ITER_KIND_KEY,
    MAP_SET_ITER_KIND_VALUE,
    MAP_SET_ITER_KIND_ENTRY,
    msi_idx_slot_key,
    msi_kind_slot_key,
    msi_done_slot_key,
    msi_cursor_get,
    msi_cursor_value
}
import from engine.src.runtime.error {
    make_type_error,
    vm_throw_native,
    vm_has_native_exc
}
import from engine.src.builtins.markers { _KEY_IS_SET, _KEY_IS_WEAKSET }
import from engine.src.builtins.native_registry { js_native_create }
import from engine.src.runtime.gc_pin { gc_pin_value }
import from engine.src.builtins.generators { js_iter_result }
import from engine.src.builtins.native_kinds {
    NATIVE_KIND_ITERATOR_RETURN_THIS,
    NATIVE_KIND_MAP_SET_ITER_NEXT
}

glob _SET_PROTO: JSValue = js_undefined(),
     _WEAKSET_PROTO: JSValue = js_undefined(),
     _SET_ITERATOR_PROTO: JSValue = js_undefined(),
     _MSI_SET_KEY: int = -1;

def:pub js_set_set_proto(proto: JSValue) {
    _SET_PROTO = proto;
    gc_pin_value(proto);  # glob-held singleton — invisible to the GC root walk
}

def:pub js_weakset_set_proto(proto: JSValue) {
    _WEAKSET_PROTO = proto;
    gc_pin_value(proto);  # glob-held singleton — invisible to the GC root walk
}

def:pub js_is_set(v: JSValue) -> bool {
    return (js_object_brand(v) & BRAND_SET) != 0;
}

def:pub js_is_weakset(v: JSValue) -> bool {
    return (js_object_brand(v) & BRAND_WEAKSET) != 0;
}

glob _SET_REALM: Realm;

def:pub set_set_realm(r: Realm) {
    _SET_REALM = r;
}

def _set_idx(s: JSValue) -> int {
    idx_v: JSValue = js_object_get(s, _KEY_IS_SET);
    return jsv_to_int32(idx_v);
}

def _weakset_idx(s: JSValue) -> int {
    idx_v: JSValue = js_object_get(s, _KEY_IS_WEAKSET);
    return jsv_to_int32(idx_v);
}

def _msi_set_slot_key -> int {
    if _MSI_SET_KEY < 0 {
        _MSI_SET_KEY = str_intern("__MSI_SET__");
    }
    return _MSI_SET_KEY;
}

def _set_key_id(key: JSValue) -> int {
    # Canonicalize string keys by content — identical strings can live under
    # multiple table ids (Buffer.toString/decoders mint fresh cells) and Set
    # membership is SameValueZero; see _map_key_id in map.jac for the full
    # rationale (rollup exportDescriptions bug).
    if jsv_is_string_cell(key) {
        sk_sid: int = jsv_to_table_id(key);
        if sk_sid >= HEAP_STRING_BASE {
            # Copy-before-intern: see _map_key_id in map.jac (views must not
            # enter the intern table — suffix-slice corruption class).
            sk_hs: str = str_from_id(sk_sid);
            return str_intern(str_substr(sk_hs, 0, len(sk_hs)));
        }
        return sk_sid;
    }
    # An integral float64 in int32 range (including -0) hashes like that int32:
    # same SameValueZero key — see _map_key_id in map.jac.
    if jsv_is_double(key) {
        skd: float = jsv_to_double(key);
        if skd == skd and skd >= -2147483648.0 and skd <= 2147483647.0 {
            skd_i: int = int(skd);
            if float(skd_i) == skd {
                return jsv_to_table_id(js_int(skd_i));
            }
        }
    }
    return jsv_to_table_id(key);
}

def _set_find(ss: JSSetStorage, key: JSValue) -> int {
    if jsv_is_double(key) {
        kd: float = jsv_to_double(key);
        if kd != kd {
            ni: int = 0;
            nn: int = len(ss.ekeys);
            while ni < nn {
                nk: JSValue = ss.ekeys[ni];
                if not jsv_is_hole(nk) and _same_value_zero(nk, key) {
                    return ni;
                }
                ni = ni + 1;
            }
            return -1;
        }
    }
    if len(ss.key_index) == 0 {
        return -1;
    }
    idx: int = ss.key_index.get(_set_key_id(key), -1);
    if idx >= 0 and idx < len(ss.ekeys) {
        ik: JSValue = ss.ekeys[idx];
        if not jsv_is_hole(ik) and _same_value_zero(ik, key) {
            return idx;
        }
    }
    return -1;
}

"""Give the Set its own member containers before its first add."""
def _set_own(ss: JSSetStorage) {
    if not ss.owned {
        ss.ekeys = [];
        ss.key_index = {};
        ss.owned = True;
    }
}

"""Drop the deleted members in front of the first live one once they are at
least half of the members (amortized O(1) per delete). A Set used as a queue
deletes from the front, and every new iterator walked them again (quadratic)."""
def _set_compact_prefix(ss: JSSetStorage) -> None {
    n: int = len(ss.ekeys);
    k: int = ss.head;
    if k < 0 {
        k = n;
    }
    if k < 32 or k * 2 < n {
        return;
    }
    kk: list[JSValue] = [];
    i: int = k;
    while i < n {
        kk.append(ss.ekeys[i]);
        i = i + 1;
    }
    kids: list[int] = [];
    for kid in ss.key_index {
        kids.append(kid);
    }
    for kid2 in kids {
        ss.key_index[kid2] = ss.key_index[kid2] - k;
    }
    ss.ekeys = kk;
    if ss.head >= 0 {
        ss.head = ss.head - k;
    }
    ss.base = ss.base + k;
}

def:pub js_set_create -> JSValue {
    return js_set_create_with_proto(_SET_PROTO);
}

"""Create a Set whose [[Prototype]] is `proto` (OrdinaryCreateFromConstructor)."""
def:pub js_set_create_with_proto(proto: JSValue) -> JSValue {
    ss: JSSetStorage = JSSetStorage(
        ekeys=SET_NO_VALS, key_index=SET_NO_INDEX, items=SET_NO_VALS
    );
    set_idx: int = -1;
    if len(_SET_REALM.free_set_slots) > 0 {  # G0.5: reuse a swept Set slot
        _fss_last: int = len(_SET_REALM.free_set_slots) - 1;
        set_idx = _SET_REALM.free_set_slots[_fss_last];
        del _SET_REALM.free_set_slots[_fss_last];
        _SET_REALM.sets[set_idx] = ss;  # fresh ss clears the DEAD tombstone
        _SET_REALM.sets_mark_epoch[set_idx] = 0;
    } else {
        set_idx = len(_SET_REALM.sets);
        _SET_REALM.sets.append(ss);
        _SET_REALM.sets_mark_epoch.append(0);
    }
    gc_note_alloc(_SET_REALM);  # G0.4: account set allocation
    s: JSValue = js_undefined();
    if jsv_is_object_cell(proto) {
        s = js_object_create(proto);
    } elif jsv_is_object_cell(_SET_PROTO) {
        s = js_object_create(_SET_PROTO);
    } else {
        s = js_object_create_null();
    }
    js_object_set(s, _KEY_IS_SET, js_int(set_idx));
    return s;
}

def:pub js_weakset_create -> JSValue {
    return js_weakset_create_with_proto(_WEAKSET_PROTO);
}

"""Create a WeakSet whose [[Prototype]] is `proto` (OrdinaryCreateFromConstructor)."""
def:pub js_weakset_create_with_proto(proto: JSValue) -> JSValue {
    witems: list[JSValue] = [];
    ss: JSSetStorage = JSSetStorage(
        ekeys=SET_NO_VALS, key_index=SET_NO_INDEX, items=witems
    );
    set_idx: int = -1;
    if len(_SET_REALM.free_set_slots) > 0 {  # G0.5: reuse a swept Set slot
        _fss_last: int = len(_SET_REALM.free_set_slots) - 1;
        set_idx = _SET_REALM.free_set_slots[_fss_last];
        del _SET_REALM.free_set_slots[_fss_last];
        _SET_REALM.sets[set_idx] = ss;  # fresh ss clears the DEAD tombstone
        _SET_REALM.sets_mark_epoch[set_idx] = 0;
    } else {
        set_idx = len(_SET_REALM.sets);
        _SET_REALM.sets.append(ss);
        _SET_REALM.sets_mark_epoch.append(0);
    }
    gc_note_alloc(_SET_REALM);  # G0.4: account set allocation
    s: JSValue = js_undefined();
    if jsv_is_object_cell(proto) {
        s = js_object_create(proto);
    } elif jsv_is_object_cell(_WEAKSET_PROTO) {
        s = js_object_create(_WEAKSET_PROTO);
    } else {
        s = js_object_create_null();
    }
    js_object_set(s, _KEY_IS_WEAKSET, js_int(set_idx));
    return s;
}

def:pub js_set_add(s: JSValue, val: JSValue) -> JSValue {
    ss: JSSetStorage = _SET_REALM.sets[_set_idx(s)];
    fi: int = _set_find(ss, val);
    if fi >= 0 {
        return s;
    }
    _set_own(ss);
    ni: int = len(ss.ekeys);
    ss.ekeys.append(val);
    if ss.head < 0 {
        ss.head = ni;
    }
    ss.key_index[_set_key_id(val)] = ni;
    ss.live_count = ss.live_count + 1;
    return s;
}

def:pub js_set_has(s: JSValue, val: JSValue) -> JSValue {
    ss: JSSetStorage = _SET_REALM.sets[_set_idx(s)];
    if _set_find(ss, val) >= 0 {
        return js_true();
    }
    return js_false();
}

def:pub js_set_delete(s: JSValue, val: JSValue) -> JSValue {
    ss: JSSetStorage = _SET_REALM.sets[_set_idx(s)];
    fi: int = _set_find(ss, val);
    if fi < 0 {
        return js_false();
    }
    ss.ekeys[fi] = jsv_hole();
    kid: int = _set_key_id(val);
    if ss.key_index.get(kid, -1) == fi {
        del ss.key_index[kid];
    }
    if fi == ss.head {
        nh: int = fi + 1;
        nn: int = len(ss.ekeys);
        while nh < nn and jsv_is_hole(ss.ekeys[nh]) {
            nh = nh + 1;
        }
        if nh >= nn {
            nh = -1;
        }
        ss.head = nh;
    }
    if ss.live_count > 0 {
        ss.live_count = ss.live_count - 1;
    }
    _set_compact_prefix(ss);
    return js_true();
}

def:pub js_set_clear(s: JSValue) {
    ss: JSSetStorage = _SET_REALM.sets[_set_idx(s)];
    # Every member is deleted, so drop them all; in-flight iterators resume at
    # the first member added after the clear (SetData keeps its length).
    ss.base = ss.base + len(ss.ekeys);
    ss.ekeys = SET_NO_VALS;
    ss.key_index = SET_NO_INDEX;
    ss.owned = False;
    ss.head = -1;
    ss.live_count = 0;
}

def:pub js_set_size(s: JSValue) -> int {
    ss: JSSetStorage = _SET_REALM.sets[_set_idx(s)];
    return ss.live_count;
}

def:pub js_set_values_array(s: JSValue) -> JSValue {
    ss: JSSetStorage = _SET_REALM.sets[_set_idx(s)];
    result: list[JSValue] = [];
    i: int = 0;
    n: int = len(ss.ekeys);
    while i < n {
        if not jsv_is_hole(ss.ekeys[i]) {
            result.append(ss.ekeys[i]);
        }
        i = i + 1;
    }
    return js_array_create(result);
}

def:pub js_set_entries_array(s: JSValue) -> JSValue {
    ss: JSSetStorage = _SET_REALM.sets[_set_idx(s)];
    result: list[JSValue] = [];
    i: int = 0;
    n: int = len(ss.ekeys);
    while i < n {
        if not jsv_is_hole(ss.ekeys[i]) {
            pair: JSValue = js_array_create([ss.ekeys[i], ss.ekeys[i]]);
            result.append(pair);
        }
        i = i + 1;
    }
    return js_array_create(result);
}

def:pub js_set_iter_items(s: JSValue) -> JSValue {
    return js_set_values_array(s);
}

def _set_build_iter_proto -> JSValue {
    p: JSValue = js_object_create(js_object_get_ordinary_proto());
    next_fn: JSValue = js_native_create("next", 0, NATIVE_KIND_MAP_SET_ITER_NEXT);
    js_object_define_property(
        p,
        WK_NEXT,
        JSProperty(
            key=WK_NEXT,
            value=next_fn,
            writable=True,
            enumerable=False,
            configurable=True,
            deleted=False
        )
    );
    iter_key: int = SYMBOL_KEY_BASE + SYMBOL_ITERATOR;
    iter_fn: JSValue = js_native_create(
        "[Symbol.iterator]", 0, NATIVE_KIND_ITERATOR_RETURN_THIS
    );
    js_object_define_property(
        p,
        iter_key,
        JSProperty(
            key=iter_key,
            value=iter_fn,
            writable=True,
            enumerable=False,
            configurable=True,
            deleted=False
        )
    );
    tag_key: int = SYMBOL_KEY_BASE + SYMBOL_TO_STRING_TAG;
    tag_val: JSValue = jsv_from_string_id(str_intern("Set Iterator"));
    js_object_define_property(
        p,
        tag_key,
        JSProperty(
            key=tag_key,
            value=tag_val,
            writable=False,
            enumerable=False,
            configurable=True,
            deleted=False
        )
    );
    return p;
}

def:pub js_get_set_iterator_proto -> JSValue {
    if not jsv_is_object_cell(_SET_ITERATOR_PROTO) {
        _SET_ITERATOR_PROTO = _set_build_iter_proto();
        gc_pin_value(_SET_ITERATOR_PROTO);  # glob-held singleton — invisible to the GC root walk
    }
    return _SET_ITERATOR_PROTO;
}

def:pub js_make_set_iterator(s: JSValue, kind: int) -> JSValue {
    it: JSValue = js_object_create(js_get_set_iterator_proto());
    js_object_set(it, _msi_set_slot_key(), s);
    js_object_set(it, msi_idx_slot_key(), js_int(0));
    js_object_set(it, msi_kind_slot_key(), js_int(kind));
    return it;
}

def:pub js_is_set_iterator(v: JSValue) -> bool {
    if not jsv_is_object_cell(v) {
        return False;
    }
    return js_object_has_own(v, _msi_set_slot_key());
}

"""Advance a Set iterator: the next value ([v, v] for entries), or the hole
sentinel once exhausted, after which it stays done (§24.2.5.1)."""
def:pub js_set_iterator_step(it: JSValue) -> JSValue {
    if not js_is_set_iterator(it) {
        return jsv_hole();
    }
    if js_object_has_own(it, msi_done_slot_key()) {
        return jsv_hole();
    }
    s: JSValue = js_object_get(it, _msi_set_slot_key());
    if not js_is_set(s) {
        js_object_set(it, msi_done_slot_key(), js_true());
        return jsv_hole();
    }
    ss: JSSetStorage = _SET_REALM.sets[_set_idx(s)];
    n: int = len(ss.ekeys);
    p: int = msi_cursor_get(it) - ss.base;
    # Every member before head is deleted; no head means no live member.
    if ss.head < 0 {
        p = n;
    } elif p < ss.head {
        p = ss.head;
    }
    while p < n and jsv_is_hole(ss.ekeys[p]) {
        p = p + 1;
    }
    if p >= n {
        js_object_set(it, msi_done_slot_key(), js_true());
        return jsv_hole();
    }
    key: JSValue = ss.ekeys[p];
    js_object_set(it, msi_idx_slot_key(), msi_cursor_value(ss.base + p + 1));
    kind_v: JSValue = js_object_get(it, msi_kind_slot_key());
    if jsv_is_int32(kind_v) and jsv_to_int32(kind_v) == MAP_SET_ITER_KIND_ENTRY {
        return js_array_create([key, key]);
    }
    return key;
}

def:pub js_set_iterator_next(it: JSValue) -> JSValue {
    v: JSValue = js_set_iterator_step(it);
    if jsv_is_hole(v) {
        return js_iter_result(js_undefined(), True);
    }
    return js_iter_result(v, False);
}

# ── WeakSet ───────────────────────────────────────────────────────────────────
def:pub js_weakset_add(s: JSValue, val: JSValue) -> JSValue {
    if not _can_be_held_weakly(val) {
        vm_throw_native(make_type_error("Invalid value used in weak set"));
        return js_undefined();
    }
    ss: JSSetStorage = _SET_REALM.sets[_weakset_idx(s)];
    i: int = 0;
    n: int = len(ss.items);
    while i < n {
        if _same_value_zero(ss.items[i], val) {
            return s;
        }
        i = i + 1;
    }
    ss.items.append(val);
    return s;
}

def:pub js_weakset_has(s: JSValue, val: JSValue) -> JSValue {
    ss: JSSetStorage = _SET_REALM.sets[_weakset_idx(s)];
    i: int = 0;
    n: int = len(ss.items);
    while i < n {
        if _same_value_zero(ss.items[i], val) {
            return js_true();
        }
        i = i + 1;
    }
    return js_false();
}

def:pub js_weakset_delete(s: JSValue, val: JSValue) -> JSValue {
    ss: JSSetStorage = _SET_REALM.sets[_weakset_idx(s)];
    i: int = 0;
    n: int = len(ss.items);
    while i < n {
        if _same_value_zero(ss.items[i], val) {
            ni: list[JSValue] = [];
            di: int = 0;
            while di < n {
                if di != i {
                    ni.append(ss.items[di]);
                }
                di = di + 1;
            }
            ss.items = ni;
            return js_true();
        }
        i = i + 1;
    }
    return js_false();
}

def:pub js_Set(args: list[JSValue]) -> JSValue {
    s: JSValue = js_set_create();
    if len(args) > 0 {
        init: JSValue = args[0];
        if jsv_is_null(init) or jsv_is_undefined(init) {
            return s;
        }
        if js_is_set(init) {
            vals: JSValue = js_set_values_array(init);
            n_v: int = js_array_len(vals);
            vi: int = 0;
            while vi < n_v {
                js_set_add(s, js_array_get(vals, vi));
                vi = vi + 1;
            }
            return s;
        }
        if not js_is_array(init) {
            vm_throw_native(
                make_type_error(
                    "object is not iterable (cannot read property Symbol(Symbol.iterator))"
                )
            );
            return js_undefined();
        }
        n: int = js_array_len(init);
        i: int = 0;
        while i < n {
            js_set_add(s, js_array_get(init, i));
            i = i + 1;
        }
    }
    return s;
}

"""WeakSet constructor fallback (VM CALL_NEW handles full iterable + IteratorClose)."""
def:pub js_WeakSet(args: list[JSValue]) -> JSValue {
    ws: JSValue = js_weakset_create();
    if len(args) > 0 {
        init: JSValue = args[0];
        if jsv_is_null(init) or jsv_is_undefined(init) {
            return ws;
        }
        if js_is_array(init) {
            n_ws: int = js_array_len(init);
            wi: int = 0;
            while wi < n_ws {
                js_weakset_add(ws, js_array_get(init, wi));
                if vm_has_native_exc() {
                    return js_undefined();
                }
                wi = wi + 1;
            }
            return ws;
        }
        vm_throw_native(
            make_type_error(
                "object is not iterable (cannot read property Symbol(Symbol.iterator))"
            )
        );
        return js_undefined();
    }
    return ws;
}
