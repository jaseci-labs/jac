"""
JSObject: property map, prototype chain, and core object operations.

Every JavaScript object has:
  - A flat property map (key id → JSProperty)
  - A prototype pointer (index into the global object table, or -1 for null)
  - A class id (0 = plain object, other ids reserved for Array, Function, etc.)
  - An extensible flag (Object.preventExtensions)

Property keys are opaque integer IDs.  's string interning table will
assign these IDs;  uses pre-defined constants for well-known keys and
small literal integers for tests.

ECMAScript spec refs:
  §6.1.7   The Object Type
  §10.1    Ordinary Object Internal Methods
  §10.1.1  [[GetPrototypeOf]]
  §10.1.8  [[Get]]  / §10.1.9  [[Set]]  / §10.1.10 [[Delete]]
"""

import from engine.src.runtime.jsvalue {
    JSValue,
    jsv_is_object_cell,
    jsv_is_undefined,
    jsv_is_double,
    jsv_is_int32,
    jsv_from_object_id,
    jsv_from_int32,
    jsv_to_table_id,
    jsv_to_double,
    jsv_to_int32,
    js_undefined,
    js_null,
    js_strict_equal,
    __float_bits,
    js_int,
    jsv_hole,
    jsv_is_hole,
    jsv_is_cell
}
import from engine.src.runtime.jsobj_type {
    proto_epoch_bump,
    global_obj_note_write,
    JSProperty,
    JSObject,
    ProxyState,
    ArgsState,
    AccessorTable,
    PROP_WRITABLE,
    PROP_ENUMERABLE,
    PROP_CONFIGURABLE,
    PROP_DEFAULT,
    PROP_READONLY,
    MAP_MODE_DICT,
    MAP_MODE_SHAPE,
    ELEMS_NONE,
    ELEMS_DENSE,
    ELEMS_HOLEY,
    DENSE_GAP_MAX,
    idx_protector_clear,
    idx_protector_ok,
    BRAND_STRING_OBJ,
    BRAND_ARRAY,
    BRAND_ENV_OBJ
}
import from engine.src.runtime.jscell {
    FLAG_IS_PROTO,
    FLAG_MODULE_NS,
    FLAG_MAPPED_ARGS,
    FLAG_IS_CLASS,
    FLAG_IS_ARGUMENTS,
    FLAG_FROZEN,
    FLAG_SEALED,
    FLAG_NON_EXTENSIBLE,
    FLAG_IS_GLOBAL
}
import from engine.src.runtime.shape {
    shape_gate_enabled,
    shape_lookup,
    shape_keys,
    shape_transition_add,
    shape_change_attrs,
    SHAPE_ATTR_ACCESSOR
}
import from engine.src.runtime.realm { Realm, gc_note_alloc }
import from engine.src.ffi.libc { getenv, write }
import from engine.src.runtime.encoding {
    PROTO_MAX_DEPTH,
    SYMBOL_KEY_BASE,
    BUILTIN_BASE
}
import from engine.src.runtime.jsstring {
    str_intern_index,
    str_from_id,
    str_intern,
    str_intern_lookup,
    str_substr,
    str_id_is_array_index,
    str_id_is_brand_key
}
import from engine.src.runtime.gc_pin { gc_pin_value }

# ═══════════════════════════════════════════════════════════════════════════════
# Well-known property key constants
# ═══════════════════════════════════════════════════════════════════════════════
#
#  (string interning) will assign IDs dynamically.  For  we
# pre-define constants for the keys used in smoke tests and well-known slots.
# User-defined keys in tests start at KEY_BASE (10) to avoid collisions.

glob _OBJDBG: int = -1,
     KEY_PROTO: int = 1,
     KEY_CONSTRUCTOR: int = 2,
     KEY_LENGTH: int = 3,
     KEY_NAME: int = 4,
     KEY_VALUE: int = 5;  # JAC_DBG_OBJ object-table growth probe (-1 unknown/0 off/1 on)

# "__proto__"
# "constructor"
# "length"
# "name"
# "value" (descriptor field)
glob:pub KEY_CTOR_KIND: int = 1000023;  # internal: NATIVE_KIND on callable objects (not 6 — collides with str_intern(""))
glob KEY_BASE: int = 10,
     _OBJ_REALM: Realm;  # first key available for tests / user code


# Symbol-keyed property namespace.
# Symbol JSValues use as_ptr = symbol_id (0-based index into _SYMBOL_TABLE).
# To store symbol-keyed properties in a plain JSObject without colliding with
# string-interned key IDs (which start at 0 and grow upward), we encode a
# symbol property key as:  SYMBOL_KEY_BASE + symbol_id
# 10_000_000 gives ample headroom for any number of interned strings.
# Canonical value in runtime/encoding.na.jac (imported above).

# ═══════════════════════════════════════════════════════════════════════════════
# Object table bridge
# ═══════════════════════════════════════════════════════════════════════════════
#
# JSObjects are stored in realm.objects; set via obj_set_realm().
# Index 0 is reserved (null sentinel).
def:pub obj_set_realm(r: Realm) {
    _OBJ_REALM = r;
}


# ═══════════════════════════════════════════════════════════════════════════════
# Internal helpers
# ═══════════════════════════════════════════════════════════════════════════════

"""Allocate a JSObject in the global table; return its 1-based index."""
def _obj_alloc(prototype_idx: int) -> int {
    gc_note_alloc(_OBJ_REALM);  # G0.4: account this object allocation (reuse or append path)
    # Mark the prototype as such — gates the dense-elements index protector:
    # an index-keyed prop landing on any flagged object clears the protector.
    # First time only (flag not yet set): also scan for index props it may
    # have acquired BEFORE becoming a prototype. Amortized once per object.
    if prototype_idx > 0 and prototype_idx <= len(_OBJ_REALM.objects) {
        pa_raw: JSObject = _OBJ_REALM.objects[prototype_idx - 1];
        if (pa_raw.cell_flags & FLAG_IS_PROTO) == 0 {
            pa_raw.cell_flags = pa_raw.cell_flags | FLAG_IS_PROTO;
            if idx_protector_ok() {
                # A Proxy prototype traps EVERY inherited [[Set]]/[[Get]] —
                # no index-key scan can prove it inert.
                if pa_raw.class_id != 0 {
                    idx_protector_clear();
                } elif pa_raw.elems_kind != ELEMS_NONE and len(pa_raw.elems_ro()) > 0 {
                    idx_protector_clear();
                } else {
                    for pa_k in pa_raw.all_keys() {
                        if _obj_is_array_index_key_id(pa_k) {
                            idx_protector_clear();
                            break;
                        }
                    }
                }
            }
        }
    }
    # A2.4: reuse a tombstoned slot from the GC free-list if available.
    if len(_OBJ_REALM.free_object_slots) > 0 {
        last: int = len(_OBJ_REALM.free_object_slots) - 1;
        idx: int = _OBJ_REALM.free_object_slots[last];
        del _OBJ_REALM.free_object_slots[last];
        # RE-INITIALISE IN PLACE — do NOT `objects[idx-1] = JSObject(...)`.
        # Overwriting the list element drops the tombstoned instance, but the
        # native list-element store does not recursively release the dropped
        # archetype's container fields (properties map + accessor/elems lists).
        # So every reuse leaked the swept object's containers: ~2.4GB across a
        # vite build's ~4.7M reuses, OOMing under --gc. A field store DOES
        # release its old value, so we mutate the existing instance instead.
        #
        # gc_sweep_objects is the ONLY producer of free_object_slots, and it
        # already emptied properties.{entries,key_order,slots}, elems and nulled
        # the accessors table before parking the slot — so those stay untouched
        # here (re-emptying would just churn empty containers). Every OTHER field
        # is reset to its fresh-JSObject default (gc_sweep does not touch them).
        ro: JSObject = _OBJ_REALM.objects[idx - 1];
        ro.prototype_idx = prototype_idx;
        ro.version = 0;
        ro.shape_id = 0;
        ro.mode = MAP_MODE_SHAPE if shape_gate_enabled() else MAP_MODE_DICT;
        ro.class_id = 0;
        # extensible/is_mapped_args/is_arguments are cell_flags bits now (P5);
        # the `ro.cell_flags = 0` below resets all three to their defaults.
        # Proxy/args state lives in realm side-tables (Phase 1); gc_sweep_objects
        # dels the rows when the slot is reclaimed, but drop them defensively here
        # too so a reused slot can never inherit a prior object's exotic state.
        if idx in _OBJ_REALM.proxy_slots {
            del _OBJ_REALM.proxy_slots[idx];
        }
        if idx in _OBJ_REALM.args_slots {
            del _OBJ_REALM.args_slots[idx];
        }
        # Release the lazy containers (P2/P3b/P4); sweep already nulled them, but
        # drop defensively so a reused slot can never inherit stale property state.
        ro.accessors = None;
        ro.entries = None;
        ro.key_order = None;
        ro.elems = None;
        ro.binary_kind = 0;
        ro.binary_slot = -1;
        ro.cell_kind = 1;
        ro.cell_flags = 0;  # clears FLAG_MODULE_NS (former is_module_namespace) too
        ro.structure_id = 0;
        ro.brand = 0;
        _OBJ_REALM.objects_mark_epoch[idx - 1] = 0;
        return idx;
    }
    idx: int = len(_OBJ_REALM.objects) + 1;  # reserve 0 as null sentinel
    if _OBJDBG != 0 {
        if _OBJDBG < 0 {
            if getenv("JAC_DBG_OBJ") != None {
                _OBJDBG = 1;
            } else {
                _OBJDBG = 0;
            }
        }
        if _OBJDBG == 1 and (idx % 500000) == 0 {
            odm: str = "[OBJTBL] table="
                + str(idx)
                + " freelist="
                + str(len(_OBJ_REALM.free_object_slots))
                + " live="
                + str(idx - len(_OBJ_REALM.free_object_slots))
                + " gc_on="
                + str(_OBJ_REALM.gc_enabled)
                + "\n";
            write(2, odm, len(odm));
        }
    }
    _OBJ_REALM.objects.append(
        JSObject(
            prototype_idx=prototype_idx,
            version=0,
            shape_id=0,
            slots=[],
            mode=(MAP_MODE_SHAPE if shape_gate_enabled() else MAP_MODE_DICT),
            class_id=0,
            elems_kind=0
        )
    );
    _OBJ_REALM.objects_mark_epoch.append(0);  # A2.2 GC mark bitmap
    return idx;
}

"""A fresh ordinary object with [[Prototype]] table id `proto_idx` (-1 =
null) that is already at shape `sid` with `v0`, `v1` in its two slots —
what two property adds from the empty root shape build, without the two
transitions. `sid` must be a two-property shape learned from an object
built the ordinary way (so its keys, order and attributes are known)."""
def:pub js_object_new_shaped2(
    proto_idx: int, sid: int, v0: JSValue, v1: JSValue
) -> JSValue {
    sh2_idx: int = _obj_alloc(proto_idx);
    _OBJ_REALM.objects[sh2_idx - 1].shape_id = sid;
    _OBJ_REALM.objects[sh2_idx - 1].slots.append(v0);
    _OBJ_REALM.objects[sh2_idx - 1].slots.append(v1);
    _OBJ_REALM.objects[sh2_idx - 1].version = 2;
    return _obj_wrap(sh2_idx);
}

"""Retrieve a JSObject from the global table by index (for Proxy / internal use)."""
def:pub js_object_table_get(idx: int) -> JSObject {
    return _obj_get(idx);
}

# Scalar reads of one object's fields for the VM's hottest paths. They go
# through the table row as a borrowed list element, so unlike
# js_object_table_get / _obj_get (which return an owned JSObject reference:
# a retain plus the caller's release, ~35 instructions per call before any
# work) they take no reference at all. `id` is the 1-based table id (> 0).

"""binary_kind of the object with table id `id`."""
def:pub js_object_binary_kind_id(id: int) -> int {
    return _OBJ_REALM.objects[id - 1].binary_kind;
}

"""Element `i` of `v`'s dense elements when it is there (an own data element:
[[Get]] returns it with nothing observable), else the hole — the caller then
takes the full property path."""
def:pub js_object_dense_elem(v: JSValue, i: int) -> JSValue {
    if i < 0 or not jsv_is_object_cell(v) {
        return jsv_hole();
    }
    de_id: int = jsv_to_table_id(v);
    if de_id <= 0 or _OBJ_REALM.objects[de_id - 1].elems_kind == ELEMS_NONE {
        return jsv_hole();
    }
    # One table access, no object reference taken.
    return _OBJ_REALM.objects[de_id - 1].elem_or_hole(i);
}

"""[[Set]] of element `i` of `v` when it is a PRESENT dense element of a
non-prototype object — an own writable data property (dense storage holds
default-attribute data elements only): stores `val`, True. False (nothing
done) otherwise (V4.21)."""
def:pub js_object_dense_set_present(v: JSValue, i: int, val: JSValue) -> bool {
    if i < 0 or not jsv_is_object_cell(v) {
        return False;
    }
    dp_id: int = jsv_to_table_id(v);
    if dp_id <= 0 or _OBJ_REALM.objects[dp_id - 1].elems_kind == ELEMS_NONE {
        return False;
    }
    if (_OBJ_REALM.objects[dp_id - 1].cell_flags & FLAG_IS_PROTO) != 0 {
        return False;
    }
    if jsv_is_hole(_OBJ_REALM.objects[dp_id - 1].elem_or_hole(i)) {
        return False;
    }
    _OBJ_REALM.objects[dp_id - 1].elems_rw()[i] = val;
    return True;
}

"""The property IC's hit test and read in one table access: slots[si] of
`v` when it is an ordinary shape-mode object of shape `sid`, else the hole
(what js_object_ic_shape(v) == sid followed by js_object_slot_at_id gives)."""
def:pub js_object_ic_hit(v: JSValue, sid: int, si: int) -> JSValue {
    if not jsv_is_object_cell(v) {
        return jsv_hole();
    }
    ih_id: int = jsv_to_table_id(v);
    if ih_id <= 0 {
        return jsv_hole();
    }
    return _OBJ_REALM.objects[ih_id - 1].ic_slot(sid, si);
}

"""The SET IC's hit test and write in one table access (see js_object_ic_hit)."""
def:pub js_object_ic_set_hit(v: JSValue, sid: int, si: int, val: JSValue) -> bool {
    if not jsv_is_object_cell(v) {
        return False;
    }
    is_id: int = jsv_to_table_id(v);
    if is_id <= 0 {
        return False;
    }
    return _OBJ_REALM.objects[is_id - 1].ic_slot_set(sid, si, val);
}

"""[[Prototype]] table id of the object with table id `id` (0 = null)."""
def:pub js_object_proto_idx_id(id: int) -> int {
    return _OBJ_REALM.objects[id - 1].prototype_idx;
}

"""CreateDataProperty(`v`, i, val) for a plain extensible Array with dense
elements, in place: overwrite element i (a present element or a hole — dense
storage only holds default-attribute data elements), or append at
i == len(elems) — below the stored length (the ArraySpeciesCreate(O, n)
result of map: empty elements, length n) with no length change, or at/past it
(filter's length-0 result) growing a writable length to i + 1. False (nothing
written) for anything else — the caller takes the full definition path."""
def:pub js_object_dense_put(v: JSValue, i: int, val: JSValue) -> bool {
    if i < 0 or not jsv_is_object_cell(v) {
        return False;
    }
    dp_id: int = jsv_to_table_id(v);
    if dp_id <= 0 {
        return False;
    }
    dp_raw: JSObject = _obj_get(dp_id);
    if dp_raw.class_id != 0
        or dp_raw.elems_kind == ELEMS_NONE
        or (dp_raw.brand & BRAND_ARRAY) == 0 {
        return False;
    }
    if (dp_raw.cell_flags & (FLAG_FROZEN | FLAG_SEALED | FLAG_NON_EXTENSIBLE)) != 0 {
        return False;
    }
    dp_n: int = len(dp_raw.elems_ro());
    if i < dp_n {
        dp_raw.elems_rw()[i] = val;
        return True;
    }
    if i == dp_n and dp_raw.mode == MAP_MODE_SHAPE {
        dp_lk: int = shape_lookup(dp_raw.shape_id, KEY_LENGTH);
        if dp_lk >= 0 and (dp_lk & SHAPE_ATTR_ACCESSOR) == 0 {
            dp_len: JSValue = dp_raw.slots[dp_lk // 16];
            if jsv_is_int32(dp_len) and i < jsv_to_int32(dp_len) {
                dp_raw.elems_rw().append(val);
                return True;
            }
            # At or past the length (filter's result starts at length 0):
            # ArrayDefineOwnProperty grows `length` to i + 1 — allowed only
            # while `length` is writable.
            if jsv_is_int32(dp_len)
                and i >= jsv_to_int32(dp_len)
                and (dp_lk & PROP_WRITABLE) != 0
                and i < 2147483647 {
                dp_raw.elems_rw().append(val);
                dp_raw.slots[dp_lk // 16] = js_int(i + 1);
                return True;
            }
        }
    }
    return False;
}

"""True for an ordinary object cell: no class (Proxy, String / Date …
wrappers), binary payload, module namespace or arguments exotic — whose
own-property attributes all live in its shape / property map / elements."""
def:pub js_object_is_plain_ordinary(v: JSValue) -> bool {
    if not jsv_is_object_cell(v) {
        return False;
    }
    po_id: int = jsv_to_table_id(v);
    if po_id <= 0 {
        return False;
    }
    return _OBJ_REALM.objects[po_id - 1].class_id == 0
        and _OBJ_REALM.objects[po_id - 1].binary_kind == 0
        and (
            _OBJ_REALM.objects[po_id - 1].cell_flags
            & (FLAG_MODULE_NS | FLAG_IS_ARGUMENTS)
        )
            == 0;
}

"""cell_flags of the object with table id `id`."""
def:pub js_object_cell_flags_id(id: int) -> int {
    return _OBJ_REALM.objects[id - 1].cell_flags;
}

"""class_id of the object with table id `id`."""
def:pub js_object_class_id_id(id: int) -> int {
    return _OBJ_REALM.objects[id - 1].class_id;
}

"""elems_kind of the object with table id `id`."""
def:pub js_object_elems_kind_id(id: int) -> int {
    return _OBJ_REALM.objects[id - 1].elems_kind;
}

"""binary_slot of the object with table id `id`."""
def:pub js_object_binary_slot_id(id: int) -> int {
    return _OBJ_REALM.objects[id - 1].binary_slot;
}

"""Flag `v` as the realm's global object (FLAG_IS_GLOBAL): its writes are
recorded for the VM's bare-name global reads and it stays off the shape ICs."""
def:pub js_object_mark_global(v: JSValue) -> None {
    if not jsv_is_object_cell(v) {
        return;
    }
    mg_id: int = jsv_to_table_id(v);
    if mg_id <= 0 {
        return;
    }
    mg_raw: JSObject = _obj_get(mg_id);
    if (mg_raw.cell_flags & FLAG_IS_GLOBAL) == 0 {
        mg_raw.cell_flags = mg_raw.cell_flags | FLAG_IS_GLOBAL;
    }
}

"""Shape id the property ICs key on: the shape_id of an ordinary
(class_id 0), non-namespace, shape-mode object, else -1."""
def:pub js_object_ic_shape(v: JSValue) -> int {
    if not jsv_is_object_cell(v) {
        return -1;
    }
    is_id: int = jsv_to_table_id(v);
    if is_id <= 0 {
        return -1;
    }
    if _OBJ_REALM.objects[is_id - 1].class_id != 0 {
        return -1;
    }
    if (_OBJ_REALM.objects[is_id - 1].cell_flags & FLAG_MODULE_NS) != 0 {
        return -1;
    }
    # The global object stays off the ICs: an IC-hit write would store the slot
    # directly and skip global_obj_note_write (bare global reads would miss it).
    if (_OBJ_REALM.objects[is_id - 1].cell_flags & FLAG_IS_GLOBAL) != 0 {
        return -1;
    }
    if _OBJ_REALM.objects[is_id - 1].mode != MAP_MODE_SHAPE {
        return -1;
    }
    return _OBJ_REALM.objects[is_id - 1].shape_id;
}

"""slots[si] of the object with table id `id` (an IC hit: the caller has
matched the shape, so the slot exists)."""
def:pub js_object_slot_at_id(id: int, si: int) -> JSValue {
    return _OBJ_REALM.objects[id - 1].slots[si];
}

"""Table slot index of `v`'s own data property `key` when `v` is an ordinary
shape-mode object that has it (see js_object_ic_shape), else -1. Used once
to learn the layout of closure cells (vm/cell.jac)."""
def:pub js_object_own_data_slot(v: JSValue, key: int) -> int {
    if js_object_ic_shape(v) < 0 {
        return -1;
    }
    ds_p: int = shape_lookup(_OBJ_REALM.objects[jsv_to_table_id(v) - 1].shape_id, key);
    if ds_p < 0 or (ds_p & SHAPE_ATTR_ACCESSOR) != 0 {
        return -1;
    }
    return ds_p // 16;
}

"""Write slots[si] of `v` when it is an ordinary, shape-mode object of shape
`sid` that is not frozen/sealed/non-extensible (so the shape's writable data
property at `si` takes a plain [[Set]]); False (nothing written) otherwise."""
def:pub js_object_shape_slot_set(v: JSValue, sid: int, si: int, val: JSValue) -> bool {
    if js_object_ic_shape(v) != sid {
        return False;
    }
    sw_id: int = jsv_to_table_id(v);
    if (
        _OBJ_REALM.objects[sw_id - 1].cell_flags
        & (FLAG_FROZEN | FLAG_SEALED | FLAG_NON_EXTENSIBLE)
    )
        != 0 {
        return False;
    }
    _OBJ_REALM.objects[sw_id - 1].slots[si] = val;
    return True;
}

"""slots[si] = val on the object with table id `id` (a SET IC hit: the
caller has matched the shape, which guarantees a writable data slot)."""
def:pub js_object_slot_set_at_id(id: int, si: int, val: JSValue) {
    _OBJ_REALM.objects[id - 1].slots[si] = val;
}

"""Inherited-data IC guard on the receiver (table id `id`): its
[[Prototype]] is still `proto_idx`, it is not a binary view, and it is
neither an arguments object nor a class."""
def:pub js_object_proto_ic_ok(id: int, proto_idx: int) -> bool {
    return _OBJ_REALM.objects[id - 1].prototype_idx == proto_idx
        and _OBJ_REALM.objects[id - 1].binary_kind == 0
        and (
            _OBJ_REALM.objects[id - 1].cell_flags & (FLAG_IS_ARGUMENTS | FLAG_IS_CLASS)
        )
            == 0;
}

"""BRAND_* bits of `v` (jsobj_type.brand_bit_for_key), 0 for a non-object.
The builtin type predicates (js_is_map, js_is_generator, …) test these instead
of probing their marker key with js_object_has_own."""
def:pub js_object_brand(v: JSValue) -> int {
    if not jsv_is_object_cell(v) {
        return 0;
    }
    ob_id: int = jsv_to_table_id(v);
    if ob_id <= 0 {
        return 0;
    }
    return _OBJ_REALM.objects[ob_id - 1].brand;
}

"""Retrieve a JSObject from the global table by index."""
def _obj_get(idx: int) -> JSObject {
    # _OBJ_REALM.objects is 0-based but we allocate starting at index 1;
    # adjust: real index in list = idx - 1
    return _OBJ_REALM.objects[idx - 1];
}

# Mapped-arguments aliasing storage lives in realm.args_slots[idx], not on the
# JSObject (docs/OBJECT_FOOTPRINT_PLAN.md Phase 1). A row exists iff the object's
# is_mapped_args flag is set, so every caller guards on that first.
def _args_row(idx: int) -> ArgsState {
    return _OBJ_REALM.args_slots[idx];
}

# ── Lazy accessor tables (docs/OBJECT_FOOTPRINT_PLAN.md P2) ────────────────────
# JSObject.accessors is None until the first accessor is installed, so ordinary
# objects carry no getter/setter dicts. Shared read-only empty table for the None
# case — NEVER mutate it; every write path must go through _acc_rw.
glob _ACC_EMPTY: AccessorTable = AccessorTable();

"""Accessor table for READ access: the object's own table, or the shared empty one
when it has no accessors. Result must not be mutated (see _acc_rw for writes)."""
def _acc_ro(raw: JSObject) -> AccessorTable {
    if raw.accessors is not None {
        return raw.accessors;
    }
    return _ACC_EMPTY;
}

"""Accessor table for WRITE access, materializing it (and the owning edge) on the
object's first accessor install."""
def _acc_rw(raw: JSObject) -> AccessorTable {
    if raw.accessors is not None {
        return raw.accessors;
    }
    t: AccessorTable = AccessorTable(
        getters={}, setters={}, enumerable={}, configurable={}
    );
    raw.accessors = t;
    return t;
}

"""Wrap an object table index as a JSValue with tag=Object."""
def _obj_wrap(idx: int) -> JSValue {
    return jsv_from_object_id(idx);
}

"""Allocate a new object table slot; returns 1-based index (for Proxy construction)."""
def:pub js_object_alloc_slot(proto_idx: int) -> int {
    return _obj_alloc(proto_idx);
}

"""Wrap a 1-based object table index as JSObject JSValue."""
def:pub js_object_wrap_slot(idx: int) -> JSValue {
    return _obj_wrap(idx);
}


# ═══════════════════════════════════════════════════════════════════════════════
# Public API — object creation
# ═══════════════════════════════════════════════════════════════════════════════

"""
Create an empty object with `proto` as its prototype.
ECMAScript: OrdinaryObjectCreate(proto).
"""
def:pub js_object_create(proto: JSValue) -> JSValue {
    proto_idx: int = -1;
    if jsv_is_object_cell(proto) {
        proto_idx = jsv_to_table_id(proto);
    }
    idx: int = _obj_alloc(proto_idx);
    return _obj_wrap(idx);
}

"""
Create an empty object with a null prototype (Object.create(null)).
ECMAScript: OrdinaryObjectCreate(null).
"""
def:pub js_object_create_null -> JSValue {
    idx: int = _obj_alloc(-1);
    return _obj_wrap(idx);
}

"""Default [[Prototype]] for `{}` literals and `new Object()` (set from init_global)."""
glob _ORDINARY_OBJECT_PROTO: JSValue;

def:pub js_object_set_ordinary_proto(p: JSValue) {
    _ORDINARY_OBJECT_PROTO = p;
    gc_pin_value(p);  # glob-held singleton — invisible to the GC root walk
}

"""Return the default [[Prototype]] for ordinary objects (Object.prototype)."""
def:pub js_object_get_ordinary_proto -> JSValue {
    return _ORDINARY_OBJECT_PROTO;
}

"""Default [[Prototype]] for function objects (set from init_global)."""
glob _FUNCTION_PROTO: JSValue;

def:pub js_function_set_proto(p: JSValue) {
    _FUNCTION_PROTO = p;
    gc_pin_value(p);  # glob-held singleton — invisible to the GC root walk
}

"""Return Function.prototype for getPrototypeOf on function values."""
def:pub js_function_get_proto -> JSValue {
    return _FUNCTION_PROTO;
}

# ── Generator intrinsics (ES §27.3 / §27.5), set from init_global ──────────────
# %Generator%          = GeneratorFunction.prototype — [[Prototype]] of every
#                        generator function; its own [[Prototype]] is Function.prototype.
# %GeneratorPrototype% = Generator.prototype — [[Prototype]] of each generator
#                        function's `.prototype` object, and the fallback
#                        [[Prototype]] of a generator instance when `g.prototype`
#                        is not an object.
glob _GENERATOR_INTRINSIC: JSValue,
     _GENERATOR_PROTO: JSValue,
     _ASYNC_GENERATOR_INTRINSIC: JSValue,
     _ASYNC_GENERATOR_PROTO: JSValue,
     _NATIVE_ITER_PROTO: JSValue,
     _NATIVE_ASYNC_ITER_PROTO: JSValue;

# The native %Iterator.prototype% objects that %GeneratorPrototype% /
# %AsyncGeneratorPrototype% inherit from. Bootstrap creates them before the JS
# `Iterator.prototype` stub (which holds the iterator-helper methods map/filter/
# take/…) exists, so their [[Prototype]] is re-parented to the stub prototype
# once it is installed (see js_iterator_reparent_native_protos).
def:pub js_iterator_set_native_protos(iter_proto: JSValue, async_iter_proto: JSValue) {
    _NATIVE_ITER_PROTO = iter_proto;
    _NATIVE_ASYNC_ITER_PROTO = async_iter_proto;
    gc_pin_value(iter_proto);  # glob-held singleton — invisible to the GC root walk
    gc_pin_value(async_iter_proto);  # glob-held singleton — invisible to the GC root walk
}

"""Re-parent the native %Iterator.prototype% (and async variant) onto the JS
`Iterator.prototype` stub so generator instances inherit the iterator-helper
methods (map/filter/take/drop/…) through their %GeneratorPrototype% chain."""
def:pub js_iterator_reparent_native_protos(helper_proto: JSValue) -> None {
    if not (jsv_is_object_cell(helper_proto) and jsv_to_table_id(helper_proto) > 0) {
        return;
    }
    if jsv_is_object_cell(_NATIVE_ITER_PROTO)
        and jsv_to_table_id(_NATIVE_ITER_PROTO) > 0 {
        js_object_set_prototype(_NATIVE_ITER_PROTO, helper_proto);
    }
    if jsv_is_object_cell(_NATIVE_ASYNC_ITER_PROTO)
        and jsv_to_table_id(_NATIVE_ASYNC_ITER_PROTO) > 0 {
        js_object_set_prototype(_NATIVE_ASYNC_ITER_PROTO, helper_proto);
    }
}

def:pub js_generator_set_intrinsics(
    gen_fn: JSValue, gen_proto: JSValue, async_gen_fn: JSValue, async_gen_proto: JSValue
) {
    _GENERATOR_INTRINSIC = gen_fn;
    _GENERATOR_PROTO = gen_proto;
    _ASYNC_GENERATOR_INTRINSIC = async_gen_fn;
    _ASYNC_GENERATOR_PROTO = async_gen_proto;
    gc_pin_value(gen_fn);  # glob-held singleton — invisible to the GC root walk
    gc_pin_value(gen_proto);
    gc_pin_value(async_gen_fn);
    gc_pin_value(async_gen_proto);
}

"""%Generator% (GeneratorFunction.prototype) — [[Prototype]] of generator functions."""
def:pub js_generator_get_intrinsic -> JSValue {
    return _GENERATOR_INTRINSIC;
}

"""%GeneratorPrototype% (Generator.prototype)."""
def:pub js_generator_get_proto -> JSValue {
    return _GENERATOR_PROTO;
}

def:pub js_async_generator_get_intrinsic -> JSValue {
    return _ASYNC_GENERATOR_INTRINSIC;
}

def:pub js_async_generator_get_proto -> JSValue {
    return _ASYNC_GENERATOR_PROTO;
}

"""Define a non-enumerable data property (writable, configurable) — prototype methods / constructor."""
def:pub js_object_define_nonenum(jsobj: JSValue, key: int, val: JSValue) {
    p: JSProperty = JSProperty(
        key=key,
        value=val,
        writable=True,
        enumerable=False,
        configurable=True,
        deleted=False
    );
    js_object_define_property(jsobj, key, p);
}

"""Create an ordinary object with the default Object.prototype (or null if unset)."""
def:pub js_object_new_ordinary -> JSValue {
    if jsv_is_object_cell(_ORDINARY_OBJECT_PROTO)
        and jsv_to_table_id(_ORDINARY_OBJECT_PROTO) > 0 {
        return js_object_create(_ORDINARY_OBJECT_PROTO);
    }
    return js_object_create_null();
}


# ═══════════════════════════════════════════════════════════════════════════════
# Public API — [[Get]] / [[Set]] / [[Delete]]
# ═══════════════════════════════════════════════════════════════════════════════

"""
[[Get]](obj, key) — walk the prototype chain up to MAX_DEPTH hops.
Returns undefined if not found anywhere in the chain.
ECMAScript §10.1.8.
"""
def:pub js_object_get(jsobj: JSValue, key: int) -> JSValue {
    if not jsv_is_object_cell(jsobj) {
        return js_undefined();
    }
    current_idx: int = jsv_to_table_id(jsobj);
    # Guard: as_ptr <= 0 means this is a fn_val or native_val, not a
    # regular object-table entry.  Attempting _obj_get on such a value
    # would index out of bounds and crash.
    if current_idx <= 0 {
        return js_undefined();
    }
    # Depth limit of 1000 guards against prototype cycles.
    # Guard <= 0: -1 is the null-proto sentinel; any other non-positive value
    # (e.g. a fn_val as_ptr leaked via a buggy set_prototype call) must also
    # terminate the walk rather than being passed to _obj_get.
    for _depth in range(PROTO_MAX_DEPTH) {
        if current_idx <= 0 {
            return js_undefined();
        }
        current: JSObject = _obj_get(current_idx);
        # Dense elements: an in-range non-hole element is the own property.
        # Holes/out-of-range fall through (the map holds no index keys while
        # dense — invariant) and continue up the prototype chain.
        if current.elems_kind != ELEMS_NONE and _obj_is_array_index_key_id(key) {
            dgi: int = _obj_array_index_sort_key(key);
            if dgi < len(current.elems_ro()) {
                dgv: JSValue = current.elems_ro()[dgi];
                if not jsv_is_hole(dgv) {
                    return dgv;
                }
            }
        }
        # Non-materializing own-data read: get_property() allocates a fresh
        # JSProperty per hit in shape mode and the owned result local leaked on
        # this hot read path (see js_object_get_own_data_ic). has_own_data() +
        # get() are scalar and allocation-free.
        gt_own: JSValue = current.get_own_data_or_hole(key);
        if not jsv_is_hole(gt_own) {
            # Mapped arguments: an aliased index reads the live parameter slot.
            if current.mapped_args() {
                gt_ars: ArgsState = _args_row(current_idx);
                if key in gt_ars.slot_map {
                    ms: int = gt_ars.slot_map[key];
                    if ms >= 0 and ms < len(gt_ars.locals) {
                        return gt_ars.locals[ms];
                    }
                }
            }
            return gt_own;
        }
        current_idx = current.prototype_idx;
    }
    return js_undefined();
}

"""
[[Get]] over a prototype chain of ordinary objects, one own lookup per level.

Returns the value when an object on the chain has `key` as an own data
property, undefined when the chain ends without it, and the hole sentinel
(jsv_hole — never a property value) when some object on the chain needs exotic
or accessor handling the caller must do itself: a Proxy or other class_id
object, a binary view, a module namespace, mapped `arguments`, a String
wrapper, dense array elements, or an accessor for `key`. A non-hole answer
involved no getter, trap or side effect, so it equals the full ordinary [[Get]].
(A plain JSValue, not a tuple: tuple returns are heap-allocated per call.)
"""
def:pub js_object_get_ordinary(jsobj: JSValue, key: int) -> JSValue {
    go_idx: int = jsv_to_table_id(jsobj);
    for _go_depth in range(PROTO_MAX_DEPTH) {
        if go_idx <= 0 {
            return js_undefined();
        }
        go_raw: JSObject = _obj_get(go_idx);
        # A String wrapper is exotic only for `length` and integer-index keys
        # (ES §10.4.3); any other key — every String.prototype method name —
        # resolves like an ordinary object's.
        if go_raw.class_id != 0
            or go_raw.binary_kind != 0
            or go_raw.elems_kind != ELEMS_NONE
            or (go_raw.cell_flags & (FLAG_MODULE_NS | FLAG_MAPPED_ARGS)) != 0
            or (
                (go_raw.brand & BRAND_STRING_OBJ) != 0
                and (key == KEY_LENGTH or _obj_is_array_index_key_id(key))
            ) {
            return jsv_hole();
        }
        # Accessors first, as the full [[Get]] does: a key can be in both the
        # accessor tables and `entries`, and the accessor wins.
        if go_raw.accessors is not None and _go_acc_tables_have(go_raw, key) {
            return jsv_hole();
        }
        if go_raw.mode == MAP_MODE_SHAPE {
            go_packed: int = shape_lookup(go_raw.shape_id, key);
            if go_packed >= 0 {
                if (go_packed & SHAPE_ATTR_ACCESSOR) != 0 {
                    return jsv_hole();
                }
                return go_raw.slots[go_packed // 16];
            }
        } else {
            go_ent: dict[int, JSProperty] = go_raw.ent_ro();
            if key in go_ent {
                return go_ent[key].value;
            }
        }
        go_idx = go_raw.prototype_idx;
    }
    return jsv_hole();
}

"""True if `raw` takes plain own-data writes: an ordinary, extensible object
that is not an array, String wrapper, process.env, class, binary view, module
namespace, mapped `arguments` or dense-elements holder."""
def _go_write_plain(raw: JSObject) -> bool {
    return raw.class_id == 0
        and raw.binary_kind == 0
        and raw.elems_kind == ELEMS_NONE
        and (
            raw.cell_flags
            & (
                FLAG_MODULE_NS
                | FLAG_MAPPED_ARGS
                | FLAG_IS_CLASS
                | FLAG_NON_EXTENSIBLE
                | FLAG_FROZEN
                | FLAG_SEALED
                | FLAG_IS_GLOBAL
            )
        )
            == 0
        and (raw.brand & (BRAND_STRING_OBJ | BRAND_ARRAY | BRAND_ENV_OBJ)) == 0;
}

"""True if `key` is in `raw`'s accessor side tables (get/set/attribute maps —
an accessor whose get and set are both undefined shows only in the latter)."""
def _go_acc_tables_have(raw: JSObject, key: int) -> bool {
    ga_acc: AccessorTable = _acc_ro(raw);
    return key in ga_acc.getters
        or key in ga_acc.setters
        or key in ga_acc.configurable
        or key in ga_acc.enumerable;
}

"""True if `raw` has an accessor (getter and/or setter) own property `key`."""
def _go_has_accessor(raw: JSObject, key: int) -> bool {
    if raw.mode == MAP_MODE_SHAPE {
        ga_p: int = shape_lookup(raw.shape_id, key);
        if ga_p >= 0 and (ga_p & SHAPE_ATTR_ACCESSOR) != 0 {
            return True;
        }
    }
    if raw.accessors is not None {
        return _go_acc_tables_have(raw, key);
    }
    return False;
}

"""Add `key` as a new default data property (writable, enumerable,
configurable) on a plain object that does not have it yet — CreateDataProperty
for the object-literal / class-field case. False (nothing written) when the
object or key needs the full path: not _go_write_plain, key already own, or an
array-index key (those go to dict mode via js_object_set)."""
def:pub js_object_add_data_ordinary(jsobj: JSValue, key: int, val: JSValue) -> bool {
    ad_idx: int = jsv_to_table_id(jsobj);
    if ad_idx <= 0 {
        return False;
    }
    ad_raw: JSObject = _obj_get(ad_idx);
    if not _go_write_plain(ad_raw) {
        return False;
    }
    if ad_raw.has_key(key) or _go_has_accessor(ad_raw, key) {
        return False;
    }
    if _obj_is_array_index_key_id(key) {
        return False;
    }
    return ad_raw.set(key, val, PROP_DEFAULT) == 0;
}

"""
OrdinarySet(O, key, V, Receiver = O) for plain objects in one pass. Returns True
when the write is done: an existing writable own data property updated in
place, or — when no object on the prototype chain has an accessor or a
read-only data property for `key` — a new default data property added to O.
False (nothing written) for everything the caller must handle in full: setters,
read-only targets, Proxies / exotics on the chain, non-plain receivers and
array-index keys.
"""
def:pub js_object_set_ordinary(jsobj: JSValue, key: int, val: JSValue) -> bool {
    so_idx: int = jsv_to_table_id(jsobj);
    if so_idx <= 0 {
        return False;
    }
    so_raw: JSObject = _obj_get(so_idx);
    if not _go_write_plain(so_raw) {
        return False;
    }
    if _go_has_accessor(so_raw, key) {
        return False;
    }
    if so_raw.mode == MAP_MODE_SHAPE {
        so_p: int = shape_lookup(so_raw.shape_id, key);
        if so_p >= 0 {
            if (so_p & SHAPE_ATTR_ACCESSOR) != 0 or (so_p & PROP_WRITABLE) == 0 {
                return False;
            }
            so_raw.slots[so_p // 16] = val;
            return True;
        }
    } else {
        so_ent: dict[int, JSProperty] = so_raw.ent_ro();
        if key in so_ent {
            so_prop: JSProperty = so_ent[key];
            if not so_prop.writable {
                return False;
            }
            so_prop.value = val;
            return True;
        }
    }
    # Not own: an inherited setter, read-only data property or exotic object
    # decides the outcome — leave those to the full path.
    so_pidx: int = so_raw.prototype_idx;
    for _so_depth in range(PROTO_MAX_DEPTH) {
        if so_pidx <= 0 {
            break;
        }
        so_pr: JSObject = _obj_get(so_pidx);
        if so_pr.class_id != 0
            or so_pr.binary_kind != 0
            or so_pr.elems_kind != ELEMS_NONE
            or (so_pr.cell_flags & (FLAG_MODULE_NS | FLAG_MAPPED_ARGS)) != 0
            or (so_pr.brand & BRAND_STRING_OBJ) != 0 {
            return False;
        }
        if _go_has_accessor(so_pr, key) {
            return False;
        }
        if so_pr.mode == MAP_MODE_SHAPE {
            so_pp: int = shape_lookup(so_pr.shape_id, key);
            if so_pp >= 0 {
                if (so_pp & PROP_WRITABLE) == 0 {
                    return False;
                }
                break;
            }
        } else {
            so_pent: dict[int, JSProperty] = so_pr.ent_ro();
            if key in so_pent {
                if not so_pent[key].writable {
                    return False;
                }
                break;
            }
        }
        so_pidx = so_pr.prototype_idx;
    }
    if _obj_is_array_index_key_id(key) {
        return False;
    }
    return so_raw.set(key, val, PROP_DEFAULT) == 0;
}

"""`o.k += delta` for an own writable int32 data property of a plain object
(see _go_write_plain), in place: returns the OLD value, or the hole sentinel
(nothing written) when the full [[Get]]/[[Set]] path is needed — not plain,
dict mode, an accessor or read-only property, no own `k`, a non-int32 value,
or a result outside int32. A non-hole result means no getter, setter, trap or
valueOf could have run, so it equals GET + ToNumeric + add + [[Set]]."""
def:pub js_object_own_int_add(jsobj: JSValue, key: int, delta: int) -> JSValue {
    oi_idx: int = jsv_to_table_id(jsobj);
    if oi_idx <= 0 {
        return jsv_hole();
    }
    oi_raw: JSObject = _obj_get(oi_idx);
    if oi_raw.mode != MAP_MODE_SHAPE or not _go_write_plain(oi_raw) {
        return jsv_hole();
    }
    if oi_raw.accessors is not None and _go_acc_tables_have(oi_raw, key) {
        return jsv_hole();
    }
    oi_p: int = shape_lookup(oi_raw.shape_id, key);
    if oi_p < 0 or (oi_p & SHAPE_ATTR_ACCESSOR) != 0 or (oi_p & PROP_WRITABLE) == 0 {
        return jsv_hole();
    }
    oi_old: JSValue = oi_raw.slots[oi_p // 16];
    if not jsv_is_int32(oi_old) {
        return jsv_hole();
    }
    oi_new: int = jsv_to_int32(oi_old) + delta;
    if oi_new < -2147483648 or oi_new > 2147483647 {
        return jsv_hole();
    }
    oi_raw.slots[oi_p // 16] = js_int(oi_new);
    return oi_old;
}

"""Return the property-map generation counter for IC invalidation (Phase 4)."""
def:pub js_object_map_version(jsobj: JSValue) -> int {
    if not jsv_is_object_cell(jsobj) {
        return -1;
    }
    idx: int = jsv_to_table_id(jsobj);
    if idx <= 0 {
        return -1;
    }
    return _obj_get(idx).version;
}

# ── Object-footprint measurement (docs/OBJECT_FOOTPRINT_PLAN.md, Phase 0) ────
# One-shot structural inventory of the live object heap, printed at process exit
# when JAC_OBJ_STATS is set (see process.process_do_exit). `sub_allocs` is the
# reducible headline: today every live object carries a fixed set of
# sub-allocations (1 property map + entries + key_order + slots + 4 accessor
# dicts + args_locals + args_slot_map + elems = 12). Later phases move exotic
# state to sparse side-tables; when they land, update _OBJ_STATS_SUBS_PER_OBJ
# and the counts below so the number reflects the new structure and strictly
# decreases. The mp2 live-bytes profiler is the ground-truth byte cross-check.
glob _OBJ_STATS_SUBS_PER_OBJ: int = 1,
     _DEOPT_IDX: int = 0,
     _DEOPT_ACC: int = 0,
     _DEOPT_DBG: int = -1;  # P1 args off-object (12→10); P2 lazy AccessorTable (10→6); P3a inlined JSPropertyMap, dropped wrapper (6→5); P3b lazy dict-mode entries/key_order (5→2); P4 lazy elems (2→1) → base is now just the shape-mode `slots` list; arrays add elems (see elem_objs)

# TEMP diagnostic (JAC_DEOPT_STATS): count js_object_set write-funnel shape→dict
# deopts split by cause (index-key vs accessor), printed every 500k so the ratio
# is visible even if the run OOMs before clean exit. Remove once the deopt fix lands.
def:pub obj_stats_report {
    live: int = 0;
    dictm: int = 0;
    shapem: int = 0;
    sslots: int = 0;
    sentries: int = 0;
    sko: int = 0;
    acc_objs: int = 0;
    mapped: int = 0;
    arr_objs: int = 0;
    selems: int = 0;
    classful: int = 0;
    binaries: int = 0;
    modns: int = 0;
    ent_objs: int = 0;
    elem_objs: int = 0;
    i: int = 0;
    n: int = len(_OBJ_REALM.objects);
    while i < n {
        os_o: JSObject = _OBJ_REALM.objects[i];
        if os_o.cell_flags != CELL_FLAG_DEAD {
            live = live + 1;
            if os_o.mode == 0 {
                dictm = dictm + 1;
            } else {
                shapem = shapem + 1;
            }
            sslots = sslots + len(os_o.slots);
            sentries = sentries + len(os_o.ent_ro());
            sko = sko + len(os_o.ko_ro());
            if os_o.entries is not None {
                ent_objs = ent_objs + 1;
            }
            if len(_acc_ro(os_o).getters) > 0 or len(_acc_ro(os_o).setters) > 0 {
                acc_objs = acc_objs + 1;
            }
            if os_o.mapped_args() {
                mapped = mapped + 1;
            }
            if os_o.elems_kind != ELEMS_NONE {
                arr_objs = arr_objs + 1;
                selems = selems + len(os_o.elems_ro());
            }
            if os_o.elems is not None {
                elem_objs = elem_objs + 1;
            }
            if os_o.class_id != 0 {
                classful = classful + 1;
            }
            if os_o.binary_kind != 0 {
                binaries = binaries + 1;
            }
            if (os_o.cell_flags & FLAG_MODULE_NS) != 0 {
                modns = modns + 1;
            }
        }
        i = i + 1;
    }
    heap_live: int = len(_OBJ_REALM.heap_strings)
        - len(_OBJ_REALM.free_heap_string_slots);
    intern_n: int = len(_OBJ_REALM.intern_by_id);
    # Base per-object container (the shape-mode `slots` list, P4) + the 2-container
    # ArgsState row each mapped-args object carries (P1) + each accessor object's
    # lazy AccessorTable (1 struct + 4 dicts = 5, P2) + the 2 lazy dict-mode maps
    # (entries + key_order) per dict-key-holding object (P3b) + the lazy `elems`
    # list per densified array (P4).
    subs: int = live * _OBJ_STATS_SUBS_PER_OBJ
        + mapped * 2
        + acc_objs * 5
        + ent_objs * 2
        + elem_objs * 1;
    msg: str = "[OBJSTATS] live_objs="
        + str(live)
        + " (dict="
        + str(dictm)
        + " shape="
        + str(shapem)
        + ")"
        + " sub_allocs="
        + str(subs)
        + " | props: slots="
        + str(sslots)
        + " entries="
        + str(sentries)
        + " key_order="
        + str(sko)
        + " | accessor_objs="
        + str(acc_objs)
        + " dict_map_objs="
        + str(ent_objs)
        + " mapped_args="
        + str(mapped)
        + " | arrays="
        + str(arr_objs)
        + " elem_objs="
        + str(elem_objs)
        + " elems="
        + str(selems)
        + " | classful="
        + str(classful)
        + " binary="
        + str(binaries)
        + " module_ns="
        + str(modns)
        + " | heap_str_live="
        + str(heap_live)
        + " intern="
        + str(intern_n)
        + "\n";
    write(2, msg, len(msg));
}

"""Own-property data read without prototype walk (IC hit path).

Returns [found_flag, value] where found_flag is 1 if an own data property
exists. Accessors / mapped-args / missing keys return found_flag=0 so the
caller falls back to the slow path."""
def:pub js_object_get_own_data_ic(jsobj: JSValue, key: int) -> list[JSValue] {
    out: list[JSValue] = [js_int(0), js_undefined()];
    if not jsv_is_object_cell(jsobj) {
        return out;
    }
    idx: int = jsv_to_table_id(jsobj);
    if idx <= 0 {
        return out;
    }
    raw: JSObject = _obj_get(idx);
    if raw.mapped_args() {
        return out;
    }  # aliased indices need the slow path
    # Non-materializing own-data lookup: get_property() would allocate a fresh
    # JSProperty per call, and on this ~75M-calls/build hot path the owned
    # result local leaked (~3GB, OOMed vite builds under --gc). has_own_data()
    # + get() are both scalar-returning and allocation-free.
    if not raw.has_own_data(key) {
        return out;
    }
    # Accessor own properties are stored with getter/setter tables — if a getter
    # is registered, this is not a plain data prop.
    if key in _acc_ro(raw).getters or key in _acc_ro(raw).setters {
        return out;
    }
    out[0] = js_int(1);
    out[1] = raw.get(key);
    return out;
}

"""
[[Set]](obj, key, val) — set an own property with default data-property flags.
Does nothing if the object is not extensible and the key is new.
Returns 0 on success, 1 if rejected (non-extensible / non-writable).
ECMAScript §10.1.9.
"""
def:pub js_object_set(jsobj: JSValue, key: int, val: JSValue) -> int {
    if not jsv_is_object_cell(jsobj) {
        return 1;
    }
    if jsv_to_table_id(jsobj) <= 0 {
        return 1;
    }
    raw: JSObject = _obj_get(jsv_to_table_id(jsobj));
    if (raw.cell_flags & FLAG_IS_PROTO) != 0 {
        proto_epoch_bump();
    }
    if (raw.cell_flags & FLAG_IS_GLOBAL) != 0 {
        global_obj_note_write(key);
    }
    # An index-keyed prop landing on a PROTOTYPE object invalidates the dense
    # fast paths that skip prototype walks (hole/out-of-range reads, appends).
    if (raw.cell_flags & FLAG_IS_PROTO) != 0
        and idx_protector_ok()
        and _obj_is_array_index_key_id(key) {
        idx_protector_clear();
    }
    # Dense elements: in-range write / append / small-gap hole-fill stay
    # dense; big gaps or non-extensible new indices degrade or reject.
    if raw.elems_kind != ELEMS_NONE and _obj_is_array_index_key_id(key) {
        dsi: int = _obj_array_index_sort_key(key);
        el_w: list[JSValue] = raw.elems_rw();
        dsn: int = len(el_w);
        if dsi < dsn {
            el_w[dsi] = val;
            return 0;
        }
        if raw.is_ext() {
            if dsi == dsn {
                el_w.append(val);
                return 0;
            }
            if dsi <= dsn + DENSE_GAP_MAX {
                while len(el_w) < dsi {
                    el_w.append(jsv_hole());
                }
                el_w.append(val);
                raw.elems_kind = ELEMS_HOLEY;
                return 0;
            }
        } else {
            return 1;
        }
        raw.ensure_sparse();
    }
    # Array-index keys would each mint a transition (per-index shape chains,
    # e.g. filling an array-like) — send them to dict mode instead. Dense
    # element storage is a separate workstream (interpreter_optimizations §3).
    # Accessor-owned keys also convert first: dict-mode [[Set]] treats an
    # accessor-only key as "no data property" (VM handles the setter before
    # ever reaching here) and that semantic must survive the mode change.
    if raw.mode == MAP_MODE_SHAPE {
        sgp: int = shape_lookup(raw.shape_id, key);
        w_acc: bool = sgp >= 0 and (sgp & SHAPE_ATTR_ACCESSOR) != 0;
        w_idx: bool = _obj_is_array_index_key_id(key);
        if w_acc or w_idx {
            if _DEOPT_DBG < 0 {
                if getenv("JAC_DEOPT_STATS") != None {
                    _DEOPT_DBG = 1;
                } else {
                    _DEOPT_DBG = 0;
                }
            }
            if _DEOPT_DBG == 1 {
                if w_idx {
                    _DEOPT_IDX = _DEOPT_IDX + 1;
                } else {
                    _DEOPT_ACC = _DEOPT_ACC + 1;
                }
                if ((_DEOPT_IDX + _DEOPT_ACC) % 500000) == 0 {
                    dm: str = "[DEOPT] set-funnel idx="
                        + str(_DEOPT_IDX)
                        + " acc="
                        + str(_DEOPT_ACC)
                        + "\n";
                    write(2, dm, len(dm));
                }
            }
            raw.pm_ensure_dict();
        }
    }
    if raw.has_key(key) {
        prop: JSProperty = raw.get_property(key);
        if not prop.writable {
            return 1;
        }
        # Mapped arguments: writing an aliased index writes the live parameter slot
        # (and the stored value, kept in sync for descriptor reads).
        if raw.mapped_args() {
            st_ars: ArgsState = _args_row(jsv_to_table_id(jsobj));
            if key in st_ars.slot_map {
                ms: int = st_ars.slot_map[key];
                if ms >= 0 and ms < len(st_ars.locals) {
                    st_ars.locals[ms] = val;
                }
            }
        }
        # Preserve existing descriptor flags (ECMAScript [[Set]] only updates value)
        existing_flags: int = 0;
        if prop.writable {
            existing_flags = existing_flags | PROP_WRITABLE;
        }
        if prop.enumerable {
            existing_flags = existing_flags | PROP_ENUMERABLE;
        }
        if prop.configurable {
            existing_flags = existing_flags | PROP_CONFIGURABLE;
        }
        if raw.set(key, val, existing_flags) != 0 {
            raw.pm_ensure_dict();
            raw.set(key, val, existing_flags);
        }
        return 0;
    }
    if not raw.is_ext() {
        return 1;
    }
    if raw.set(key, val, PROP_DEFAULT) != 0 {
        raw.pm_ensure_dict();
        raw.set(key, val, PROP_DEFAULT);
    }
    return 0;
}

"""
Define own property with explicit descriptor flags (PROP_* bitmask).
Use for non-enumerable/non-configurable properties like array.length.
Returns 0 on success, 1 if rejected.
"""
def:pub js_object_set_flags(jsobj: JSValue, key: int, val: JSValue, flags: int) -> int {
    if not jsv_is_object_cell(jsobj) {
        return 1;
    }
    if jsv_to_table_id(jsobj) <= 0 {
        return 1;
    }
    raw: JSObject = _obj_get(jsv_to_table_id(jsobj));
    if (raw.cell_flags & FLAG_IS_GLOBAL) != 0 {
        global_obj_note_write(key);
    }
    if raw.elems_kind != ELEMS_NONE and _obj_is_array_index_key_id(key) {
        raw.ensure_sparse();
    }
    if raw.mode == MAP_MODE_SHAPE {
        sgf: int = shape_lookup(raw.shape_id, key);
        if (sgf >= 0 and (sgf & SHAPE_ATTR_ACCESSOR) != 0)
            or _obj_is_array_index_key_id(key) {
            raw.pm_ensure_dict();
        }
    }
    if raw.has_key(key) {
        prop: JSProperty = raw.get_property(key);
        if not prop.writable {
            return 1;
        }
    } elif not raw.is_ext() {
        return 1;
    }
    if raw.set(key, val, flags) != 0 {
        raw.pm_ensure_dict();
        raw.set(key, val, flags);
    }
    return 0;
}

"""
Remove an own data/accessor property while leaving `key_order` intact.
Used by ValidateAndApplyPropertyDescriptor kind conversions (data↔accessor)
so insertion order is preserved; contrast `js_object_delete` which purges
key_order for the `delete` operator.
"""
def:pub js_object_remove_own_keep_order(jsobj: JSValue, key: int) -> bool {
    if not jsv_is_object_cell(jsobj) {
        return False;
    }
    if jsv_to_table_id(jsobj) <= 0 {
        return False;
    }
    raw: JSObject = _obj_get(jsv_to_table_id(jsobj));
    if (raw.cell_flags & FLAG_IS_GLOBAL) != 0 {
        global_obj_note_write(key);
    }
    if raw.elems_kind != ELEMS_NONE and _obj_is_array_index_key_id(key) {
        raw.ensure_sparse();
    }
    if raw.mode == MAP_MODE_SHAPE and raw.has_key(key) {
        raw.pm_ensure_dict();
    }
    if key in _acc_ro(raw).getters
        or key in _acc_ro(raw).setters
        or key in _acc_ro(raw).enumerable
        or key in _acc_ro(raw).configurable {
        acc_conf: bool = True;
        if key in _acc_ro(raw).configurable {
            acc_conf = _acc_ro(raw).configurable[key];
        }
        if not acc_conf {
            return False;
        }
        if key in _acc_ro(raw).getters {
            del _acc_ro(raw).getters[key];
        }
        if key in _acc_ro(raw).setters {
            del _acc_ro(raw).setters[key];
        }
        if key in _acc_ro(raw).enumerable {
            del _acc_ro(raw).enumerable[key];
        }
        if key in _acc_ro(raw).configurable {
            del _acc_ro(raw).configurable[key];
        }
        if raw.has_key(key) {
            raw.delete(key);
        }
        return True;
    }
    prop: JSProperty = raw.get_property(key);
    if prop.key == 0 {
        return True;
    }
    if not prop.configurable {
        return False;
    }
    if raw.mapped_args() {
        dl_ars: ArgsState = _args_row(jsv_to_table_id(jsobj));
        if key in dl_ars.slot_map {
            del dl_ars.slot_map[key];
        }
    }
    raw.delete(key);
    return True;
}

"""
[[Delete]](obj, key) — remove an own property.
Returns True on success, False if non-configurable.
ECMAScript §10.1.10. Purges key_order so a later re-add appends once.
"""
def:pub js_object_delete(jsobj: JSValue, key: int) -> bool {
    if not jsv_is_object_cell(jsobj) {
        return False;
    }
    if jsv_to_table_id(jsobj) <= 0 {
        return False;
    }
    raw: JSObject = _obj_get(jsv_to_table_id(jsobj));
    if (raw.cell_flags & FLAG_IS_PROTO) != 0 {
        proto_epoch_bump();
    }
    if (raw.cell_flags & FLAG_IS_GLOBAL) != 0 {
        global_obj_note_write(key);
    }
    # Dense elements are configurable by construction: delete = punch a hole.
    if raw.elems_kind != ELEMS_NONE and _obj_is_array_index_key_id(key) {
        ddel: int = _obj_array_index_sort_key(key);
        el_d: list[JSValue] = raw.elems_rw();
        if ddel < len(el_d) and not jsv_is_hole(el_d[ddel]) {
            el_d[ddel] = jsv_hole();
            raw.elems_kind = ELEMS_HOLEY;
        }
        return True;
    }
    # Shape mode: any delete of an existing key (data or accessor) leaves
    # shape mode first, then the dict logic below applies verbatim.
    if raw.mode == MAP_MODE_SHAPE and raw.has_key(key) {
        raw.pm_ensure_dict();
    }
    # Accessor property: honour its configurable attribute, then remove it from the
    # accessor dicts and the insertion order.
    if key in _acc_ro(raw).getters or key in _acc_ro(raw).setters {
        acc_conf: bool = True;
        if key in _acc_ro(raw).configurable {
            acc_conf = _acc_ro(raw).configurable[key];
        }
        if not acc_conf {
            return False;
        }
        if key in _acc_ro(raw).getters {
            del _acc_ro(raw).getters[key];
        }
        if key in _acc_ro(raw).setters {
            del _acc_ro(raw).setters[key];
        }
        if key in _acc_ro(raw).enumerable {
            del _acc_ro(raw).enumerable[key];
        }
        if key in _acc_ro(raw).configurable {
            del _acc_ro(raw).configurable[key];
        }
        # Drop the key from the insertion order (inline; adding a helper here risks
        # the jsobject.na.jac parser function-count limit).
        acc_ko_new: list[int] = [];
        for acc_kk in raw.ko_ro() {
            if acc_kk != key {
                acc_ko_new.append(acc_kk);
            }
        }
        raw.key_order = acc_ko_new;
        return True;
    }
    prop: JSProperty = raw.get_property(key);
    has_getter: bool = key in _acc_ro(raw).getters;
    has_setter: bool = key in _acc_ro(raw).setters;
    if prop.key == 0 and not has_getter and not has_setter {
        return True;  # already absent — delete succeeds per spec
    }
    # Non-configurable data/accessor sentinels in `properties` reject delete.
    # Accessor-only entries (no properties sentinel) are treated as configurable.
    if prop.key != 0 and not prop.configurable {
        return False;
    }
    # Mapped arguments: deleting an aliased index removes the parameter mapping
    # (ES §10.4.4.4) — a later re-add of the index must NOT re-alias the parameter.
    if raw.mapped_args() {
        dl_ars: ArgsState = _args_row(jsv_to_table_id(jsobj));
        if key in dl_ars.slot_map {
            del dl_ars.slot_map[key];
        }
    }
    if prop.key != 0 {
        raw.delete(key);
    }
    # Purge accessor tables so HasProperty / [[Get]] no longer see a stale
    # getter/setter after the property is deleted (R18).
    if has_getter {
        del _acc_ro(raw).getters[key];
    }
    if has_setter {
        del _acc_ro(raw).setters[key];
    }
    # Lazy compaction (perf): leave the deleted id in key_order and let the
    # OwnKeys reader skip/dedup it (see js_object_own_keys' liveness filter),
    # rebuilding only when dead ids dominate. adel_fixes purged key_order on
    # every delete — O(n) per delete on delete-heavy workloads — which this
    # deliberately avoids. Correctness is preserved by the reader-side dedup.
    _compact_key_order(raw);
    return True;
}

"""Drop dead ids from `key_order` once they outnumber the live keys.

A delete leaves the key's id in `key_order` (readers skip it via a liveness
check), so a fill/clear cycle — `arr.length = 0` in a loop is the common one —
grows key_order without bound and makes every enumeration O(all keys ever
inserted) rather than O(live keys), i.e. quadratic overall.

Liveness must consider BOTH the property map and the accessor tables: an
accessor-only key (defineProperty with just a get/set) lives in `key_order` with
NO `entries` row, so testing `entries` alone would silently delete every getter
and setter from enumeration. That is exactly what broke ~30 suites on the first
attempt at this. Rebuilding preserves relative order, so insertion order is
unaffected."""
def _compact_key_order(raw: JSObject) -> None {
    if raw.mode == MAP_MODE_SHAPE {
        return;
    }  # no tombstones in shape mode
    ko_c: list[int] = raw.ko_ro();
    ent_c: dict[int, JSProperty] = raw.ent_ro();
    ko_len: int = len(ko_c);
    if ko_len <= 16 {
        return;
    }
    live_n: int = len(ent_c) + len(_acc_ro(raw).getters) + len(_acc_ro(raw).setters);
    if ko_len <= 2 * live_n {
        return;
    }
    ko_new: list[int] = [];
    koi: int = 0;
    while koi < ko_len {
        kok: int = ko_c[koi];
        if kok in ent_c or kok in _acc_ro(raw).getters or kok in _acc_ro(raw).setters {
            ko_new.append(kok);
        }
        koi = koi + 1;
    }
    raw.key_order = ko_new;
}


# ═══════════════════════════════════════════════════════════════════════════════
# Public API — HasProperty / HasOwnProperty
# ═══════════════════════════════════════════════════════════════════════════════

"""[[HasOwnProperty]](obj, key) — own properties only. ECMAScript §10.1.7."""
def:pub js_object_has_own(jsobj: JSValue, key: int) -> bool {
    if not jsv_is_object_cell(jsobj) {
        return False;
    }
    if jsv_to_table_id(jsobj) <= 0 {
        return False;
    }
    raw: JSObject = _obj_get(jsv_to_table_id(jsobj));
    if raw.elems_kind != ELEMS_NONE and _obj_is_array_index_key_id(key) {
        dho: int = _obj_array_index_sort_key(key);
        if dho < len(raw.elems_ro()) and not jsv_is_hole(raw.elems_ro()[dho]) {
            return True;
        }
    }
    if raw.has_key(key) {
        return True;
    }
    # No accessor side table: nothing else can hold the key. (The common
    # miss — marker-key probes on plain objects — paid four empty-table
    # lookups, each through its own AccessorTable reference.)
    if raw.accessors is None {
        return False;
    }
    return (
        key in _acc_ro(raw).getters
        or key in _acc_ro(raw).setters
        or key in _acc_ro(raw).configurable
        or key in _acc_ro(raw).enumerable
    );
}

"""True if jsobj has an own accessor property for key (get/set may be undefined).

Presence is tracked via accessor_enumerable / accessor_configurable (seeded by
`_register_accessor_key`) as well as the getter/setter maps, so an accessor
whose [[Get]] and [[Set]] are both `undefined` still counts as an accessor —
native dict stores may not retain undefined-valued entries.
"""
def:pub js_object_has_own_accessor(jsobj: JSValue, key: int) -> bool {
    if not jsv_is_object_cell(jsobj) {
        return False;
    }
    if jsv_to_table_id(jsobj) <= 0 {
        return False;
    }
    raw: JSObject = _obj_get(jsv_to_table_id(jsobj));
    if raw.mode == MAP_MODE_SHAPE {
        hac: int = shape_lookup(raw.shape_id, key);
        return hac >= 0 and (hac & SHAPE_ATTR_ACCESSOR) != 0;
    }
    if key in _acc_ro(raw).getters or key in _acc_ro(raw).setters {
        return True;
    }
    if key in _acc_ro(raw).configurable or key in _acc_ro(raw).enumerable {
        return True;
    }
    return False;
}

"""
[[HasProperty]](obj, key) — full prototype chain.  ECMAScript §10.1.7.1.
Mirrors the `in` operator.
"""
def:pub js_object_has(jsobj: JSValue, key: int) -> bool {
    if not jsv_is_object_cell(jsobj) {
        return False;
    }
    current_idx: int = jsv_to_table_id(jsobj);
    if current_idx <= 0 {
        return False;
    }
    for _depth in range(PROTO_MAX_DEPTH) {
        if current_idx <= 0 {
            return False;
        }
        current: JSObject = _obj_get(current_idx);
        if current.elems_kind != ELEMS_NONE and _obj_is_array_index_key_id(key) {
            dhp: int = _obj_array_index_sort_key(key);
            if dhp < len(current.elems_ro())
                and not jsv_is_hole(current.elems_ro()[dhp]) {
                return True;
            }
        }
        if current.has_key(key) {
            return True;
        }
        if current.accessors is not None
            and (key in _acc_ro(current).getters or key in _acc_ro(current).setters) {
            return True;
        }
        current_idx = current.prototype_idx;
    }
    return False;
}


# ═══════════════════════════════════════════════════════════════════════════════
# Public API — enumeration
# ═══════════════════════════════════════════════════════════════════════════════

def _obj_is_array_index_key_id(kid: int) -> bool {
    if kid >= SYMBOL_KEY_BASE {
        return False;
    }
    # `length` is the hottest non-index key on arrays: answered without the
    # cache lookup.
    if kid == KEY_LENGTH {
        return False;
    }
    # Cached per key id (str_id_is_array_index): this runs on every property
    # lookup of an array-like object.
    return str_id_is_array_index(kid);
}

def _obj_array_index_sort_key(kid: int) -> int {
    s: str = str_from_id(kid);
    np: int = 0;
    pi: int = 0;
    sn: int = len(s);
    # Byte-wise digit test: the previous `ch: str = str_substr(...)` per digit
    # parked an owned 1-byte str in a named local that is never released — two
    # leaked allocations per array-index property get (Array.prototype.join over
    # 800 elements retained 100KB per call).
    while pi < sn {
        cc: int = ord(s[pi]);
        if cc >= 48 and cc <= 57 {
            np = np * 10 + (cc - 48);
        }
        pi = pi + 1;
    }
    return np;
}

"""Stable merge-sort of array-index key IDs by numeric value (O(n log n)).

Replaces the previous O(n^2) bubble sort used by OwnPropertyKeys — objects
with thousands of numeric keys (Object.keys / spread / Object.assign) were
quadratic."""
def _obj_merge_sort_index_keys(indices: list[int]) -> list[int] {
    n: int = len(indices);
    if n <= 1 {
        return indices;
    }
    mid: int = n // 2;
    left: list[int] = [];
    right: list[int] = [];
    li: int = 0;
    while li < mid {
        left.append(indices[li]);
        li = li + 1;
    }
    while li < n {
        right.append(indices[li]);
        li = li + 1;
    }
    left = _obj_merge_sort_index_keys(left);
    right = _obj_merge_sort_index_keys(right);
    out: list[int] = [];
    i: int = 0;
    j: int = 0;
    while i < len(left) and j < len(right) {
        if _obj_array_index_sort_key(left[i]) <= _obj_array_index_sort_key(right[j]) {
            out.append(left[i]);
            i = i + 1;
        } else {
            out.append(right[j]);
            j = j + 1;
        }
    }
    while i < len(left) {
        out.append(left[i]);
        i = i + 1;
    }
    while j < len(right) {
        out.append(right[j]);
        j = j + 1;
    }
    return out;
}

def _obj_sort_key_id_partitions(indices: list[int], strings: list[int]) {
    # Sort in place by replacing contents with merge-sorted order.
    sorted_ids: list[int] = _obj_merge_sort_index_keys(indices);
    si: int = 0;
    sn: int = len(sorted_ids);
    while si < sn {
        indices[si] = sorted_ids[si];
        si = si + 1;
    }
}

"""True if `kid` names an engine-internal per-instance private brand marker
(`__brand@<sid>`). These are stamped on instances / the class object to enforce private
brand checks (ES §6.2.12) and must never appear in user-visible own-key enumeration."""
def _obj_key_id_is_internal_brand(kid: int) -> bool {
    if kid < 0 or kid >= BUILTIN_BASE {
        return False;
    }
    return str_id_is_brand_key(kid);
}


# Engine-internal marker keys filtered out of own-key enumeration
# (js_object_own_key_ids_ordered), interned on first use.
glob _OKO_MK_IS_CLASS: int = -1,
     _OKO_MK_CTOR: int = -1,
     _OKO_MK_CLASS_NAME: int = -1,
     _OKO_MK_BRAND_CUR: int = -1,
     _OKO_MK_BRANDSID_CUR: int = -1,
     _OKO_MK_STATIC_FIELDS: int = -1,
     _OKO_MK_FIELDS: int = -1;

def _oko_markers {
    _OKO_MK_CTOR = str_intern("__CTOR__");
    _OKO_MK_CLASS_NAME = str_intern("__CLASS_NAME__");
    _OKO_MK_BRAND_CUR = str_intern("__brand@cur");
    _OKO_MK_BRANDSID_CUR = str_intern("__brandsid@cur");
    _OKO_MK_STATIC_FIELDS = str_intern("__STATIC_FIELDS__");
    _OKO_MK_FIELDS = str_intern("__FIELDS__");
    _OKO_MK_IS_CLASS = str_intern("__IS_CLASS__");
}

"""All own property key IDs in [[OwnPropertyKeys]] order (indices, strings, symbols)."""
def:pub js_object_own_key_ids_ordered(jsobj: JSValue) -> list[int] {
    empty: list[int] = [];
    if not jsv_is_object_cell(jsobj) {
        return empty;
    }
    if jsv_to_table_id(jsobj) <= 0 {
        return empty;
    }
    # js_object_all_keys already synthesizes dense-element index ids (in
    # numeric order) ahead of the map keys; the partition below re-routes
    # them into `indices` — do NOT synthesize a second copy here.
    raw_ids: list[int] = js_object_all_keys(jsobj);
    indices: list[int] = [];
    strings: list[int] = [];
    symbols: list[int] = [];
    # Internal class markers are stored as ordinary string properties (the compiler
    # emits `__IS_CLASS__` / `__CTOR__` / `__CLASS_NAME__` via SET_PROP), but they
    # are engine-internal and MUST NOT appear in any user-visible own-key list
    # (getOwnPropertyNames / keys / Reflect.ownKeys / assign / spread). Filter them
    # here — the single ordered-own-keys chokepoint. (json.jac filters __IS_CLASS__
    # the same way.) Computed once per call, not per key.
    # (Interned once — see _oko_markers; this ran per call, seven string
    # hash + compare lookups each.)
    if _OKO_MK_IS_CLASS < 0 {
        _oko_markers();
    }
    mk_is_class: int = _OKO_MK_IS_CLASS;
    mk_ctor: int = _OKO_MK_CTOR;
    mk_class_name: int = _OKO_MK_CLASS_NAME;
    # Per-evaluation private brand markers stamped on the class object by MAKE_CLASS
    # (`__brand@cur` / `__brandsid@cur`) are engine-internal too — never user-visible.
    mk_brand_cur: int = _OKO_MK_BRAND_CUR;
    mk_brandsid_cur: int = _OKO_MK_BRANDSID_CUR;
    # The class object's field lists (static fields run at class evaluation,
    # instance fields at construction) are bookkeeping too: `class K { static a = 1 }`
    # listed "__STATIC_FIELDS__" in Object.keys(K) / getOwnPropertyNames / `{ ...K }`.
    mk_static_fields: int = _OKO_MK_STATIC_FIELDS;
    mk_fields: int = _OKO_MK_FIELDS;
    for kid in raw_ids {
        if kid < 0 {
            continue;
        }
        if kid == mk_is_class or kid == mk_ctor or kid == mk_class_name {
            continue;
        }
        if kid == mk_brand_cur or kid == mk_brandsid_cur {
            continue;
        }
        if kid == mk_static_fields or kid == mk_fields {
            continue;
        }
        # The per-instance private brand `__brand@<sid>` (a synthetic field stamped on
        # instances / the class) is also internal — its name starts with "__brand@".
        if _obj_key_id_is_internal_brand(kid) {
            continue;
        }
        if kid >= BUILTIN_BASE and kid < SYMBOL_KEY_BASE {
            continue;
        }
        if kid >= SYMBOL_KEY_BASE {
            symbols.append(kid);
        } elif _obj_is_array_index_key_id(kid) {
            indices.append(kid);
        } else {
            strings.append(kid);
        }
    }
    _obj_sort_key_id_partitions(indices, strings);
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

"""
True iff `jsobj` is a plain data-only array eligible for the VM's sparse-array
callback fast path (forEach/map/filter/every/some/…). Requires:
  - a real array with dense/holey elems OR a sparse map of pure DATA index props,
  - NO accessor properties at all (a getter/setter could observe iteration order
    or mutate live state in ways the hole-skipping snapshot must not reorder),
  - class_id == 0 (not a Proxy/exotic), extensible or not is irrelevant here.
The no-inherited-index protector (idx_protector_ok) is checked separately by the
caller — together they guarantee a hole answers HasProperty=false with no
prototype walk, so skipping holes is observationally identical to probing them.
"""
def:pub js_object_array_is_dataonly_fast(jsobj: JSValue) -> bool {
    if not jsv_is_object_cell(jsobj) {
        return False;
    }
    if jsv_to_table_id(jsobj) <= 0 {
        return False;
    }
    raw: JSObject = _obj_get(jsv_to_table_id(jsobj));
    if raw.class_id != 0 {
        return False;
    }
    if len(_acc_ro(raw).getters) != 0 or len(_acc_ro(raw).setters) != 0 {
        return False;
    }
    if raw.mapped_args() or (raw.cell_flags & FLAG_MODULE_NS) != 0 {
        return False;
    }
    return True;
}

"""
Smallest PRESENT own array-index in [from_idx, n), or n if none — the live
cursor that lets a callback loop jump across holes in O(present) instead of
scanning every integer. Re-queried each step so additions/deletions the
callback performs are honored (spec: HasProperty is checked live per index).

Dense/holey: forward scan of `elems` from from_idx skipping hole sentinels
(O(gap), and gaps in a dense array are ≤ DENSE_GAP_MAX by construction).
Sparse map: probe from_idx .. from_idx+DENSE_GAP_MAX-1 by key lookup, then
min-scan the array-index keys past that window. The probe is what keeps a
callback loop linear: an array can sit in the map with few or no holes (frozen,
sealed, an index defineProperty, one far write), and a full key scan on every
step made forEach/map over it O(n²) (~15K elements: 232M key checks, 82% of a
vite build). Caller must have verified eligibility via
js_object_array_is_dataonly_fast + idx_protector_ok.
"""
def:pub js_object_next_present_index_ge(jsobj: JSValue, from_idx: int, n: int) -> int {
    if not jsv_is_object_cell(jsobj) {
        return n;
    }
    if jsv_to_table_id(jsobj) <= 0 {
        return n;
    }
    raw: JSObject = _obj_get(jsv_to_table_id(jsobj));
    if raw.elems_kind != ELEMS_NONE {
        de_i: int = from_idx;
        de_n: int = len(raw.elems_ro());
        if de_n > n {
            de_n = n;
        }
        while de_i < de_n {
            if not jsv_is_hole(raw.elems_ro()[de_i]) {
                return de_i;
            }
            de_i = de_i + 1;
        }
        return n;
    }
    # Sparse map: probe the next indices directly first.
    pr_end: int = from_idx + DENSE_GAP_MAX;
    if pr_end > n {
        pr_end = n;
    }
    pr_i: int = from_idx;
    while pr_i < pr_end {
        pr_k: int = str_intern_lookup(str(pr_i));
        if pr_k >= 0 and raw.has_key(pr_k) {
            return pr_i;
        }
        pr_i = pr_i + 1;
    }
    if pr_end >= n {
        return n;
    }
    # A gap wider than the window: the minimum array-index key in [pr_end, n).
    best: int = n;
    for kid in raw.all_keys() {
        if kid < 0 {
            continue;
        }
        if _obj_is_array_index_key_id(kid) {
            iv: int = _obj_array_index_sort_key(kid);
            if iv >= pr_end and iv < n and iv < best {
                best = iv;
            }
        }
    }
    return best;
}

"""Live enumerable check for EnumerableOwnPropertyNames / CopyDataProperties."""
def:pub js_object_own_key_is_enumerable_now(jsobj: JSValue, kid: int) -> bool {
    if not jsv_is_object_cell(jsobj) {
        return False;
    }
    if jsv_to_table_id(jsobj) <= 0 {
        return False;
    }
    raw_e: JSObject = _obj_get(jsv_to_table_id(jsobj));
    if raw_e.elems_kind != ELEMS_NONE and _obj_is_array_index_key_id(kid) {
        den: int = _obj_array_index_sort_key(kid);
        return den < len(raw_e.elems_ro()) and not jsv_is_hole(raw_e.elems_ro()[den]);
    }
    # Shape mode: data AND accessor entries answer from the packed attrs
    # (get_property reports accessors as not-found, so it can't be used here).
    if raw_e.mode == MAP_MODE_SHAPE {
        oke: int = shape_lookup(raw_e.shape_id, kid);
        if oke >= 0 {
            return (oke & PROP_ENUMERABLE) != 0;
        }
        return False;
    }
    p_e: JSProperty = raw_e.get_property(kid);
    if p_e.key != 0 {
        return p_e.enumerable;
    }
    if kid in _acc_ro(raw_e).getters
        or kid in _acc_ro(raw_e).setters
        or kid in _acc_ro(raw_e).enumerable
        or kid in _acc_ro(raw_e).configurable {
        acc_enum: bool = True;
        if kid in _acc_ro(raw_e).enumerable {
            acc_enum = _acc_ro(raw_e).enumerable[kid];
        }
        return acc_enum;
    }
    return False;
}

# js_object_keys per shape id (V4.20): shapes are immutable and never freed.
glob _OKEYS_BY_SHAPE: dict[int, list[int]] = {},
     _SPREAD_PLANS: dict[int, list[int]] = {};

# Object spread / rest plans per shape id (V4.23): [key, slot, key, slot, …]
# of the enumerable own keys in [[OwnPropertyKeys]] order, or [-1] when a key
# is an accessor. Declared above its writer (Jac binds an earlier assignment
# as a local).
"""The spread plan of `v` (see _SPREAD_PLANS) when it is an ordinary
shape-mode object without element storage, brand marker or exotic flags,
else [-1]. The list is shared: callers must not modify it."""
def:pub js_object_spread_plan(v: JSValue) -> list[int] {
    sp_none: list[int] = [-1];
    if not jsv_is_object_cell(v) {
        return sp_none;
    }
    sp_id: int = jsv_to_table_id(v);
    if sp_id <= 0 {
        return sp_none;
    }
    if _OBJ_REALM.objects[sp_id - 1].mode != MAP_MODE_SHAPE
        or _OBJ_REALM.objects[sp_id - 1].elems_kind != ELEMS_NONE
        or _OBJ_REALM.objects[sp_id - 1].class_id != 0
        or _OBJ_REALM.objects[sp_id - 1].binary_kind != 0
        or _OBJ_REALM.objects[sp_id - 1].brand != 0
        or (
            _OBJ_REALM.objects[sp_id - 1].cell_flags
            & (
                FLAG_MODULE_NS
                | FLAG_IS_GLOBAL
                | FLAG_IS_ARGUMENTS
                | FLAG_MAPPED_ARGS
                | FLAG_IS_CLASS
            )
        )
            != 0 {
        return sp_none;
    }
    sp_sid: int = _OBJ_REALM.objects[sp_id - 1].shape_id;
    if sp_sid in _SPREAD_PLANS {
        return _SPREAD_PLANS[sp_sid];
    }
    sp_plan: list[int] = [];
    for sp_k in js_object_own_key_ids_ordered(v) {
        sp_a: int = shape_lookup(sp_sid, sp_k);
        if sp_a < 0 or (sp_a & SHAPE_ATTR_ACCESSOR) != 0 {
            sp_plan = [-1];
            break;
        }
        if (sp_a & PROP_ENUMERABLE) != 0 {
            sp_plan.append(sp_k);
            sp_plan.append(sp_a // 16);
        }
    }
    _SPREAD_PLANS[sp_sid] = sp_plan;
    return sp_plan;
}

"""
Object.keys(jsobj) — own enumerable string-key property IDs (no symbols).
Snapshot [[OwnPropertyKeys]]; re-check [[Enumerable]] per key.
ECMAScript §20.1.2.16 / §7.3.23.
"""
def:pub js_object_keys(jsobj: JSValue) -> list[int] {
    empty: list[int] = [];
    if not jsv_is_object_cell(jsobj) {
        return empty;
    }
    ok_id: int = jsv_to_table_id(jsobj);
    if ok_id <= 0 {
        return empty;
    }
    # An ordinary shape-mode object without element storage: the answer is a
    # function of its shape (V4.20) — cached per shape id, a copy returned.
    ok_sid: int = -1;
    if _OBJ_REALM.objects[ok_id - 1].mode == MAP_MODE_SHAPE
        and _OBJ_REALM.objects[ok_id - 1].elems_kind == ELEMS_NONE
        and _OBJ_REALM.objects[ok_id - 1].class_id == 0
        and _OBJ_REALM.objects[ok_id - 1].binary_kind == 0 {
        ok_sid = _OBJ_REALM.objects[ok_id - 1].shape_id;
        if ok_sid in _OKEYS_BY_SHAPE {
            ok_c: list[int] = _OKEYS_BY_SHAPE[ok_sid];
            ok_out: list[int] = [];
            for ok_k in ok_c {
                ok_out.append(ok_k);
            }
            return ok_out;
        }
    }
    result: list[int] = [];
    for k in js_object_own_key_ids_ordered(jsobj) {
        if k >= SYMBOL_KEY_BASE {
            continue;
        }
        if js_object_own_key_is_enumerable_now(jsobj, k) {
            result.append(k);
        }
    }
    if ok_sid >= 0 {
        ok_keep: list[int] = [];
        for ok_r in result {
            ok_keep.append(ok_r);
        }
        _OKEYS_BY_SHAPE[ok_sid] = ok_keep;
    }
    return result;
}

"""
Return the key IDs for which this object has an accessor getter (i.e. keys set
via js_object_set_accessor_getter).  Used by REEXPORT_STAR to enumerate live-
getter keys on ESM namespace objects, which store their exports as accessor
getters rather than plain properties so that re-exports propagate correctly
across transitive export * from chains.
"""
def:pub js_object_accessor_getter_keys(jsobj: JSValue) -> list[int] {
    empty: list[int] = [];
    if not jsv_is_object_cell(jsobj) {
        return empty;
    }
    if jsv_to_table_id(jsobj) <= 0 {
        return empty;
    }
    raw: JSObject = _obj_get(jsv_to_table_id(jsobj));
    result: list[int] = [];
    if raw.mode == MAP_MODE_SHAPE {
        agk: list[int] = shape_keys(raw.shape_id);
        agi: int = 0;
        while agi < len(agk) {
            agp: int = shape_lookup(raw.shape_id, agk[agi]);
            if agp >= 0
                and (agp & SHAPE_ATTR_ACCESSOR) != 0
                and not jsv_is_undefined(raw.slots[agp // 16]) {
                result.append(agk[agi]);
            }
            agi = agi + 1;
        }
        return result;
    }
    for k in _acc_ro(raw).getters {
        result.append(k);
    }
    return result;
}

"""
Return ALL own property key IDs, including non-enumerable.
Used internally (e.g. _populate_vm_globals) to iterate every binding.
ECMAScript §20.1.2.8 Object.getOwnPropertyNames.
"""
def:pub js_object_all_keys(jsobj: JSValue) -> list[int] {
    empty: list[int] = [];
    if not jsv_is_object_cell(jsobj) {
        return empty;
    }
    if jsv_to_table_id(jsobj) <= 0 {
        return empty;
    }
    raw: JSObject = _obj_get(jsv_to_table_id(jsobj));
    if raw.elems_kind != ELEMS_NONE {
        akd: list[int] = [];
        akd_i: int = 0;
        while akd_i < len(raw.elems_ro()) {
            if not jsv_is_hole(raw.elems_ro()[akd_i]) {
                akd.append(str_intern_index(akd_i));
            }
            akd_i = akd_i + 1;
        }
        for akd_k in raw.all_keys() {
            akd.append(akd_k);
        }
        return akd;
    }
    # Shape mode: the shape chain IS the insertion order — data and accessor
    # entries alike — with no tombstones, so no liveness or dedupe filtering.
    if raw.mode == MAP_MODE_SHAPE {
        return raw.all_keys();
    }
    # Walk insertion order, including accessor-only keys (which live in the
    # accessor dicts, not `entries`, but were appended to key_order on install).
    # Dedupe stale key_order entries (safety net if delete missed a purge).
    result: list[int] = [];
    seen: dict[int, bool] = {};
    ko_ak: list[int] = raw.ko_ro();
    ent_ak: dict[int, JSProperty] = raw.ent_ro();
    ki: int = 0;
    while ki < len(ko_ak) {
        k: int = ko_ak[ki];
        if k in seen {
            ki = ki + 1;
            continue;
        }
        if k in ent_ak or k in _acc_ro(raw).getters or k in _acc_ro(raw).setters {
            seen[k] = True;
            result.append(k);
        }
        ki = ki + 1;
    }
    return result;
}

"""js_object_gc_children's walk, appending to the GC's work list directly and
skipping non-cells (the tracer drops them on pop anyway): no per-object
result list — that was one allocation plus regrowth for every traced object
(~37M in a vite build) — and absent dict / accessor tables are not walked."""
def:pub js_object_gc_push_children(idx: int, work: list[JSValue]) -> None {
    if idx <= 0 {
        return;
    }
    raw: JSObject = _obj_get(idx);
    si: int = 0;
    sn: int = len(raw.slots);
    while si < sn {
        if jsv_is_cell(raw.slots[si]) {
            work.append(raw.slots[si]);
        }
        si = si + 1;
    }
    if raw.elems is not None {
        ei: int = 0;
        while ei < len(raw.elems_ro()) {
            if jsv_is_cell(raw.elems_ro()[ei]) {
                work.append(raw.elems_ro()[ei]);
            }
            ei = ei + 1;
        }
    }
    if raw.entries is not None {
        pc_ent: dict[int, JSProperty] = raw.ent_ro();
        for k in pc_ent {
            if jsv_is_cell(pc_ent[k].value) {
                work.append(pc_ent[k].value);
            }
        }
    }
    if raw.accessors is not None {
        for k in _acc_ro(raw).getters {
            work.append(_acc_ro(raw).getters[k]);
        }
        for k in _acc_ro(raw).setters {
            work.append(_acc_ro(raw).setters[k]);
        }
    }
    # Proxy [[ProxyTarget]] / [[ProxyHandler]] and the mapped-arguments row:
    # see js_object_gc_children below.
    if raw.class_id == 1 and idx in _OBJ_REALM.proxy_slots {
        work.append(_OBJ_REALM.proxy_slots[idx].target);
        work.append(_OBJ_REALM.proxy_slots[idx].handler);
    }
    if raw.mapped_args() and idx in _OBJ_REALM.args_slots {
        pc_ai: int = 0;
        while pc_ai < len(_OBJ_REALM.args_slots[idx].locals) {
            work.append(_OBJ_REALM.args_slots[idx].locals[pc_ai]);
            pc_ai = pc_ai + 1;
        }
    }
}

"""
Return all child JSValues of an object that the GC must trace:
own property values + accessor getters + accessor setters.

Lives in this module (not gc.na.jac) so that the dict iteration over
`raw.entries`, `_acc_ro(raw).getters`, and `_acc_ro(raw).setters`
stays in the same module that defines `JSObject` — avoiding the cross-module
dict-field-iteration codegen bug that silently emits no IR.
"""
def:pub js_object_gc_children(idx: int) -> list[JSValue] {
    out: list[JSValue] = [];
    if idx <= 0 {
        return out;
    }
    raw: JSObject = _obj_get(idx);
    # Shape-mode values live in the flat slots list. Missing this walk is a
    # use-after-free factory: slot values would be invisible to the marker.
    si: int = 0;
    while si < len(raw.slots) {
        out.append(raw.slots[si]);
        si = si + 1;
    }
    # Dense array elements likewise (hole sentinels are non-cells — the
    # tracer ignores them, so no filtering needed here).
    ei: int = 0;
    while ei < len(raw.elems_ro()) {
        out.append(raw.elems_ro()[ei]);
        ei = ei + 1;
    }
    ent_gc: dict[int, JSProperty] = raw.ent_ro();
    for k in ent_gc {
        out.append(ent_gc[k].value);
    }
    for k in _acc_ro(raw).getters {
        out.append(_acc_ro(raw).getters[k]);
    }
    for k in _acc_ro(raw).setters {
        out.append(_acc_ro(raw).setters[k]);
    }
    # The view→buffer strong edge (TypedArray/DataView, kind 2/3) is traced from
    # gc.jac's mark loop now: the buffer's table id lives in the native
    # TypedArrayData/DataViewData record and jsobject cannot import binary_state
    # (that module imports us — cycle). See gc.jac + binary_view_buffer_id.
    # Proxy internal slots [[ProxyTarget]] / [[ProxyHandler]] live in dedicated
    # JSObject fields, NOT in properties/slots/elems, so the walks above miss
    # them. Unrooted, a Proxy's handler (its trap closures + everything they
    # capture) and target were swept, and the Proxy silently DEGRADED to plain
    # target access — traps stopped firing. rollup's output-bundle Proxy returns
    # its lowercase-keys Set from the `get` trap; once swept,
    # `bundle[lowercaseBundleKeys]` read undefined → "Cannot read properties of
    # undefined (reading 'has')" in generateFinalHashes under --gc.
    # class_id == CLASS_ID_PROXY (1); default fields are js_undefined (a non-cell
    # the tracer ignores) so the guard is just to avoid two no-op appends per
    # ordinary object.
    if raw.class_id == 1 and idx in _OBJ_REALM.proxy_slots {
        px_gc: ProxyState = _OBJ_REALM.proxy_slots[idx];
        out.append(px_gc.target);
        out.append(px_gc.handler);
    }
    # Mapped-arguments row: `locals` aliases the activation's live locals list, so
    # its entries must stay reachable while the arguments object is live (Phase 1).
    if raw.mapped_args() and idx in _OBJ_REALM.args_slots {
        ar_gc: ArgsState = _OBJ_REALM.args_slots[idx];
        as_i: int = 0;
        while as_i < len(ar_gc.locals) {
            out.append(ar_gc.locals[as_i]);
            as_i = as_i + 1;
        }
    }
    return out;
}

"""
Object.entries(jsobj) — flat list of (key_as_JSInt, value) pairs.
Encoded as [js_int(k0), v0, js_int(k1), v1, ...] since  hasn't
introduced string keys yet.  Consumers iterate in steps of 2.
ECMAScript §20.1.2.5.
"""
def:pub js_object_entries(jsobj: JSValue) -> list[JSValue] {
    empty: list[JSValue] = [];
    if not jsv_is_object_cell(jsobj) {
        return empty;
    }
    if jsv_to_table_id(jsobj) <= 0 {
        return empty;
    }
    # EnumerableOwnPropertyNames kind key+value — string keys only, live enumerable.
    result: list[JSValue] = [];
    for k in js_object_own_key_ids_ordered(jsobj) {
        if k >= SYMBOL_KEY_BASE {
            continue;
        }
        if not js_object_own_key_is_enumerable_now(jsobj, k) {
            continue;
        }
        result.append(jsv_from_int32(k));
        # Ordinary [[Get]] (accessors); Proxy-aware Get lives in Object.entries via VM.
        result.append(js_object_get(jsobj, k));
    }
    return result;
}


# ═══════════════════════════════════════════════════════════════════════════════
# Public API — Object.assign / freeze
# ═══════════════════════════════════════════════════════════════════════════════

"""
CreateDataPropertyOrThrow(O, P, V) for ordinary objects — §7.3.7.
Returns 0 on success, 1 on failure. Callers (object.na.jac) throw TypeError —
this module must not import error.na.jac (cycle: error → jsobject).
"""
def:pub js_object_create_data_property_or_throw(
    jsobj: JSValue, key: int, val: JSValue
) -> int {
    desc: JSProperty = JSProperty(
        key=key,
        value=val,
        writable=True,
        enumerable=True,
        configurable=True,
        deleted=False
    );
    return js_object_define_property(jsobj, key, desc);
}

"""
Object.assign(target, ...sources) — CopyDataProperties (§7.3.25) per source.
Uses observable OwnPropertyKeys / Get and CreateDataPropertyOrThrow on target.
"""
def:pub js_object_assign(target: JSValue, sources: list[JSValue]) -> JSValue {
    if not jsv_is_object_cell(target) {
        return target;
    }
    for src in sources {
        if not jsv_is_object_cell(src) {
            continue;
        }
        key_ids: list[int] = js_object_own_key_ids_ordered(src);
        for kid in key_ids {
            if kid < 0 {
                continue;
            }
            if not js_object_own_key_is_enumerable_now(src, kid) {
                continue;
            }
            prop_val: JSValue = js_object_get(src, kid);
            if js_object_create_data_property_or_throw(target, kid, prop_val) != 0 {
                return target;
            }
        }
    }
    return target;
}

"""
Object.freeze(jsobj) — mark every own property non-writable and non-configurable,
then mark the object non-extensible.  ECMAScript §20.1.2.6.
"""
def:pub js_object_freeze(jsobj: JSValue) -> int {
    if not jsv_is_object_cell(jsobj) {
        return 1;
    }
    if jsv_to_table_id(jsobj) <= 0 {
        return 1;
    }
    raw: JSObject = _obj_get(jsv_to_table_id(jsobj));
    # Integrity ops rewrite every descriptor in place — dict mode's job
    # (Phase 6 may revisit with frozen-shape flags; freeze is rare).
    raw.ensure_sparse();
    raw.pm_ensure_dict();
    ks: list[int] = raw.all_keys();
    for k in ks {
        prop: JSProperty = raw.get_property(k);
        if prop.key != 0 {
            # Clear writable + configurable; preserve enumerable.
            flags: int = 0;
            if prop.enumerable {
                flags = flags | PROP_ENUMERABLE;
            }
            raw.set(k, prop.value, flags);
        }
    }
    # Accessors: clear configurable only (writable is N/A).
    for ak in _acc_ro(raw).getters {
        _acc_rw(raw).configurable[ak] = False;
    }
    for ak2 in _acc_ro(raw).setters {
        _acc_rw(raw).configurable[ak2] = False;
    }
    raw.set_non_ext();
    return 0;
}

# ═══════════════════════════════════════════════════════════════════════════════
# Module Namespace Exotic Object (ECMAScript §10.4.6)
# ═══════════════════════════════════════════════════════════════════════════════

# NOTE: HEAD's live-projection module-namespace builder (js_object_is_module_ns /
# js_make_module_namespace / js_module_ns_source / js_module_ns_set_value, backed
# by the is_module_ns + module_ns_source fields, plus MODULE_NS_TO_STRING_TAG_KEY)
# was superseded in the adel_fixes merge by the incremental lifecycle below
# (js_object_mark_module_namespace → js_object_namespace_export_set →
# js_object_finalize_module_namespace, backed by is_module_namespace). All callers
# were migrated to js_is_module_namespace / the mark-install-finalize API. Removed.

"""
Object.seal(jsobj) — preventExtensions + make all own properties non-configurable.
Writable data properties stay writable. ECMAScript §20.1.2.20 / §7.3.15.
"""
def:pub js_object_seal(jsobj: JSValue) -> int {
    if not jsv_is_object_cell(jsobj) {
        return 1;
    }
    if jsv_to_table_id(jsobj) <= 0 {
        return 1;
    }
    raw: JSObject = _obj_get(jsv_to_table_id(jsobj));
    raw.ensure_sparse();
    raw.pm_ensure_dict();  # in-place descriptor rewrite below is dict-only
    ks: list[int] = raw.all_keys();
    for k in ks {
        prop: JSProperty = raw.get_property(k);
        if prop.key != 0 {
            flags: int = 0;
            if prop.writable {
                flags = flags | PROP_WRITABLE;
            }
            if prop.enumerable {
                flags = flags | PROP_ENUMERABLE;
            }
            # configurable cleared
            raw.set(k, prop.value, flags);
        }
    }
    for ak in _acc_ro(raw).getters {
        _acc_rw(raw).configurable[ak] = False;
    }
    for ak2 in _acc_ro(raw).setters {
        _acc_rw(raw).configurable[ak2] = False;
    }
    raw.set_non_ext();
    return 0;
}

"""
Object.preventExtensions(jsobj) — mark non-extensible. ECMAScript §20.1.2.17.
"""
def:pub js_object_prevent_extensions(jsobj: JSValue) -> int {
    if not jsv_is_object_cell(jsobj) {
        return 1;
    }
    if jsv_to_table_id(jsobj) <= 0 {
        return 1;
    }
    raw: JSObject = _obj_get(jsv_to_table_id(jsobj));
    raw.set_non_ext();
    return 0;
}

"""Object.isExtensible(jsobj). ECMAScript §20.1.2.14."""
def:pub js_object_is_extensible(jsobj: JSValue) -> bool {
    if not jsv_is_object_cell(jsobj) {
        return False;
    }
    if jsv_to_table_id(jsobj) <= 0 {
        return False;
    }
    raw: JSObject = _obj_get(jsv_to_table_id(jsobj));
    # Module Namespace Exotic [[IsExtensible]] always returns false (§10.4.6.3),
    # even while the engine still allows privileged export-key installation
    # (raw.is_ext() may remain true until finalize).
    if (raw.cell_flags & FLAG_MODULE_NS) != 0 {
        return False;
    }
    return raw.is_ext();
}

"""True if `jsobj` is a Module Namespace Exotic Object (§10.4.6)."""
def:pub js_is_module_namespace(jsobj: JSValue) -> bool {
    if not jsv_is_object_cell(jsobj) {
        return False;
    }
    if jsv_to_table_id(jsobj) <= 0 {
        return False;
    }
    raw: JSObject = _obj_get(jsv_to_table_id(jsobj));
    return (raw.cell_flags & FLAG_MODULE_NS) != 0;
}

"""
Mark `jsobj` as a Module Namespace Exotic Object without sealing yet.
Used before module evaluation so self-imports observe exotic [[Set]]/[[Delete]]/
[[IsExtensible]] / @@toStringTag while export keys are still being installed.
Does not clear extensible — finalize does that after evaluation.
"""
def:pub js_object_mark_module_namespace(jsobj: JSValue) -> None {
    if not jsv_is_object_cell(jsobj) {
        return;
    }
    if jsv_to_table_id(jsobj) <= 0 {
        return;
    }
    raw: JSObject = _obj_get(jsv_to_table_id(jsobj));
    raw.cell_flags = raw.cell_flags | FLAG_MODULE_NS;
}

"""
Privileged write used while installing/updating export bindings on a module
namespace during evaluation. Bypasses exotic [[Set]] (which always returns
false) and the non-extensible reject for new keys. String export keys get
{writable:true, enumerable:true, configurable:false}.
"""
def:pub js_object_namespace_export_set(jsobj: JSValue, key: int, val: JSValue) -> int {
    if not jsv_is_object_cell(jsobj) {
        return 1;
    }
    if jsv_to_table_id(jsobj) <= 0 {
        return 1;
    }
    # A Module Namespace Exotic Object can never have an empty-string ("", the
    # canonical intern id 6) export name — no ExportEntry has an empty name.
    # Defensive guard against a dangling/corrupted interned key ever reaching
    # the sink; the true source is fixed upstream (preseed copies via
    # str_substr instead of retaining a rope suffix-view interior pointer).
    if key == 6 {
        return 1;
    }
    raw: JSObject = _obj_get(jsv_to_table_id(jsobj));
    # Namespace objects get non-default flags and later in-place descriptor
    # rewrites (finalize) — dict mode from the first binding.
    raw.pm_ensure_dict();
    flags: int = PROP_WRITABLE | PROP_ENUMERABLE;
    if key >= SYMBOL_KEY_BASE {
        flags = 0;
    }
    raw.set(key, val, flags);
    return 0;
}

"""
Mark `jsobj` as a Module Namespace Exotic Object and seal it:
non-extensible, with non-configurable own string/symbol properties.
String export bindings → writable+enumerable+non-configurable.
Symbol keys (@@toStringTag) → non-writable+non-enumerable+non-configurable.
"""
def:pub js_object_finalize_module_namespace(jsobj: JSValue) -> None {
    if not jsv_is_object_cell(jsobj) {
        return;
    }
    if jsv_to_table_id(jsobj) <= 0 {
        return;
    }
    raw: JSObject = _obj_get(jsv_to_table_id(jsobj));
    raw.pm_ensure_dict();  # in-place entries rewrite below is dict-only
    raw.cell_flags = raw.cell_flags | FLAG_MODULE_NS;
    keys: list[int] = raw.all_keys();
    for ak in _acc_ro(raw).getters {
        found_ak: bool = False;
        ki0: int = 0;
        while ki0 < len(keys) {
            if keys[ki0] == ak {
                found_ak = True;
            }
            ki0 = ki0 + 1;
        }
        if not found_ak {
            keys.append(ak);
        }
    }
    for ak2 in _acc_ro(raw).setters {
        found_ak2: bool = False;
        ki1: int = 0;
        while ki1 < len(keys) {
            if keys[ki1] == ak2 {
                found_ak2 = True;
            }
            ki1 = ki1 + 1;
        }
        if not found_ak2 {
            keys.append(ak2);
        }
    }
    ki: int = 0;
    while ki < len(keys) {
        kid: int = keys[ki];
        if kid < SYMBOL_KEY_BASE {
            ks: str = str_from_id(kid);
            if ks == "__DEFER_PENDING" or ks == "__DEFER_PATH" {
                ki = ki + 1;
                continue;
            }
        }
        if kid in _acc_ro(raw).getters or kid in _acc_ro(raw).setters {
            _acc_rw(raw).configurable[kid] = False;
            if kid not in _acc_ro(raw).enumerable {
                _acc_rw(raw).enumerable[kid] = True;
            }
        } elif kid in raw.ent_ro() {
            prop: JSProperty = raw.ent_ro()[kid];
            is_sym: bool = kid >= SYMBOL_KEY_BASE;
            w: bool = True;
            e: bool = True;
            if is_sym {
                w = False;
                e = False;
            }
            raw.ent_rw()[kid] = JSProperty(
                key=kid,
                value=prop.value,
                writable=w,
                enumerable=e,
                configurable=False,
                deleted=False
            );
        }
        ki = ki + 1;
    }
    raw.set_non_ext();
}

"""Object.isFrozen(jsobj). ECMAScript §20.1.2.12."""
def:pub js_object_is_frozen(jsobj: JSValue) -> bool {
    if not jsv_is_object_cell(jsobj) {
        return True;  # primitives are trivially frozen per spec
    }
    if jsv_to_table_id(jsobj) <= 0 {
        return True;
    }
    raw: JSObject = _obj_get(jsv_to_table_id(jsobj));
    if raw.is_ext() {
        return False;
    }
    if raw.elems_kind != ELEMS_NONE {
        ifd: int = 0;
        while ifd < len(raw.elems_ro()) {
            if not jsv_is_hole(raw.elems_ro()[ifd]) {
                return False;
            }
            ifd = ifd + 1;
        }
    }
    # Shape mode: get_property hides accessors (and freeze converts to dict),
    # so a non-frozen shape object answers from the packed attrs directly.
    if raw.mode == MAP_MODE_SHAPE {
        ifk: list[int] = shape_keys(raw.shape_id);
        ifi: int = 0;
        while ifi < len(ifk) {
            ifp: int = shape_lookup(raw.shape_id, ifk[ifi]);
            if ifp >= 0 {
                if (ifp & PROP_CONFIGURABLE) != 0 {
                    return False;
                }
                if (ifp & SHAPE_ATTR_ACCESSOR) == 0 and (ifp & PROP_WRITABLE) != 0 {
                    return False;
                }
            }
            ifi = ifi + 1;
        }
        return True;
    }
    ks: list[int] = raw.all_keys();
    for k in ks {
        prop: JSProperty = raw.get_property(k);
        if prop.writable or prop.configurable {
            return False;
        }
    }
    for ak in _acc_ro(raw).getters {
        acc_c: bool = True;
        if ak in _acc_ro(raw).configurable {
            acc_c = _acc_ro(raw).configurable[ak];
        }
        if acc_c {
            return False;
        }
    }
    for ak2 in _acc_ro(raw).setters {
        if ak2 in _acc_ro(raw).getters {
            continue;
        }
        acc_c2: bool = True;
        if ak2 in _acc_ro(raw).configurable {
            acc_c2 = _acc_ro(raw).configurable[ak2];
        }
        if acc_c2 {
            return False;
        }
    }
    return True;
}

"""Object.isSealed(jsobj). ECMAScript §20.1.2.13."""
def:pub js_object_is_sealed(jsobj: JSValue) -> bool {
    if not jsv_is_object_cell(jsobj) {
        return True;
    }
    if jsv_to_table_id(jsobj) <= 0 {
        return True;
    }
    raw: JSObject = _obj_get(jsv_to_table_id(jsobj));
    if raw.is_ext() {
        return False;
    }
    if raw.elems_kind != ELEMS_NONE {
        isd: int = 0;
        while isd < len(raw.elems_ro()) {
            if not jsv_is_hole(raw.elems_ro()[isd]) {
                return False;
            }
            isd = isd + 1;
        }
    }
    if raw.mode == MAP_MODE_SHAPE {
        isk: list[int] = shape_keys(raw.shape_id);
        isi: int = 0;
        while isi < len(isk) {
            isp: int = shape_lookup(raw.shape_id, isk[isi]);
            if isp >= 0 and (isp & PROP_CONFIGURABLE) != 0 {
                return False;
            }
            isi = isi + 1;
        }
        return True;
    }
    ks: list[int] = raw.all_keys();
    for k in ks {
        prop: JSProperty = raw.get_property(k);
        if prop.configurable {
            return False;
        }
    }
    for ak in _acc_ro(raw).getters {
        acc_c: bool = True;
        if ak in _acc_ro(raw).configurable {
            acc_c = _acc_ro(raw).configurable[ak];
        }
        if acc_c {
            return False;
        }
    }
    for ak2 in _acc_ro(raw).setters {
        if ak2 in _acc_ro(raw).getters {
            continue;
        }
        acc_c2: bool = True;
        if ak2 in _acc_ro(raw).configurable {
            acc_c2 = _acc_ro(raw).configurable[ak2];
        }
        if acc_c2 {
            return False;
        }
    }
    return True;
}


# ═══════════════════════════════════════════════════════════════════════════════
# Public API — prototype chain access
# ═══════════════════════════════════════════════════════════════════════════════

"""
Object.getPrototypeOf(jsobj).
Returns null JSValue if prototype is null.  ECMAScript §10.1.1.
"""
def:pub js_object_get_prototype(jsobj: JSValue) -> JSValue {
    if not jsv_is_object_cell(jsobj) {
        return js_null();
    }
    if jsv_to_table_id(jsobj) <= 0 {
        return js_null();
    }
    raw: JSObject = _obj_get(jsv_to_table_id(jsobj));
    if raw.prototype_idx == -1 {
        return js_null();
    }
    return _obj_wrap(raw.prototype_idx);
}

"""
Object.setPrototypeOf(obj, proto).
Returns 0 on success, 1 if obj is non-extensible or proto would introduce a cycle.
ECMAScript §10.1.2.
"""
def _proto_would_cycle(obj_idx: int, proto_idx: int) -> bool {
    if proto_idx <= 0 {
        return False;
    }
    walk: int = proto_idx;
    for _depth in range(PROTO_MAX_DEPTH) {
        if walk <= 0 {
            return False;
        }
        if walk == obj_idx {
            return True;
        }
        walk = _obj_get(walk).prototype_idx;
    }
    return True;
}

def:pub js_object_set_prototype(jsobj: JSValue, proto: JSValue) -> int {
    if not jsv_is_object_cell(jsobj) {
        return 1;
    }
    obj_idx: int = jsv_to_table_id(jsobj);
    if obj_idx <= 0 {
        return 1;
    }
    raw: JSObject = _obj_get(obj_idx);
    new_proto_idx: int = -1;
    if jsv_is_object_cell(proto) and jsv_to_table_id(proto) > 0 {
        new_proto_idx = jsv_to_table_id(proto);
    }
    # ES §10.1.14 / Reflect.setPrototypeOf: same current [[Prototype]] succeeds
    # even when the object is non-extensible (before the extensibility rejection).
    if raw.prototype_idx == new_proto_idx {
        return 0;
    }
    # Module Namespace Exotic [[SetPrototypeOf]] → SetImmutablePrototype (§10.4.6.2):
    # only the current [[Prototype]] (always null) is accepted; any other V → false.
    if (raw.cell_flags & FLAG_MODULE_NS) != 0 {
        return 1;
    }
    if not raw.is_ext() {
        return 1;
    }
    if _proto_would_cycle(obj_idx, new_proto_idx) {
        return 1;
    }
    raw.prototype_idx = new_proto_idx;
    # Re-linking a prototype changes the chain of every object inheriting from
    # it: invalidate inherited-read ICs (a non-prototype receiver's own link is
    # checked by the IC itself).
    if (raw.cell_flags & FLAG_IS_PROTO) != 0 {
        proto_epoch_bump();
    }
    # Dense-elements protector: the new prototype may ALREADY carry index
    # properties (e.g. Object.setPrototypeOf(x, [5, 6])). Flag it, and clear
    # the protector if any index-keyed own prop (or dense element) exists on
    # it. Objects deeper in its chain were already prototypes — any index
    # props they gained cleared the protector at write time.
    if new_proto_idx > 0 {
        np_raw: JSObject = _obj_get(new_proto_idx);
        np_raw.cell_flags = np_raw.cell_flags | FLAG_IS_PROTO;
        if idx_protector_ok() {
            if np_raw.class_id != 0 {
                idx_protector_clear();
            } elif np_raw.elems_kind != ELEMS_NONE and len(np_raw.elems_ro()) > 0 {
                idx_protector_clear();
            } else {
                for np_k in js_object_all_keys(proto) {
                    if _obj_is_array_index_key_id(np_k) {
                        idx_protector_clear();
                        break;
                    }
                }
            }
        }
    }
    return 0;
}


# ═══════════════════════════════════════════════════════════════════════════════
# Public API — property descriptors
# ═══════════════════════════════════════════════════════════════════════════════

"""
Object.defineProperty(obj, key, descriptor).
Installs or reconfigures an own property.  ECMAScript §10.1.6.
"""
def _prop_same_value(a: JSValue, b: JSValue) -> bool {
    a_num: bool = jsv_is_int32(a) or jsv_is_double(a);
    b_num: bool = jsv_is_int32(b) or jsv_is_double(b);
    if a_num and b_num {
        da: float = 0.0;
        db: float = 0.0;
        if jsv_is_int32(a) {
            da = float(jsv_to_int32(a));
        } else {
            da = jsv_to_double(a);
        }
        if jsv_is_int32(b) {
            db = float(jsv_to_int32(b));
        } else {
            db = jsv_to_double(b);
        }
        a_nan: bool = not (da == da);
        b_nan: bool = not (db == db);
        if a_nan and b_nan {
            return True;
        }
        if a_nan or b_nan {
            return False;
        }
        if da == 0.0 and db == 0.0 {
            a_neg: bool = jsv_is_double(a) and __float_bits(da) < 0;
            b_neg: bool = jsv_is_double(b) and __float_bits(db) < 0;
            return a_neg == b_neg;
        }
        return da == db;
    }
    return js_strict_equal(a, b);
}

def:pub js_object_define_property(
    jsobj: JSValue, key: int, descriptor: JSProperty
) -> int {
    if not jsv_is_object_cell(jsobj) {
        return 1;
    }
    if jsv_to_table_id(jsobj) <= 0 {
        return 1;
    }
    raw: JSObject = _obj_get(jsv_to_table_id(jsobj));
    if (raw.cell_flags & FLAG_IS_PROTO) != 0 {
        proto_epoch_bump();
    }
    if (raw.cell_flags & FLAG_IS_GLOBAL) != 0 {
        global_obj_note_write(key);
    }
    # Accessor-owned keys must not grow a parallel data property.  ValidateAndApply
    # converts accessor→data by deleting the accessor first; installing data here
    # would fight the record merge (and fail spuriously after preventExtensions).
    if key in _acc_ro(raw).getters or key in _acc_ro(raw).setters {
        return 1;
    }
    if (raw.cell_flags & FLAG_IS_PROTO) != 0
        and idx_protector_ok()
        and _obj_is_array_index_key_id(key) {
        idx_protector_clear();
    }
    if raw.elems_kind != ELEMS_NONE and _obj_is_array_index_key_id(key) {
        if descriptor.writable and descriptor.enumerable and descriptor.configurable {
            ddi: int = _obj_array_index_sort_key(key);
            el_dd: list[JSValue] = raw.elems_rw();
            ddn: int = len(el_dd);
            if ddi < ddn {
                el_dd[ddi] = descriptor.value;
                return 0;
            }
            if ddi == ddn and raw.is_ext() {
                el_dd.append(descriptor.value);
                return 0;
            }
        }
        raw.ensure_sparse();
    }
    if raw.mode == MAP_MODE_SHAPE {
        dpk: int = shape_lookup(raw.shape_id, key);
        if dpk >= 0 and (dpk & SHAPE_ATTR_ACCESSOR) != 0 {
            return 1;
        }
        if _obj_is_array_index_key_id(key) {
            raw.pm_ensure_dict();
        }
    }
    existing: JSProperty = raw.get_property(key);
    # Mapped arguments index: validate against the *live* parameter value, not the
    # stale stored one (ES §10.4.4.2 runs OrdinaryDefineOwnProperty on the current
    # state, which for a mapped index is the parameter binding).
    dpf_idx: int = jsv_to_table_id(jsobj);
    dp_is_mapped: bool = False;
    if raw.mapped_args() and existing.key != 0 {
        if key in _args_row(dpf_idx).slot_map {
            dp_is_mapped = True;
        }
    }
    if dp_is_mapped {
        dpf_ars: ArgsState = _args_row(dpf_idx);
        dpm_slot: int = dpf_ars.slot_map[key];
        if dpm_slot >= 0 and dpm_slot < len(dpf_ars.locals) {
            existing.value = dpf_ars.locals[dpm_slot];
        }
    }
    if existing.key == 0 {
        if not raw.is_ext() {
            return 1;
        }
    } else {
        if not existing.configurable {
            if descriptor.configurable {
                return 1;
            }
            if descriptor.enumerable != existing.enumerable {
                return 1;
            }
            # ES §10.1.6.3: for a non-configurable data property, `writable` may go
            # true→false but not false→true; and once non-writable, the value and
            # writable flag are frozen. SameValue-compatible redefines must succeed.
            if not existing.writable {
                if descriptor.writable {
                    return 1;
                }
                if not _prop_same_value(descriptor.value, existing.value) {
                    return 1;
                }
            }
        }
    }
    flags: int = 0;
    if descriptor.writable {
        flags = flags | PROP_WRITABLE;
    }
    if descriptor.enumerable {
        flags = flags | PROP_ENUMERABLE;
    }
    if descriptor.configurable {
        flags = flags | PROP_CONFIGURABLE;
    }
    if raw.set(key, descriptor.value, flags) != 0 {
        raw.pm_ensure_dict();
        raw.set(key, descriptor.value, flags);
    }
    # Mapped-arguments post-step (ES §10.4.4.2): write the new value to the
    # parameter, then de-map if the redefinition made it non-writable.
    if dp_is_mapped {
        dpf_ars2: ArgsState = _args_row(dpf_idx);
        dpm_slot2: int = dpf_ars2.slot_map[key];
        if dpm_slot2 >= 0 and dpm_slot2 < len(dpf_ars2.locals) {
            dpf_ars2.locals[dpm_slot2] = descriptor.value;
        }
        if not descriptor.writable {
            del dpf_ars2.slot_map[key];
        }
    }
    return 0;
}

"""
Commit a data descriptor already approved by ValidateAndApplyPropertyDescriptor.
Does NOT re-run SameValue / configurable / extensible checks (those reject
compatible SameValue redefines and cause "Cannot redefine" over-rejects).
Still updates mapped Arguments ParameterMap when present.
"""
def:pub js_object_apply_validated_descriptor(
    jsobj: JSValue, key: int, descriptor: JSProperty
) -> int {
    if not jsv_is_object_cell(jsobj) {
        return 1;
    }
    if jsv_to_table_id(jsobj) <= 0 {
        return 1;
    }
    raw: JSObject = _obj_get(jsv_to_table_id(jsobj));
    if (raw.cell_flags & FLAG_IS_GLOBAL) != 0 {
        global_obj_note_write(key);
    }
    if key in _acc_ro(raw).getters or key in _acc_ro(raw).setters {
        return 1;
    }
    if (raw.cell_flags & FLAG_IS_PROTO) != 0
        and idx_protector_ok()
        and _obj_is_array_index_key_id(key) {
        idx_protector_clear();
    }
    if raw.elems_kind != ELEMS_NONE and _obj_is_array_index_key_id(key) {
        if descriptor.writable and descriptor.enumerable and descriptor.configurable {
            avi: int = _obj_array_index_sort_key(key);
            el_av: list[JSValue] = raw.elems_rw();
            avn: int = len(el_av);
            if avi < avn {
                el_av[avi] = descriptor.value;
                return 0;
            }
            if avi == avn and raw.is_ext() {
                el_av.append(descriptor.value);
                return 0;
            }
        }
        raw.ensure_sparse();
    }
    if raw.mode == MAP_MODE_SHAPE {
        avk: int = shape_lookup(raw.shape_id, key);
        if avk >= 0 and (avk & SHAPE_ATTR_ACCESSOR) != 0 {
            return 1;
        }
        if _obj_is_array_index_key_id(key) {
            raw.pm_ensure_dict();
        }
    }
    av_idx: int = jsv_to_table_id(jsobj);
    dp_is_mapped: bool = False;
    if raw.mapped_args() {
        if key in _args_row(av_idx).slot_map {
            dp_is_mapped = True;
        }
    }
    flags: int = 0;
    if descriptor.writable {
        flags = flags | PROP_WRITABLE;
    }
    if descriptor.enumerable {
        flags = flags | PROP_ENUMERABLE;
    }
    if descriptor.configurable {
        flags = flags | PROP_CONFIGURABLE;
    }
    if raw.set(key, descriptor.value, flags) != 0 {
        raw.pm_ensure_dict();
        raw.set(key, descriptor.value, flags);
    }
    if dp_is_mapped {
        av_ars: ArgsState = _args_row(av_idx);
        dpm_slot2: int = av_ars.slot_map[key];
        if dpm_slot2 >= 0 and dpm_slot2 < len(av_ars.locals) {
            av_ars.locals[dpm_slot2] = descriptor.value;
        }
        if not descriptor.writable {
            del av_ars.slot_map[key];
        }
    }
    return 0;
}

"""
Object.getOwnPropertyDescriptor(obj, key).
Returns a JSProperty; caller checks result.key == 0 to detect "not found".
ECMAScript §10.1.5.
"""
def:pub js_object_get_own_property_descriptor(jsobj: JSValue, key: int) -> JSProperty {
    if not jsv_is_object_cell(jsobj) {
        return JSProperty(
            key=0,
            value=js_undefined(),
            writable=False,
            enumerable=False,
            configurable=False,
            deleted=True
        );
    }
    if jsv_to_table_id(jsobj) <= 0 {
        return JSProperty(
            key=0,
            value=js_undefined(),
            writable=False,
            enumerable=False,
            configurable=False,
            deleted=True
        );
    }
    raw: JSObject = _obj_get(jsv_to_table_id(jsobj));
    # Dense element: a plain writable/enumerable/configurable data descriptor.
    if raw.elems_kind != ELEMS_NONE and _obj_is_array_index_key_id(key) {
        dgp: int = _obj_array_index_sort_key(key);
        if dgp < len(raw.elems_ro()) and not jsv_is_hole(raw.elems_ro()[dgp]) {
            return JSProperty(
                key=key,
                value=raw.elems_ro()[dgp],
                writable=True,
                enumerable=True,
                configurable=True,
                deleted=False
            );
        }
    }
    # Shape-mode accessor: surface the present, correctly-flagged descriptor
    # from the packed attrs (get/set values come from get_own_accessor_*).
    if raw.mode == MAP_MODE_SHAPE {
        gsk: int = shape_lookup(raw.shape_id, key);
        if gsk >= 0 and (gsk & SHAPE_ATTR_ACCESSOR) != 0 {
            return JSProperty(
                key=key,
                value=js_undefined(),
                writable=False,
                enumerable=(gsk & PROP_ENUMERABLE) != 0,
                configurable=(gsk & PROP_CONFIGURABLE) != 0,
                deleted=False
            );
        }
    }
    # Accessor property: report an accessor descriptor.  (JSProperty carries no
    # get/set slots — callers needing them use js_object_get_own_accessor_*; here
    # we surface a present, correctly-flagged descriptor so enumeration and
    # `hasOwnProperty`-style checks see the key.  `writable` is meaningless for an
    # accessor and left false.)
    # Include accessor_enumerable/configurable so get:undefined / set:undefined
    # accessors (whose map entries may not retain undefined) still report present.
    if (
        key in _acc_ro(raw).getters
        or key in _acc_ro(raw).setters
        or key in _acc_ro(raw).configurable
        or key in _acc_ro(raw).enumerable
    ) {
        acc_enum: bool = True;
        if key in _acc_ro(raw).enumerable {
            acc_enum = _acc_ro(raw).enumerable[key];
        }
        acc_conf: bool = True;
        if key in _acc_ro(raw).configurable {
            acc_conf = _acc_ro(raw).configurable[key];
        }
        return JSProperty(
            key=key,
            value=js_undefined(),
            writable=False,
            enumerable=acc_enum,
            configurable=acc_conf,
            deleted=False
        );
    }
    gopd_p: JSProperty = raw.get_property(key);
    # Mapped arguments: the descriptor's value reflects the live parameter slot.
    if gopd_p.key != 0 and raw.mapped_args() {
        gopd_ars: ArgsState = _args_row(jsv_to_table_id(jsobj));
        if key in gopd_ars.slot_map {
            gms: int = gopd_ars.slot_map[key];
            if gms >= 0 and gms < len(gopd_ars.locals) {
                return JSProperty(
                    key=gopd_p.key,
                    value=gopd_ars.locals[gms],
                    writable=gopd_p.writable,
                    enumerable=gopd_p.enumerable,
                    configurable=gopd_p.configurable,
                    deleted=False
                );
            }
        }
    }
    return gopd_p;
}


# ═══════════════════════════════════════════════════════════════════════════════
# Public API — accessor descriptors (getters / setters)
# ═══════════════════════════════════════════════════════════════════════════════

"""
Mark `argobj` as a mapped `arguments` exotic object (ES §10.4.4): indexed entries
listed in `slot_map` (interned index-key id → local slot) alias the live parameter
bindings in `locals` (a shared reference to the activation's locals list).
"""
def:pub js_object_mark_arguments(argobj: JSValue) -> None {
    if not jsv_is_object_cell(argobj) {
        return;
    }
    oid: int = jsv_to_table_id(argobj);
    if oid <= 0 {
        return;
    }
    _obj_get(oid).set_arguments();
}

def:pub js_object_set_mapped_args(
    argobj: JSValue, locals: list[JSValue], slot_map: dict[int, int]
) -> None {
    if not jsv_is_object_cell(argobj) {
        return;
    }
    if jsv_to_table_id(argobj) <= 0 {
        return;
    }
    ma_idx: int = jsv_to_table_id(argobj);
    raw: JSObject = _obj_get(ma_idx);
    raw.pm_ensure_dict();  # aliased indices never take the shape path
    raw.set_mapped_args();
    _OBJ_REALM.args_slots[ma_idx] = ArgsState(locals=locals, slot_map=slot_map);
}

"""Remove an index from an arguments object's parameter map (de-map on reconfigure
via [[DefineOwnProperty]], ES §10.4.4.2). After this, reads/writes use the stored
property value, not the parameter slot."""
def:pub js_object_unmap_arg(argobj: JSValue, key: int) -> None {
    if not jsv_is_object_cell(argobj) {
        return;
    }
    if jsv_to_table_id(argobj) <= 0 {
        return;
    }
    ua_idx: int = jsv_to_table_id(argobj);
    raw: JSObject = _obj_get(ua_idx);
    if raw.mapped_args() {
        ua_ars: ArgsState = _args_row(ua_idx);
        if key in ua_ars.slot_map {
            del ua_ars.slot_map[key];
        }
    }
}

"""Return the current live value of a mapped arguments index, or undefined if not
mapped — used by getOwnPropertyDescriptor to report the up-to-date value."""
def:pub js_object_mapped_arg_value(argobj: JSValue, key: int) -> JSValue {
    if not jsv_is_object_cell(argobj) {
        return js_undefined();
    }
    if jsv_to_table_id(argobj) <= 0 {
        return js_undefined();
    }
    mv_idx: int = jsv_to_table_id(argobj);
    raw: JSObject = _obj_get(mv_idx);
    if raw.mapped_args() {
        mv_ars: ArgsState = _args_row(mv_idx);
        if key in mv_ars.slot_map {
            ms: int = mv_ars.slot_map[key];
            if ms >= 0 and ms < len(mv_ars.locals) {
                return mv_ars.locals[ms];
            }
        }
    }
    return js_undefined();
}

"""True if v is an Arguments exotic object (mapped or unmapped)."""
def:pub js_object_is_arguments(v: JSValue) -> bool {
    if not jsv_is_object_cell(v) {
        return False;
    }
    oid: int = jsv_to_table_id(v);
    if oid <= 0 {
        return False;
    }
    return _obj_get(oid).mapped_args() or _obj_get(oid).arguments_obj();
}

"""True if argobj has a live parameter mapping for key."""
def:pub js_object_is_arg_mapped(argobj: JSValue, key: int) -> bool {
    if not jsv_is_object_cell(argobj) {
        return False;
    }
    if jsv_to_table_id(argobj) <= 0 {
        return False;
    }
    am_idx: int = jsv_to_table_id(argobj);
    raw: JSObject = _obj_get(am_idx);
    if not raw.mapped_args() {
        return False;
    }
    return key in _args_row(am_idx).slot_map;
}

"""
Install a getter function for key on jsobj.
ECMAScript: accessor property descriptor with [[Get]].
"""
def:pub js_object_set_accessor_getter(
    jsobj: JSValue, key: int, getter_fn: JSValue
) -> int {
    if not jsv_is_object_cell(jsobj) {
        return 1;
    }
    if jsv_to_table_id(jsobj) <= 0 {
        return 1;
    }
    raw: JSObject = _obj_get(jsv_to_table_id(jsobj));
    if (raw.cell_flags & FLAG_IS_PROTO) != 0 {
        proto_epoch_bump();
    }
    if (raw.cell_flags & FLAG_IS_GLOBAL) != 0 {
        global_obj_note_write(key);
    }
    if idx_protector_ok()
        and _obj_is_array_index_key_id(key)
        and (raw.cell_flags & FLAG_IS_PROTO) != 0 {
        idx_protector_clear();
    }
    if raw.elems_kind != ELEMS_NONE and _obj_is_array_index_key_id(key) {
        raw.ensure_sparse();
    }
    # Shape mode: accessors are 2-slot (getter, setter) shape entries with
    # SHAPE_ATTR_ACCESSOR. New keys transition; an existing accessor rewrites
    # its getter slot in place; a data→accessor kind change goes to dict mode.
    # (Mapped-arguments objects are always dict mode — the de-map below never
    # applies on the shape arm.)
    if raw.mode == MAP_MODE_SHAPE {
        sag: int = shape_lookup(raw.shape_id, key);
        if sag >= 0 and (sag & SHAPE_ATTR_ACCESSOR) != 0 {
            raw.slots[sag // 16] = getter_fn;
            return 0;
        }
        if sag < 0 {
            sag_child: int = shape_transition_add(
                raw.shape_id,
                key,
                SHAPE_ATTR_ACCESSOR | PROP_ENUMERABLE | PROP_CONFIGURABLE
            );
            if sag_child > 0 {
                raw.shape_id = sag_child;
                raw.slots.append(getter_fn);
                raw.slots.append(js_undefined());
                raw.version = raw.version + 1;
                return 0;
            }
        }
        raw.pm_ensure_dict();
    }
    _register_accessor_key(raw, key);
    _acc_rw(raw).getters[key] = getter_fn;
    # Mapped arguments: turning an aliased index into an accessor de-maps it
    # (ES §10.4.4.2 — an accessor descriptor removes the parameter mapping).
    if raw.mapped_args() {
        sa_ars: ArgsState = _args_row(jsv_to_table_id(jsobj));
        if key in sa_ars.slot_map {
            del sa_ars.slot_map[key];
        }
    }
    return 0;
}

"""
Register an accessor key in the object's insertion-order list so it participates
in own-key enumeration (Object.keys / Object.assign / spread / object-rest /
for-in), and seed its descriptor flags (enumerable/configurable = true by
default — object-literal & defineProperty-default semantics).  Idempotent: a key
already present as a data property or a prior accessor is left in place.
"""
def _register_accessor_key(raw: JSObject, key: int) {
    # Accessor storage lives in the side dicts + key_order until Phase 4 —
    # a shape-mode object leaves shape mode at its first accessor.
    raw.pm_ensure_dict();
    # Append only when absent from insertion order.  Data→accessor conversion
    # deletes the data entry but leaves the key in key_order; re-appending
    # duplicates enumeration (Object.keys / entries live semantics).
    in_order: bool = False;
    for ko in raw.ko_ro() {
        if ko == key {
            in_order = True;
            break;
        }
    }
    if not in_order {
        raw.ko_rw().append(key);
    }
    # Drop any stale data-property sentinel so it cannot fight accessor
    # [[Enumerable]]/[[Configurable]] during later DefineOwnProperty / integrity.
    if key in raw.ent_ro() {
        raw.delete(key);
    }
    if key not in _acc_ro(raw).enumerable {
        _acc_rw(raw).enumerable[key] = True;
    }
    if key not in _acc_ro(raw).configurable {
        _acc_rw(raw).configurable[key] = True;
    }
}

"""Set the enumerable attribute of an accessor property (used by class accessor
installation, which is non-enumerable per ES §15.7.11)."""
def:pub js_object_set_accessor_enumerable(
    jsobj: JSValue, key: int, enumerable: bool
) -> None {
    if not jsv_is_object_cell(jsobj) {
        return;
    }
    if jsv_to_table_id(jsobj) <= 0 {
        return;
    }
    raw: JSObject = _obj_get(jsv_to_table_id(jsobj));
    # An absent key gets a blind side-dict row below, which makes it an own
    # accessor: that can shadow an inherited property an IC cached.
    if (raw.cell_flags & FLAG_IS_PROTO) != 0 {
        proto_epoch_bump();
    }
    # Shape mode: an existing accessor's flag flip is an attrs-change replay —
    # the common class-installation pattern (install getter, then
    # enumerable=false) stays in shape mode. Anything else (data key, absent
    # key) reproduces dict mode's blind side-dict seed after converting.
    if raw.mode == MAP_MODE_SHAPE {
        sae: int = shape_lookup(raw.shape_id, key);
        if sae >= 0 and (sae & SHAPE_ATTR_ACCESSOR) != 0 {
            sae_new: int = (sae & 15) & (15 - PROP_ENUMERABLE);
            if enumerable {
                sae_new = sae_new | PROP_ENUMERABLE;
            }
            if sae_new == (sae & 15) {
                return;
            }
            sae_sid: int = shape_change_attrs(raw.shape_id, key, sae_new);
            if sae_sid >= 0 {
                raw.shape_id = sae_sid;
                return;
            }
        }
        raw.pm_ensure_dict();
    }
    _acc_rw(raw).enumerable[key] = enumerable;
}

"""Set the configurable attribute of an accessor property."""
def:pub js_object_set_accessor_configurable(
    jsobj: JSValue, key: int, configurable: bool
) -> None {
    if not jsv_is_object_cell(jsobj) {
        return;
    }
    if jsv_to_table_id(jsobj) <= 0 {
        return;
    }
    raw: JSObject = _obj_get(jsv_to_table_id(jsobj));
    # See js_object_set_accessor_enumerable: may create an own accessor row.
    if (raw.cell_flags & FLAG_IS_PROTO) != 0 {
        proto_epoch_bump();
    }
    if raw.mode == MAP_MODE_SHAPE {
        sac: int = shape_lookup(raw.shape_id, key);
        if sac >= 0 and (sac & SHAPE_ATTR_ACCESSOR) != 0 {
            sac_new: int = (sac & 15) & (15 - PROP_CONFIGURABLE);
            if configurable {
                sac_new = sac_new | PROP_CONFIGURABLE;
            }
            if sac_new == (sac & 15) {
                return;
            }
            sac_sid: int = shape_change_attrs(raw.shape_id, key, sac_new);
            if sac_sid >= 0 {
                raw.shape_id = sac_sid;
                return;
            }
        }
        raw.pm_ensure_dict();
    }
    _acc_rw(raw).configurable[key] = configurable;
}

"""
Install a setter function for key on jsobj.
ECMAScript: accessor property descriptor with [[Set]].
"""
def:pub js_object_set_accessor_setter(
    jsobj: JSValue, key: int, setter_fn: JSValue
) -> int {
    if not jsv_is_object_cell(jsobj) {
        return 1;
    }
    if jsv_to_table_id(jsobj) <= 0 {
        return 1;
    }
    raw: JSObject = _obj_get(jsv_to_table_id(jsobj));
    if (raw.cell_flags & FLAG_IS_PROTO) != 0 {
        proto_epoch_bump();
    }
    if (raw.cell_flags & FLAG_IS_GLOBAL) != 0 {
        global_obj_note_write(key);
    }
    if idx_protector_ok()
        and _obj_is_array_index_key_id(key)
        and (raw.cell_flags & FLAG_IS_PROTO) != 0 {
        idx_protector_clear();
    }
    if raw.elems_kind != ELEMS_NONE and _obj_is_array_index_key_id(key) {
        raw.ensure_sparse();
    }
    if raw.mode == MAP_MODE_SHAPE {
        sas: int = shape_lookup(raw.shape_id, key);
        if sas >= 0 and (sas & SHAPE_ATTR_ACCESSOR) != 0 {
            raw.slots[sas // 16 + 1] = setter_fn;
            return 0;
        }
        if sas < 0 {
            sas_child: int = shape_transition_add(
                raw.shape_id,
                key,
                SHAPE_ATTR_ACCESSOR | PROP_ENUMERABLE | PROP_CONFIGURABLE
            );
            if sas_child > 0 {
                raw.shape_id = sas_child;
                raw.slots.append(js_undefined());
                raw.slots.append(setter_fn);
                raw.version = raw.version + 1;
                return 0;
            }
        }
        raw.pm_ensure_dict();
    }
    _register_accessor_key(raw, key);
    _acc_rw(raw).setters[key] = setter_fn;
    # Mapped arguments: an accessor setter de-maps the aliased index (see getter).
    if raw.mapped_args() {
        sa_ars: ArgsState = _args_row(jsv_to_table_id(jsobj));
        if key in sa_ars.slot_map {
            del sa_ars.slot_map[key];
        }
    }
    return 0;
}

"""
Return this object's own getter for key (no prototype walk).
Returns Undefined if the object has no own getter for key.
ECMAScript: [[GetOwnProperty]] accessor [[Get]] slot.
"""
def:pub js_object_get_own_accessor_getter(jsobj: JSValue, key: int) -> JSValue {
    if not jsv_is_object_cell(jsobj) {
        return js_undefined();
    }
    if jsv_to_table_id(jsobj) <= 0 {
        return js_undefined();
    }
    raw: JSObject = _obj_get(jsv_to_table_id(jsobj));
    if raw.mode == MAP_MODE_SHAPE {
        gag: int = shape_lookup(raw.shape_id, key);
        if gag >= 0 and (gag & SHAPE_ATTR_ACCESSOR) != 0 {
            return raw.slots[gag // 16];
        }
        return js_undefined();
    }
    if key in _acc_ro(raw).getters {
        return _acc_ro(raw).getters[key];
    }
    return js_undefined();
}

"""
Return this object's own setter for key (no prototype walk).
Returns Undefined if the object has no own setter for key.
ECMAScript: [[GetOwnProperty]] accessor [[Set]] slot.
"""
def:pub js_object_get_own_accessor_setter(jsobj: JSValue, key: int) -> JSValue {
    if not jsv_is_object_cell(jsobj) {
        return js_undefined();
    }
    if jsv_to_table_id(jsobj) <= 0 {
        return js_undefined();
    }
    raw: JSObject = _obj_get(jsv_to_table_id(jsobj));
    if raw.mode == MAP_MODE_SHAPE {
        gas: int = shape_lookup(raw.shape_id, key);
        if gas >= 0 and (gas & SHAPE_ATTR_ACCESSOR) != 0 {
            return raw.slots[gas // 16 + 1];
        }
        return js_undefined();
    }
    if key in _acc_ro(raw).setters {
        return _acc_ro(raw).setters[key];
    }
    return js_undefined();
}

"""
Walk the prototype chain looking for a getter for key.
Returns the getter function JSValue, or Undefined if none found.

Stops at the first level that owns `key` in any form (getter, setter-only
accessor, or data property) so an own property correctly shadows inherited
accessors (R18 / ECMAScript OrdinaryGet §10.1.8).
"""
def:pub js_object_lookup_getter(jsobj: JSValue, key: int) -> JSValue {
    if not jsv_is_object_cell(jsobj) {
        return js_undefined();
    }
    current_idx: int = jsv_to_table_id(jsobj);
    if current_idx <= 0 {
        return js_undefined();
    }
    for _depth in range(PROTO_MAX_DEPTH) {
        if current_idx <= 0 {
            return js_undefined();
        }
        current: JSObject = _obj_get(current_idx);
        if current.elems_kind != ELEMS_NONE and _obj_is_array_index_key_id(key) {
            dlg: int = _obj_array_index_sort_key(key);
            if dlg < len(current.elems_ro())
                and not jsv_is_hole(current.elems_ro()[dlg]) {
                return js_undefined();  # own data element shadows prototypes
            }
        }
        if current.mode == MAP_MODE_SHAPE {
            lgp: int = shape_lookup(current.shape_id, key);
            if lgp >= 0 {
                if (lgp & SHAPE_ATTR_ACCESSOR) != 0 {
                    # Getter slot; undefined correctly shadows (setter-only).
                    return current.slots[lgp // 16];
                }
                return js_undefined();  # own data property shadows prototypes
            }
        } else {
            if key in _acc_ro(current).getters {
                return _acc_ro(current).getters[key];
            }
            # Own accessor without [[Get]], or own data property: shadow prototypes.
            if key in _acc_ro(current).setters or current.has_key(key) {
                return js_undefined();
            }
        }
        current_idx = current.prototype_idx;
    }
    return js_undefined();
}

"""
Walk the prototype chain looking for a setter for key.
Returns the setter function JSValue, or Undefined if none found.

Stops at the first level that owns `key` in any form (setter, getter-only
accessor, or data property) so an own property correctly shadows inherited
accessors (R18 / ECMAScript OrdinarySet §10.1.9).
"""
def:pub js_object_lookup_setter(jsobj: JSValue, key: int) -> JSValue {
    if not jsv_is_object_cell(jsobj) {
        return js_undefined();
    }
    current_idx: int = jsv_to_table_id(jsobj);
    if current_idx <= 0 {
        return js_undefined();
    }
    for _depth in range(PROTO_MAX_DEPTH) {
        if current_idx <= 0 {
            return js_undefined();
        }
        current: JSObject = _obj_get(current_idx);
        if current.elems_kind != ELEMS_NONE and _obj_is_array_index_key_id(key) {
            dls: int = _obj_array_index_sort_key(key);
            if dls < len(current.elems_ro())
                and not jsv_is_hole(current.elems_ro()[dls]) {
                return js_undefined();
            }
        }
        if current.mode == MAP_MODE_SHAPE {
            lsp: int = shape_lookup(current.shape_id, key);
            if lsp >= 0 {
                if (lsp & SHAPE_ATTR_ACCESSOR) != 0 {
                    return current.slots[lsp // 16 + 1];
                }
                return js_undefined();  # own data property shadows prototypes
            }
        } else {
            if key in _acc_ro(current).setters {
                return _acc_ro(current).setters[key];
            }
            # Own accessor without [[Set]], or own data property: shadow prototypes.
            if key in _acc_ro(current).getters or current.has_key(key) {
                return js_undefined();
            }
        }
        current_idx = current.prototype_idx;
    }
    return js_undefined();
}

# NAPI dispatch enters Jac from C without going through call_native; register
# push/pop hooks so addon property ops can use the same observable bridge.
def _napi_obs_noop {}

glob _NAPI_OBS_PUSH_FN: Callable[[], None] = _napi_obs_noop,
     _NAPI_OBS_POP_FN: Callable[[], None] = _napi_obs_noop,
     _NAPI_OBS_REGISTERED: bool = False;

"""Register push/pop hooks for NAPI→Jac re-entry (avoids napi→vm import cycle)."""
def:pub js_object_register_napi_obs_scope(
    push_cb: Callable[[], None], pop_cb: Callable[[], None]
) {
    _NAPI_OBS_PUSH_FN = push_cb;
    _NAPI_OBS_POP_FN = pop_cb;
    _NAPI_OBS_REGISTERED = True;
}

"""Push VM observable context at NAPI dispatch entry."""
def:pub js_object_napi_obs_push {
    if _NAPI_OBS_REGISTERED {
        _NAPI_OBS_PUSH_FN();
    }
}

"""Pop VM observable context at NAPI dispatch exit."""
def:pub js_object_napi_obs_pop {
    if _NAPI_OBS_REGISTERED {
        _NAPI_OBS_POP_FN();
    }
}
