"""Built-in: Map constructor, prototype methods, and WeakMap.

Storage design
──────────────
JSMapStorage (Jac obj):
  - keys: list[JSValue]
  - vals: list[JSValue]

All Maps (including WeakMaps) share a single _MAP_REALM.maps: list[JSMapStorage].

A Map JSObject is distinguished from a plain object by a hidden property:
  _KEY_IS_MAP     (= 1_000_002) → Int32(index into _MAP_REALM.maps)
  _KEY_IS_WEAKMAP (= 1_000_004) → Int32(index into _MAP_REALM.maps)

Key equality uses SameValueZero (like === but NaN === NaN).

ECMAScript spec : §24.1 — Map Objects
Bun reference   : bun/src/js/builtins/Map.ts, MapPrototype.ts
"""

import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    js_true,
    js_false,
    js_int,
    js_number,
    jsv_hole,
    jsv_is_hole,
    jsv_is_int32,
    jsv_is_double,
    jsv_is_bool,
    jsv_is_null,
    jsv_is_object_cell,
    jsv_is_undefined,
    jsv_is_string_cell,
    jsv_is_symbol,
    jsv_is_any_object,
    jsv_is_cell,
    jsv_cell_kind,
    jsv_to_int32,
    jsv_to_double,
    jsv_to_bool,
    jsv_to_table_id,
    jsv_from_string_id,
    jsv_undefined,
    JS_CELL_KIND_NATIVE
}
import from engine.src.runtime.jsstring { str_from_id, str_substr, HEAP_STRING_BASE }
import from engine.src.builtins.map_type { JSMapStorage, MAP_NO_VALS, MAP_NO_INDEX }
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
import from engine.src.runtime.jsobj_type { JSProperty, BRAND_MAP, BRAND_WEAKMAP }
import from engine.src.runtime.jsstring { str_intern }
import from engine.src.runtime.encoding { SYMBOL_KEY_BASE }
import from engine.src.runtime.jssymbol { SYMBOL_ITERATOR, SYMBOL_TO_STRING_TAG }
import from engine.src.runtime.wk_keys { WK_NEXT }
import from engine.src.builtins.array {
    js_array_create,
    js_is_array,
    js_array_len,
    js_array_get
}
import from engine.src.runtime.error { make_type_error, vm_throw_native }
import from engine.src.builtins.markers { _KEY_IS_MAP, _KEY_IS_WEAKMAP }
import from engine.src.builtins.native_registry { js_native_create }
import from engine.src.runtime.gc_pin { gc_pin_value }
import from engine.src.builtins.generators { js_iter_result }
import from engine.src.builtins.native_kinds {
    NATIVE_KIND_ITERATOR_RETURN_THIS,
    NATIVE_KIND_MAP_SET_ITER_NEXT
}

# ── Hidden marker keys (canonical values in builtins/markers.na.jac) ─────────
"""Internal: Map.prototype object, wired by init_global."""
glob _MAP_PROTO: JSValue = jsv_undefined();

"""Internal: WeakMap.prototype object, wired by init_global."""
glob _WEAKMAP_PROTO: JSValue = jsv_undefined();

def:pub js_map_set_proto(proto: JSValue) {
    _MAP_PROTO = proto;
    gc_pin_value(proto);  # glob-held singleton — invisible to the GC root walk
}

def:pub js_weakmap_set_proto(proto: JSValue) {
    _WEAKMAP_PROTO = proto;
    gc_pin_value(proto);  # glob-held singleton — invisible to the GC root walk
}

# ── SameValueZero key equality (§7.2.10) ─────────────────────────────────────
"""Return True if a and b are SameValueZero-equal.
Like strict equality (===) but NaN === NaN and +0 === -0.
Used for Map/Set key lookup."""
def:pub _same_value_zero(a: JSValue, b: JSValue) -> bool {
    # Strings compare by CONTENT: a computed (heap) string and an interned string
    # of equal text have different ids/top-bits, so id comparison alone would
    # miss them and break Map/Set lookup on computed keys. Check before the
    # top-bits shortcut, which would otherwise reject them.
    if jsv_is_string_cell(a) and jsv_is_string_cell(b) {
        aid_svz: int = jsv_to_table_id(a);
        bid_svz: int = jsv_to_table_id(b);
        if aid_svz == bid_svz {
            return True;
        }
        return str_from_id(aid_svz) == str_from_id(bid_svz);
    }
    if (a >> 44) != (b >> 44) {
        # Numbers compare by VALUE across encodings: an int32 and a float64 of the
        # same value are one key — 2 and the 2.0 that Math.sqrt(4) or an
        # Array.from({length}) index produces — and so are +0 and -0
        # (ECMAScript SameValueZero).
        if (jsv_is_int32(a) or jsv_is_double(a))
            and (jsv_is_int32(b) or jsv_is_double(b)) {
            svz_ad: float = float(jsv_to_int32(a))
                if jsv_is_int32(a)
                else jsv_to_double(a);
            svz_bd: float = float(jsv_to_int32(b))
                if jsv_is_int32(b)
                else jsv_to_double(b);
            if svz_ad != svz_ad and svz_bd != svz_bd {
                return True;
            }
            return svz_ad == svz_bd;
        }
        return False;
    }
    if jsv_is_undefined(a) {
        return True;
    }
    if jsv_is_null(a) {
        return True;
    }
    if jsv_is_bool(a) {
        return jsv_to_bool(a) == jsv_to_bool(b);
    }
    if jsv_is_int32(a) {
        return jsv_to_int32(a) == jsv_to_int32(b);
    }
    if jsv_is_double(a) {
        # NaN !== NaN in normal equality, but SameValueZero says NaN === NaN
        svz_an: bool = jsv_to_double(a) != jsv_to_double(a);
        svz_bn: bool = jsv_to_double(b) != jsv_to_double(b);
        if svz_an and svz_bn {
            return True;
        }
        return jsv_to_double(a) == jsv_to_double(b);
    }
    # String, Symbol, Object, Function: identity comparison via pointer/index
    return jsv_to_table_id(a) == jsv_to_table_id(b);
}

# ── Internal Map helpers ──────────────────────────────────────────────────────
"""Return True if v is a JS Map (has the _KEY_IS_MAP marker)."""
def:pub js_is_map(v: JSValue) -> bool {
    return (js_object_brand(v) & BRAND_MAP) != 0;
}

"""Return True if v is a JS WeakMap (has the _KEY_IS_WEAKMAP marker)."""
def:pub js_is_weakmap(v: JSValue) -> bool {
    return (js_object_brand(v) & BRAND_WEAKMAP) != 0;
}

"""Return the _MAP_REALM.maps index of a Map."""
glob _MAP_REALM: Realm;

def:pub map_set_realm(r: Realm) {
    _MAP_REALM = r;
}

def _map_idx(m: JSValue) -> int {
    idx_v: JSValue = js_object_get(m, _KEY_IS_MAP);
    return jsv_to_int32(idx_v);
}

"""Return the _MAP_REALM.maps index of a WeakMap."""
def _weakmap_idx(m: JSValue) -> int {
    idx_v: JSValue = js_object_get(m, _KEY_IS_WEAKMAP);
    return jsv_to_int32(idx_v);
}

"""CanBeHeldWeakly (§9.2.3 / WeakRef): Objects (incl. callables) and
non-registered Symbols. Primitives and Symbol.keyFor symbols are rejected."""
def:pub _can_be_held_weakly(v: JSValue) -> bool {
    # Fast reject for non-cells (numbers, bools, null, undefined, …).
    if not jsv_is_cell(v) {
        return False;
    }
    # Objects + function/native callables.
    if jsv_is_any_object(v) {
        return True;
    }
    # Non-registered symbols only.
    if not jsv_is_symbol(v) {
        return False;
    }
    sym_id: int = jsv_to_table_id(v);
    for registry_key in _MAP_REALM.symbol_registry {
        if _MAP_REALM.symbol_registry[registry_key] == sym_id {
            return False;
        }
    }
    return True;
}

"""Create a new empty Map and register it in _MAP_REALM.maps."""
def:pub js_map_create -> JSValue {
    return js_map_create_with_proto(_MAP_PROTO);
}

"""Create a Map whose [[Prototype]] is `proto` (OrdinaryCreateFromConstructor)."""
def:pub js_map_create_with_proto(proto: JSValue) -> JSValue {
    ms: JSMapStorage = JSMapStorage(
        ekeys=MAP_NO_VALS,
        evals=MAP_NO_VALS,
        key_index=MAP_NO_INDEX,
        keys=MAP_NO_VALS,
        vals=MAP_NO_VALS
    );
    map_idx: int = -1;
    if len(_MAP_REALM.free_map_slots) > 0 {  # G0.5: reuse a swept Map slot
        _fms_last: int = len(_MAP_REALM.free_map_slots) - 1;
        map_idx = _MAP_REALM.free_map_slots[_fms_last];
        del _MAP_REALM.free_map_slots[_fms_last];
        _MAP_REALM.maps[map_idx] = ms;  # fresh ms clears the DEAD tombstone
        _MAP_REALM.maps_mark_epoch[map_idx] = 0;
    } else {
        map_idx = len(_MAP_REALM.maps);
        _MAP_REALM.maps.append(ms);
        _MAP_REALM.maps_mark_epoch.append(0);  # A2.2b GC mark bitmap
    }
    gc_note_alloc(_MAP_REALM);  # G0.4: account map allocation
    m: JSValue = js_undefined();
    if jsv_is_object_cell(proto) {
        m = js_object_create(proto);
    } elif jsv_is_object_cell(_MAP_PROTO) {
        m = js_object_create(_MAP_PROTO);
    } else {
        m = js_object_create_null();
    }
    js_object_set(m, _KEY_IS_MAP, js_int(map_idx));
    return m;
}

"""Create a new empty WeakMap and register it in _MAP_REALM.maps."""
def:pub js_weakmap_create -> JSValue {
    return js_weakmap_create_with_proto(_WEAKMAP_PROTO);
}

"""Create a WeakMap whose [[Prototype]] is `proto` (OrdinaryCreateFromConstructor)."""
def:pub js_weakmap_create_with_proto(proto: JSValue) -> JSValue {
    wkeys: list[JSValue] = [];
    wvals: list[JSValue] = [];
    ms: JSMapStorage = JSMapStorage(
        ekeys=MAP_NO_VALS,
        evals=MAP_NO_VALS,
        key_index=MAP_NO_INDEX,
        keys=wkeys,
        vals=wvals
    );
    map_idx: int = -1;
    if len(_MAP_REALM.free_map_slots) > 0 {  # G0.5: reuse a swept Map slot
        _fms_last: int = len(_MAP_REALM.free_map_slots) - 1;
        map_idx = _MAP_REALM.free_map_slots[_fms_last];
        del _MAP_REALM.free_map_slots[_fms_last];
        _MAP_REALM.maps[map_idx] = ms;  # fresh ms clears the DEAD tombstone
        _MAP_REALM.maps_mark_epoch[map_idx] = 0;
    } else {
        map_idx = len(_MAP_REALM.maps);
        _MAP_REALM.maps.append(ms);
        _MAP_REALM.maps_mark_epoch.append(0);  # A2.2b GC mark bitmap
    }
    gc_note_alloc(_MAP_REALM);  # G0.4: account map allocation
    m: JSValue = js_undefined();
    if jsv_is_object_cell(proto) {
        m = js_object_create(proto);
    } elif jsv_is_object_cell(_WEAKMAP_PROTO) {
        m = js_object_create(_WEAKMAP_PROTO);
    } else {
        m = js_object_create_null();
    }
    js_object_set(m, _KEY_IS_WEAKMAP, js_int(map_idx));
    return m;
}

"""Stable hash-table key for Map key_index — tag+payload so 1 and true never collide."""
def _map_key_id(key: JSValue) -> int {
    if jsv_is_int32(key) {
        return 0x40000000 | (jsv_to_int32(key) & 0x3FFFFFFF);
    }
    if jsv_is_bool(key) {
        if jsv_to_bool(key) {
            return 0x50000001;
        }
        return 0x50000000;
    }
    if jsv_is_double(key) {
        kd: float = jsv_to_double(key);
        if kd != kd {
            return 0x60000000;
        }
        if kd == 0.0 {
            return 0x60000001;
        }
        # An integral float64 in int32 range hashes like that int32: they are
        # the same SameValueZero key (rollup's chunk assignment keys a Map by
        # Array.from({length}) indices and missed every lookup).
        if kd >= -2147483648.0 and kd <= 2147483647.0 {
            kd_i: int = int(kd);
            if float(kd_i) == kd {
                return 0x40000000 | (kd_i & 0x3FFFFFFF);
            }
        }
    }
    if jsv_is_null(key) {
        return 0x70000000;
    }
    if jsv_is_undefined(key) {
        return 0x70000001;
    }
    if jsv_is_string_cell(key) {
        # Canonicalize string keys by content: identical strings can live
        # under multiple table ids (Buffer.toString/decoders mint fresh
        # cells), and Map keys are SameValueZero — hashing the raw id made
        # map.get(literal) miss a decoded-string key (rollup: exportDescriptions
        # keyed by AST-decoded identifiers were unfindable).
        mk_sid: int = jsv_to_table_id(key);
        if mk_sid >= HEAP_STRING_BASE {
            # Heap strings may be interior-pointer VIEWS (suffix slices); the
            # intern table retains its argument, so intern a COMPACT COPY —
            # interning a view dangles when its backing string is released
            # (the suffix-slice intern corruption class; caused nondeterministic
            # segfaults across the rollup suite when Map ops interned views).
            mk_hs: str = str_from_id(mk_sid);
            return str_intern(str_substr(mk_hs, 0, len(mk_hs)));
        }
        # id < HEAP_STRING_BASE is already the canonical interned id.
        return mk_sid;
    }
    return jsv_to_table_id(key);
}

def _map_find(ms: JSMapStorage, key: JSValue) -> int {
    # SameValueZero keys that do not share a stable table id need a scan:
    # NaN === NaN, and +0 (int32) === -0 (float64) across encodings.
    need_scan: bool = False;
    if jsv_is_double(key) {
        kd: float = jsv_to_double(key);
        if kd != kd or kd == 0.0 {
            need_scan = True;
        }
    } elif jsv_is_int32(key) and jsv_to_int32(key) == 0 {
        need_scan = True;
    }
    if need_scan {
        ni: int = 0;
        nn: int = len(ms.ekeys);
        while ni < nn {
            nk: JSValue = ms.ekeys[ni];
            if not jsv_is_hole(nk) and _same_value_zero(nk, key) {
                return ni;
            }
            ni = ni + 1;
        }
        return -1;
    }
    if len(ms.key_index) == 0 {
        return -1;
    }
    idx: int = ms.key_index.get(_map_key_id(key), -1);
    if idx >= 0 and idx < len(ms.ekeys) {
        ik: JSValue = ms.ekeys[idx];
        if not jsv_is_hole(ik) and _same_value_zero(ik, key) {
            return idx;
        }
    }
    return -1;
}

"""Give the Map its own entry containers before its first insert."""
def _map_own(ms: JSMapStorage) {
    if not ms.owned {
        ms.ekeys = [];
        ms.evals = [];
        ms.key_index = {};
        ms.owned = True;
    }
}

"""Drop the deleted entries in front of the first live one once they are at
least half of the entries (amortized O(1) per delete). A Map used as a queue
deletes from the front, and every new iterator walked them again (quadratic)."""
def _map_compact_prefix(ms: JSMapStorage) -> None {
    n: int = len(ms.ekeys);
    k: int = ms.head;
    if k < 0 {
        k = n;
    }
    if k < 32 or k * 2 < n {
        return;
    }
    kk: list[JSValue] = [];
    kv: list[JSValue] = [];
    i: int = k;
    while i < n {
        kk.append(ms.ekeys[i]);
        kv.append(ms.evals[i]);
        i = i + 1;
    }
    kids: list[int] = [];
    for kid in ms.key_index {
        kids.append(kid);
    }
    for kid2 in kids {
        ms.key_index[kid2] = ms.key_index[kid2] - k;
    }
    ms.ekeys = kk;
    ms.evals = kv;
    if ms.head >= 0 {
        ms.head = ms.head - k;
    }
    ms.base = ms.base + k;
}

# ── Map prototype methods ─────────────────────────────────────────────────────
"""Return the value for key in map, or undefined if not found."""
def:pub js_map_get(m: JSValue, key: JSValue) -> JSValue {
    ms: JSMapStorage = _MAP_REALM.maps[_map_idx(m)];
    fi: int = _map_find(ms, key);
    if fi >= 0 {
        return ms.evals[fi];
    }
    return js_undefined();
}

"""Set key→val in map; return the map (for chaining)."""
def:pub js_map_set(m: JSValue, key: JSValue, val: JSValue) -> JSValue {
    ms: JSMapStorage = _MAP_REALM.maps[_map_idx(m)];
    fi: int = _map_find(ms, key);
    if fi >= 0 {
        ms.evals[fi] = val;
        return m;
    }
    _map_own(ms);
    ni: int = len(ms.ekeys);
    ms.ekeys.append(key);
    ms.evals.append(val);
    if ms.head < 0 {
        ms.head = ni;
    }
    ms.key_index[_map_key_id(key)] = ni;
    ms.live_count = ms.live_count + 1;
    return m;
}

"""Return true if key exists in map."""
def:pub js_map_has(m: JSValue, key: JSValue) -> JSValue {
    ms: JSMapStorage = _MAP_REALM.maps[_map_idx(m)];
    fi: int = _map_find(ms, key);
    if fi >= 0 {
        return js_true();
    }
    return js_false();
}

"""Delete key from map; return true if deleted, false if not found."""
def:pub js_map_delete(m: JSValue, key: JSValue) -> JSValue {
    ms: JSMapStorage = _MAP_REALM.maps[_map_idx(m)];
    fi: int = _map_find(ms, key);
    if fi < 0 {
        return js_false();
    }
    ms.ekeys[fi] = jsv_hole();
    ms.evals[fi] = js_undefined();
    kid: int = _map_key_id(key);
    if ms.key_index.get(kid, -1) == fi {
        del ms.key_index[kid];
    }
    if fi == ms.head {
        nh: int = fi + 1;
        nn: int = len(ms.ekeys);
        while nh < nn and jsv_is_hole(ms.ekeys[nh]) {
            nh = nh + 1;
        }
        if nh >= nn {
            nh = -1;
        }
        ms.head = nh;
    }
    if ms.live_count > 0 {
        ms.live_count = ms.live_count - 1;
    }
    _map_compact_prefix(ms);
    return js_true();
}

"""Remove all entries from map."""
def:pub js_map_clear(m: JSValue) {
    ms: JSMapStorage = _MAP_REALM.maps[_map_idx(m)];
    # Every entry is deleted (ES MapClear), so drop them all; in-flight
    # iterators resume at the first entry added after the clear.
    ms.base = ms.base + len(ms.ekeys);
    ms.ekeys = MAP_NO_VALS;
    ms.evals = MAP_NO_VALS;
    ms.key_index = MAP_NO_INDEX;
    ms.owned = False;
    ms.head = -1;
    ms.live_count = 0;
}

"""Return the number of entries in map as an int."""
def:pub js_map_size(m: JSValue) -> int {
    ms: JSMapStorage = _MAP_REALM.maps[_map_idx(m)];
    return ms.live_count;
}

"""Return a JS Array of all map keys (snapshot — prefer live iterators)."""
def:pub js_map_keys_array(m: JSValue) -> JSValue {
    ms: JSMapStorage = _MAP_REALM.maps[_map_idx(m)];
    result: list[JSValue] = [];
    i: int = 0;
    n: int = len(ms.ekeys);
    while i < n {
        if not jsv_is_hole(ms.ekeys[i]) {
            result.append(ms.ekeys[i]);
        }
        i = i + 1;
    }
    return js_array_create(result);
}

"""Return a JS Array of all map values (snapshot — prefer live iterators)."""
def:pub js_map_values_array(m: JSValue) -> JSValue {
    ms: JSMapStorage = _MAP_REALM.maps[_map_idx(m)];
    result: list[JSValue] = [];
    i: int = 0;
    n: int = len(ms.ekeys);
    while i < n {
        if not jsv_is_hole(ms.ekeys[i]) {
            result.append(ms.evals[i]);
        }
        i = i + 1;
    }
    return js_array_create(result);
}

"""Return a JS Array of [key, val] pair arrays for entries() / Symbol.iterator."""
def:pub js_map_entries_array(m: JSValue) -> JSValue {
    ms: JSMapStorage = _MAP_REALM.maps[_map_idx(m)];
    entries: list[JSValue] = [];
    i: int = 0;
    n: int = len(ms.ekeys);
    while i < n {
        if not jsv_is_hole(ms.ekeys[i]) {
            pair: JSValue = js_array_create([ms.ekeys[i], ms.evals[i]]);
            entries.append(pair);
        }
        i = i + 1;
    }
    return js_array_create(entries);
}

"""Return entries array for use in GET_ITER (same as entries_array)."""
def:pub js_map_iter_entries(m: JSValue) -> JSValue {
    return js_map_entries_array(m);
}

# ── Live Map iterators (§24.1.5) ───────────────────────────────────────────────
# Kind: 0 = key, 1 = value, 2 = key+value. Cursor indexes `nodes` including
# tombstones so delete/reinsert/append during iteration is live.

glob:pub MAP_SET_ITER_KIND_KEY: int = 0,
     MAP_SET_ITER_KIND_VALUE: int = 1,
     MAP_SET_ITER_KIND_ENTRY: int = 2;

glob _MSI_MAP_KEY: int = -1,
     _MSI_IDX_KEY: int = -1,
     _MSI_KIND_KEY: int = -1,
     _MSI_DONE_KEY: int = -1,
     _MAP_ITERATOR_PROTO: JSValue = jsv_undefined(),
     _MSI_STEP_VAL: JSValue = jsv_undefined();

def:pub msi_map_slot_key -> int {
    if _MSI_MAP_KEY < 0 {
        _MSI_MAP_KEY = str_intern("__MSI_MAP__");
    }
    return _MSI_MAP_KEY;
}

def:pub msi_idx_slot_key -> int {
    if _MSI_IDX_KEY < 0 {
        _MSI_IDX_KEY = str_intern("__MSI_IDX__");
    }
    return _MSI_IDX_KEY;
}

def:pub msi_kind_slot_key -> int {
    if _MSI_KIND_KEY < 0 {
        _MSI_KIND_KEY = str_intern("__MSI_KIND__");
    }
    return _MSI_KIND_KEY;
}

"""Permanent [[Done]] latch — once set, iterator stays done even if items are added."""
def:pub msi_done_slot_key -> int {
    if _MSI_DONE_KEY < 0 {
        _MSI_DONE_KEY = str_intern("__MSI_DONE__");
    }
    return _MSI_DONE_KEY;
}

"""Iterator cursor: the number of the next node to visit, counted from the
Map/Set's creation (storage `base` + index into `nodes`)."""
def:pub msi_cursor_get(it: JSValue) -> int {
    cv: JSValue = js_object_get(it, msi_idx_slot_key());
    if jsv_is_int32(cv) {
        return jsv_to_int32(cv);
    }
    if jsv_is_double(cv) {
        return int(jsv_to_double(cv));
    }
    return 0;
}

def:pub msi_cursor_value(pos: int) -> JSValue {
    if pos <= 2147483647 {
        return js_int(pos);
    }
    return js_number(float(pos));
}

def _msi_build_iter_proto(tag: str) -> JSValue {
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
    tag_val: JSValue = jsv_from_string_id(str_intern(tag));
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

def:pub js_get_map_iterator_proto -> JSValue {
    if not jsv_is_object_cell(_MAP_ITERATOR_PROTO) {
        _MAP_ITERATOR_PROTO = _msi_build_iter_proto("Map Iterator");
        gc_pin_value(_MAP_ITERATOR_PROTO);  # glob-held singleton — invisible to the GC root walk
    }
    return _MAP_ITERATOR_PROTO;
}

def:pub js_make_map_iterator(m: JSValue, kind: int) -> JSValue {
    it: JSValue = js_object_create(js_get_map_iterator_proto());
    js_object_set(it, msi_map_slot_key(), m);
    js_object_set(it, msi_idx_slot_key(), js_int(0));
    js_object_set(it, msi_kind_slot_key(), js_int(kind));
    return it;
}

def:pub js_is_map_iterator(v: JSValue) -> bool {
    if not jsv_is_object_cell(v) {
        return False;
    }
    return js_object_has_own(v, msi_map_slot_key());
}

"""Advance a Map iterator: the next key, value or [key, value] by kind, or the
hole sentinel once exhausted, after which it stays done (§24.1.5.1)."""
def:pub js_map_iterator_step(it: JSValue) -> JSValue {
    if not js_is_map_iterator(it) {
        return jsv_hole();
    }
    if js_object_has_own(it, msi_done_slot_key()) {
        return jsv_hole();
    }
    m: JSValue = js_object_get(it, msi_map_slot_key());
    if not js_is_map(m) {
        js_object_set(it, msi_done_slot_key(), js_true());
        return jsv_hole();
    }
    ms: JSMapStorage = _MAP_REALM.maps[_map_idx(m)];
    n: int = len(ms.ekeys);
    p: int = msi_cursor_get(it) - ms.base;
    # Every entry before head is deleted; no head means no live entry.
    if ms.head < 0 {
        p = n;
    } elif p < ms.head {
        p = ms.head;
    }
    while p < n and jsv_is_hole(ms.ekeys[p]) {
        p = p + 1;
    }
    if p >= n {
        js_object_set(it, msi_done_slot_key(), js_true());
        return jsv_hole();
    }
    nd_key: JSValue = ms.ekeys[p];
    nd_val: JSValue = ms.evals[p];
    _MSI_STEP_VAL = nd_val;
    js_object_set(it, msi_idx_slot_key(), msi_cursor_value(ms.base + p + 1));
    kind_v: JSValue = js_object_get(it, msi_kind_slot_key());
    kind: int = MAP_SET_ITER_KIND_VALUE;
    if jsv_is_int32(kind_v) {
        kind = jsv_to_int32(kind_v);
    }
    if kind == MAP_SET_ITER_KIND_KEY {
        return nd_key;
    }
    if kind == MAP_SET_ITER_KIND_VALUE {
        return nd_val;
    }
    return js_array_create([nd_key, nd_val]);
}

"""Value of the entry the last js_map_iterator_step visited (read it before
anything can allocate: the glob is not a GC root)."""
def:pub js_map_iterator_step_val -> JSValue {
    return _MSI_STEP_VAL;
}

def:pub js_map_iterator_next(it: JSValue) -> JSValue {
    v: JSValue = js_map_iterator_step(it);
    if jsv_is_hole(v) {
        return js_iter_result(js_undefined(), True);
    }
    return js_iter_result(v, False);
}

# ── WeakMap prototype methods (same underlying storage as Map) ────────────────
"""Return value for key in weakmap, or undefined."""
def:pub js_weakmap_get(m: JSValue, key: JSValue) -> JSValue {
    ms: JSMapStorage = _MAP_REALM.maps[_weakmap_idx(m)];
    i: int = 0;
    n: int = len(ms.keys);
    while i < n {
        if _same_value_zero(ms.keys[i], key) {
            return ms.vals[i];
        }
        i = i + 1;
    }
    return js_undefined();
}

"""Set key→val in weakmap; return the weakmap."""
def:pub js_weakmap_set(m: JSValue, key: JSValue, val: JSValue) -> JSValue {
    if not _can_be_held_weakly(key) {
        vm_throw_native(make_type_error("Invalid value used as weak map key"));
        return js_undefined();
    }
    ms: JSMapStorage = _MAP_REALM.maps[_weakmap_idx(m)];
    i: int = 0;
    n: int = len(ms.keys);
    while i < n {
        if _same_value_zero(ms.keys[i], key) {
            ms.vals[i] = val;
            return m;
        }
        i = i + 1;
    }
    ms.keys.append(key);
    ms.vals.append(val);
    return m;
}

"""Return true if key exists in weakmap."""
def:pub js_weakmap_has(m: JSValue, key: JSValue) -> JSValue {
    ms: JSMapStorage = _MAP_REALM.maps[_weakmap_idx(m)];
    i: int = 0;
    n: int = len(ms.keys);
    while i < n {
        if _same_value_zero(ms.keys[i], key) {
            return js_true();
        }
        i = i + 1;
    }
    return js_false();
}

"""Delete key from weakmap; return true if deleted."""
def:pub js_weakmap_delete(m: JSValue, key: JSValue) -> JSValue {
    ms: JSMapStorage = _MAP_REALM.maps[_weakmap_idx(m)];
    i: int = 0;
    n: int = len(ms.keys);
    while i < n {
        if _same_value_zero(ms.keys[i], key) {
            nk: list[JSValue] = [];
            nv: list[JSValue] = [];
            di: int = 0;
            while di < n {
                if di != i {
                    nk.append(ms.keys[di]);
                    nv.append(ms.vals[di]);
                }
                di = di + 1;
            }
            ms.keys = nk;
            ms.vals = nv;
            return js_true();
        }
        i = i + 1;
    }
    return js_false();
}

# ── Constructor dispatchers ───────────────────────────────────────────────────
"""Map constructor. Called for `new Map()` or `new Map([[k1,v1], ...])`.
Populates from an optional array-of-pairs (or another Map) in args[0].
Per ECMA-262 §24.1.1: null/undefined → empty map; other non-iterables throw TypeError;
non-array entries in the init array throw TypeError."""
def:pub js_Map(args: list[JSValue]) -> JSValue {
    m: JSValue = js_map_create();
    if len(args) > 0 {
        init: JSValue = args[0];
        # null / undefined → empty map (spec §24.1.1 step 3)
        if jsv_is_null(init) or jsv_is_undefined(init) {
            return m;
        }
        if js_is_map(init) {
            # Copy entries from another Map
            ent: JSValue = js_map_entries_array(init);
            n_ent: int = js_array_len(ent);
            ei: int = 0;
            while ei < n_ent {
                ep: JSValue = js_array_get(ent, ei);
                if js_is_array(ep) {
                    k_cp: JSValue = js_array_get(ep, 0);
                    v_cp: JSValue = js_array_get(ep, 1);
                    js_map_set(m, k_cp, v_cp);
                }
                ei = ei + 1;
            }
            return m;
        }
        if not js_is_array(init) {
            vm_throw_native(
                make_type_error(
                    "object is not iterable (cannot read property Symbol(Symbol.iterator))"
                )
            );
            return js_undefined();
        }
        # Array of entries (fallback — VM CALL_NEW uses GetIterator).
        # ES §24.1.1.1 AddEntriesFromIterable: each entry must be an Object, then
        # k = Get(entry,"0"), v = Get(entry,"1"). A non-array object entry (e.g.
        # `{foo:'bar'}`) is valid — it yields k=v=undefined — so accept any object,
        # not just arrays (class M extends Map {}; new M([{foo:'bar'}])).
        n_pairs: int = js_array_len(init);
        pi: int = 0;
        while pi < n_pairs {
            pair: JSValue = js_array_get(init, pi);
            if not jsv_is_object_cell(pair) {
                vm_throw_native(
                    make_type_error("Iterator value is not an entry object")
                );
                return js_undefined();
            }
            k_i: JSValue;
            v_i: JSValue;
            if js_is_array(pair) {
                k_i = js_array_get(pair, 0);
                v_i = js_undefined();
                if js_array_len(pair) >= 2 {
                    v_i = js_array_get(pair, 1);
                }
            } else {
                k_i = js_object_get(pair, str_intern("0"));
                v_i = js_object_get(pair, str_intern("1"));
            }
            js_map_set(m, k_i, v_i);
            pi = pi + 1;
        }
    }
    return m;
}

"""WeakMap constructor fallback (VM CALL_NEW handles full iterable + IteratorClose).
null/undefined → empty; arrays of pairs consumed; other non-iterables → TypeError."""
def:pub js_WeakMap(args: list[JSValue]) -> JSValue {
    wm: JSValue = js_weakmap_create();
    if len(args) > 0 {
        init: JSValue = args[0];
        if jsv_is_null(init) or jsv_is_undefined(init) {
            return wm;
        }
        if js_is_array(init) {
            n_wm: int = js_array_len(init);
            wi: int = 0;
            while wi < n_wm {
                wm_pair: JSValue = js_array_get(init, wi);
                if not js_is_array(wm_pair) {
                    vm_throw_native(
                        make_type_error("Iterator value is not an entry object")
                    );
                    return js_undefined();
                }
                wm_key: JSValue = js_array_get(wm_pair, 0);
                if not _can_be_held_weakly(wm_key) {
                    vm_throw_native(
                        make_type_error("Invalid value used as weak map key")
                    );
                    return js_undefined();
                }
                wm_val: JSValue = js_undefined();
                if js_array_len(wm_pair) >= 2 {
                    wm_val = js_array_get(wm_pair, 1);
                }
                js_weakmap_set(wm, wm_key, wm_val);
                wi = wi + 1;
            }
            return wm;
        }
        vm_throw_native(
            make_type_error(
                "object is not iterable (cannot read property Symbol(Symbol.iterator))"
            )
        );
        return js_undefined();
    }
    return wm;
}
