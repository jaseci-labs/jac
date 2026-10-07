"""
JSObject type definitions — shared by jsobject.na.jac and realm.na.jac.

Does NOT import runtime.realm (that would create a cycle).
Does NOT define _OBJECT_TABLE or any allocation helpers — those stay in jsobject.na.jac.
"""

import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    jsv_is_undefined,
    jsv_hole,
    jsv_is_hole
}
import from engine.src.runtime.shape {
    shape_transition_add,
    shape_lookup,
    shape_keys,
    shape_has,
    shape_change_attrs,
    SHAPE_ATTR_ACCESSOR
}
import from engine.src.runtime.jscell {
    FLAG_NON_EXTENSIBLE,
    FLAG_MAPPED_ARGS,
    FLAG_IS_ARGUMENTS,
    FLAG_IS_PROTO,
    FLAG_MODULE_NS,
    FLAG_IS_GLOBAL
}
import from engine.src.builtins.markers {
    _KEY_IS_ARRAY,
    _KEY_IS_MAP,
    _KEY_IS_SET,
    _KEY_IS_WEAKMAP,
    _KEY_IS_WEAKSET,
    _KEY_IS_PROMISE,
    _KEY_IS_GEN_MARK,
    _KEY_IS_STRING_OBJ,
    _KEY_IS_ENV_OBJ,
    _KEY_IS_REGEXP_MARK
}

# ═══════════════════════════════════════════════════════════════════════════════
# Property flag bitmask constants
# ═══════════════════════════════════════════════════════════════════════════════

glob:pub PROP_WRITABLE: int = 1,
     PROP_ENUMERABLE: int = 2,
     PROP_CONFIGURABLE: int = 4,
     PROP_DEFAULT: int = 7,
     PROP_READONLY: int = 6,
     MAP_MODE_DICT: int = 0,
     MAP_MODE_SHAPE: int = 1,
     ELEMS_NONE: int = 0,
     ELEMS_DENSE: int = 1,
     ELEMS_HOLEY: int = 2,
     DENSE_GAP_MAX: int = 64;

# writable | enumerable | configurable (data property default)
# enumerable | configurable, not writable

# JSPropertyMap storage modes. DICT must be 0: `mode` is an appended struct
# field, and a zero-default (or garbage-zeroed) value must mean today's
# dict-backed behavior, never the shape fast path.

# Dense-elements kinds (docs/dense_elements_impl_plan.md). NONE must be 0
# (appended-field zero-default = today's map-backed behavior). Transitions:
# NONE→DENSE at array creation, DENSE→HOLEY on delete/elision/gap-fill,
# {DENSE,HOLEY}→NONE via ensure_sparse() — never backwards.

# Gap-fill limit: an index write at most this far past the dense range fills
# with holes and stays HOLEY; anything farther degrades to the sparse map.
# JS_DENSE gate: dense elements are the DEFAULT; JS_DENSE=0 forces sparse-map
# arrays (A/B lever, same pattern as JS_SHAPES=0 / JS_IC=0). Set from
# init_global, which owns getenv — this module must stay free of ffi imports
# (memset-collision issue). The glob default covers pre-init allocations.
glob _DENSE_GATE: int = 1;

def:pub dense_gate_set(enabled: bool) {
    _DENSE_GATE = 1 if enabled else 0;
}

def:pub dense_gate_enabled -> bool {
    return _DENSE_GATE == 1;
}

# ensure_sparse() must mint interned "0","1",… key ids, but this module cannot
# import jsstring (cycle: jsstring → realm → jsobj_type). init_global registers
# the interner before any JS runs; the unset default returns -1 and
# ensure_sparse skips (unreachable in a booted engine).
def _idx_intern_unset(i: int) -> int {
    return -1;
}

glob _IDX_INTERN_CB: Callable[[int], int] = _idx_intern_unset;

def:pub register_index_interner(cb: Callable[[int], int]) {
    _IDX_INTERN_CB = cb;
}

# No-index-props-on-prototypes protector (V8's NoElements idea): while intact,
# a dense hole/out-of-range READ is undefined without a prototype walk, and a
# dense APPEND needs no prototype setter/readonly probe. Cleared - permanently -
# the first time an index-keyed property (data or accessor) lands on any object
# that serves as a prototype (FLAG_IS_PROTO). Checked on every dense fast path;
# ── Prototype mutation epoch (call_path P4 / shapes Phase-6 [[Set]]-add IC) ──
# Bumped on ANY property mutation (set/delete/define/accessor install) of an
# object flagged FLAG_IS_PROTO. An IC that verified "no accessor named K on
# the receiver's prototype chain" at fill time stays valid while the epoch is
# unchanged — chain SHAPE changes on prototypes always route through these
# mutation entry points.

# once cleared those paths fall back to the fully general slow path.
glob _IDX_PROTECTOR: int = 1;

def:pub idx_protector_clear {
    _IDX_PROTECTOR = 0;
}

glob _PROTO_EPOCH: int = 1;

def:pub proto_epoch -> int {
    return _PROTO_EPOCH;
}

def:pub proto_epoch_bump {
    _PROTO_EPOCH = _PROTO_EPOCH + 1;
}
# Bumps attributed to the GC sweeping a prototype object (JS_REG_STATS).
glob _PROTO_EPOCH_GC: int = 0;
def:pub proto_epoch_bump_gc {
    _PROTO_EPOCH = _PROTO_EPOCH + 1;
    _PROTO_EPOCH_GC = _PROTO_EPOCH_GC + 1;
}
def:pub proto_epoch_gc_bumps -> int {
    return _PROTO_EPOCH_GC;
}

# Writes to the global object (FLAG_IS_GLOBAL). The VM keeps its own name→value
# table for bare global reads; a write through the object (`globalThis.fetch = f`,
# `Object.defineProperty(globalThis, …)`, `delete globalThis.x`) bumps the epoch and
# records the key so the next bare read refreshes that name from the object.
glob _GLOBAL_OBJ_EPOCH: int = 0,
     _GLOBAL_OBJ_DIRTY: dict[int, bool] = {};

def:pub global_obj_epoch -> int {
    return _GLOBAL_OBJ_EPOCH;
}

def:pub global_obj_note_write(key: int) {
    _GLOBAL_OBJ_EPOCH = _GLOBAL_OBJ_EPOCH + 1;
    _GLOBAL_OBJ_DIRTY[key] = True;
}

"""The keys written since the last call (and forget them)."""
def:pub global_obj_take_dirty -> list[int] {
    keys: list[int] = [];
    for k in _GLOBAL_OBJ_DIRTY {
        keys.append(k);
    }
    for dk in keys {
        del _GLOBAL_OBJ_DIRTY[dk];
    }
    return keys;
}

def:pub idx_protector_ok -> bool {
    return _IDX_PROTECTOR == 1;
}

# ── Brands: the builtin type markers mirrored into JSObject.brand ─────────────
# js_is_map / js_is_generator / … used to be js_object_has_own(v, marker): a full
# own-property miss (~500 instructions) for almost every object, run seven times
# on every uncached property read. `brand` holds one bit per marker, kept equal to
# "has the marker as an own property" by JSObject.set (key added) and
# JSObject.delete (key removed) — the only ways an own data key comes or goes —
# and reset wherever an object slot is recycled. Markers are ordinary data
# properties set with js_object_set, so the property itself stays the source of
# the marker's VALUE (the String wrapper's primitive, the Promise state, …).
glob:pub BRAND_ARRAY: int = 1,
     BRAND_MAP: int = 2,
     BRAND_SET: int = 4,
     BRAND_WEAKMAP: int = 8,
     BRAND_WEAKSET: int = 16,
     BRAND_GENERATOR: int = 32,
     BRAND_PROMISE: int = 64,
     BRAND_STRING_OBJ: int = 128,
     BRAND_ENV_OBJ: int = 256,
     BRAND_REGEXP: int = 512;

# process.env (string-coerced writes)
# RegExp compiled-state marker (GC tracing)
"""The brand bit a marker key stands for, or 0 for any other key. Markers are
negative ids or live in the reserved intern gap [1000000, 1010000), so the
range test turns every ordinary key away before the compares."""
def:pub brand_bit_for_key(key: int) -> int {
    if key >= 0 and (key < 1000000 or key >= 1010000) {
        return 0;
    }
    if key == _KEY_IS_ARRAY {
        return BRAND_ARRAY;
    }
    if key == _KEY_IS_MAP {
        return BRAND_MAP;
    }
    if key == _KEY_IS_SET {
        return BRAND_SET;
    }
    if key == _KEY_IS_WEAKMAP {
        return BRAND_WEAKMAP;
    }
    if key == _KEY_IS_WEAKSET {
        return BRAND_WEAKSET;
    }
    if key == _KEY_IS_GEN_MARK {
        return BRAND_GENERATOR;
    }
    if key == _KEY_IS_PROMISE {
        return BRAND_PROMISE;
    }
    if key == _KEY_IS_STRING_OBJ {
        return BRAND_STRING_OBJ;
    }
    if key == _KEY_IS_ENV_OBJ {
        return BRAND_ENV_OBJ;
    }
    if key == _KEY_IS_REGEXP_MARK {
        return BRAND_REGEXP;
    }
    return 0;
}


# ═══════════════════════════════════════════════════════════════════════════════
# JSProperty
# ═══════════════════════════════════════════════════════════════════════════════

"""A single property entry in a JSObject's property map."""
obj:pub JSProperty {
    has key: int,
        value: JSValue,
        writable: bool = True,
        enumerable: bool = True,
        configurable: bool = True,
        deleted: bool = False;  # string-interning ID (0 = sentinel "not found")
}


# True only for "not found" sentinel values returned by get_property().
# Live entries in the map always have deleted=False.
# ═══════════════════════════════════════════════════════════════════════════════
# PropertyDescriptorRecord — ES §6.2.6 Property Descriptor
# ═══════════════════════════════════════════════════════════════════════════════

"""
Unified property descriptor with explicit field presence bits.
Used by ToPropertyDescriptor / ValidateAndApplyPropertyDescriptor so each
Attributes field is read exactly once and abrupt-completion order is preserved.
"""
obj:pub PropertyDescriptorRecord {
    has has_value: bool = False,
        has_writable: bool = False,
        has_get: bool = False,
        has_set: bool = False,
        has_enumerable: bool = False,
        has_configurable: bool = False,
        value: JSValue = js_undefined(),
        writable: bool = False,
        get: JSValue = js_undefined(),
        set: JSValue = js_undefined(),
        enumerable: bool = False,
        configurable: bool = False,
        is_invalid: bool = False,
        is_accessor: bool = False;
}


# True when both accessor and data fields are present (invalid descriptor).

# True when this record describes an accessor descriptor.
# ═══════════════════════════════════════════════════════════════════════════════
# ProxyState — off-object Proxy internal slots (docs/OBJECT_FOOTPRINT_PLAN.md P1)
# ═══════════════════════════════════════════════════════════════════════════════

"""Proxy [[ProxyTarget]]/[[ProxyHandler]] + snapshot bits, stored in the sparse
side-table realm.proxy_slots keyed by the proxy's 1-based object index. Only
objects with class_id == CLASS_ID_PROXY have a row, so ordinary objects carry
none of this. `callable`/`constructible` snapshot IsCallable/IsConstructor of the
target at ProxyCreate (typeof/[[Construct]] on a revoked Proxy still consult
them). GC: the row's target/handler are traced via js_object_gc_children while
the proxy is live, and the row is dropped when the proxy slot is swept/reused
(see runtime/proxy.jac, gc.gc_sweep_objects, jsobject._obj_alloc)."""
obj:pub ProxyState {
    has target: JSValue = js_undefined(),
        handler: JSValue = js_undefined(),
        revoked: bool = False,
        callable: bool = False,
        constructible: bool = False;
}

"""Mapped-`arguments` aliasing storage (docs/OBJECT_FOOTPRINT_PLAN.md P1), stored
in realm.args_slots keyed by the arguments object's 1-based index. `locals` is a
shared reference to the activation's locals list (so writes alias both ways);
`slot_map` maps the interned index-key id → local slot index. A row exists only
while the object's is_mapped_args flag is set. GC: `locals` is traced via
js_object_gc_children while the arguments object is live; the row is dropped when
the slot is swept/reused."""
obj:pub ArgsState {
    has locals: list[JSValue] = [],
        slot_map: dict[int, int] = {};
}


"""Accessor (getter/setter) property tables (docs/OBJECT_FOOTPRINT_PLAN.md P2).
Held by a single nullable `JSObject.accessors` reference that is None until the
first accessor is installed — so ordinary objects (the vast majority: every AST
node, plain data object, array) no longer pay 4 always-allocated dicts. Keys are
interned property-name IDs. A key present in `getters`/`setters` but absent from
`enumerable`/`configurable` defaults to enumerable = configurable = true
(object-literal / defineProperty-default semantics); class proto/static accessors
set enumerable=false. GC: getter/setter values are traced via js_object_gc_children
while the owning object is live, and the table is freed with the object (the
inline reference is reset to None on sweep/slot-reuse) — no side-table cleanup."""
obj:pub AccessorTable {
    has getters: dict[int, JSValue] = {},
        setters: dict[int, JSValue] = {},
        enumerable: dict[int, bool] = {},
        configurable: dict[int, bool] = {};
}


# Shared read-only empties for the lazy dict-mode maps (P3b). Returned by
# JSObject.ent_ro()/ko_ro() when the object has no dict storage yet — NEVER
# mutated (all writes go through ent_rw()/ko_rw(), which materialize a fresh
# per-object container). Same discipline as _ACC_EMPTY (jsobject.jac).
glob _ENT_EMPTY: dict[int, JSProperty] = {},
     _KO_EMPTY: list[int] = [],
     _ELEMS_EMPTY: list[JSValue] = [];

# P4: shared read-only empty dense-elements list
# ═══════════════════════════════════════════════════════════════════════════════
# JSObject
# ═══════════════════════════════════════════════════════════════════════════════

"""
Core JavaScript object.

Stored in realm.objects; referenced by index via jsv_to_table_id(JSValue).
prototype_idx is the realm.objects index of the prototype object, or -1 for
a null prototype (Object.create(null)).
"""
obj:pub JSObject {
    has prototype_idx: int,
        entries: dict[int, JSProperty] | None = None,
        key_order: list[int] | None = None,
        version: int = 0,
        shape_id: int = 0,
        slots: list[JSValue] = [],
        mode: int = 0,
        accessors: AccessorTable | None = None,
        class_id: int = 0,
        binary_kind: int = 0,
        binary_slot: int = -1,
        cell_kind: int = 1,
        cell_flags: int = 0,
        structure_id: int = 0,
        elems_kind: int = 0,
        elems: list[JSValue] | None = None,
        brand: int = 0;  # -1 = null prototype

    # ── Lazy dict-mode map accessors (P3b) ─────────────────────────────────
    """Dict `entries` for READ access: the object's own dict, or the shared empty
    one when it has none yet. Result must not be mutated (see ent_rw)."""
    def:pub ent_ro -> dict[int, JSProperty] {
        if self.entries is not None {
            return self.entries;
        }
        return _ENT_EMPTY;
    }

    """Dict `entries` for WRITE access, materializing it on first dict-mode store."""
    def:pub ent_rw -> dict[int, JSProperty] {
        if self.entries is not None {
            return self.entries;
        }
        e: dict[int, JSProperty] = {};
        self.entries = e;
        return e;
    }

    """`key_order` for READ access; shared empty list when the object has none."""
    def:pub ko_ro -> list[int] {
        if self.key_order is not None {
            return self.key_order;
        }
        return _KO_EMPTY;
    }

    """`key_order` for WRITE access, materializing it on first dict-mode store."""
    def:pub ko_rw -> list[int] {
        if self.key_order is not None {
            return self.key_order;
        }
        k: list[int] = [];
        self.key_order = k;
        return k;
    }

    """Element `i` of the dense elements, or the hole when there are none or
    `i` is past them (a hole element is the hole too)."""
    def:pub elem_or_hole(i: int) -> JSValue {
        if self.elems is None {
            return jsv_hole();
        }
        if i >= len(self.elems) {
            return jsv_hole();
        }
        return self.elems[i];
    }

    """The property-IC hit test and read in one: slots[si] when this is an
    ordinary shape-mode object of shape `sid` (the js_object_ic_shape
    conditions), else the hole."""
    def:pub ic_slot(sid: int, si: int) -> JSValue {
        if self.class_id != 0 or self.mode != MAP_MODE_SHAPE or self.shape_id != sid {
            return jsv_hole();
        }
        if (self.cell_flags & (FLAG_MODULE_NS | FLAG_IS_GLOBAL)) != 0 {
            return jsv_hole();
        }
        return self.slots[si];
    }

    """The SET-IC hit test and write in one (see ic_slot); False when the
    shape does not match."""
    def:pub ic_slot_set(sid: int, si: int, val: JSValue) -> bool {
        if self.class_id != 0 or self.mode != MAP_MODE_SHAPE or self.shape_id != sid {
            return False;
        }
        if (self.cell_flags & (FLAG_MODULE_NS | FLAG_IS_GLOBAL)) != 0 {
            return False;
        }
        self.slots[si] = val;
        return True;
    }

    """Dense `elems` for READ access; shared empty list when the array has none
    (or the object is not an array). Result must not be mutated (see elems_rw)."""
    def:pub elems_ro -> list[JSValue] {
        if self.elems is not None {
            return self.elems;
        }
        return _ELEMS_EMPTY;
    }

    """Dense `elems` for WRITE access, materializing it on first densify (P4)."""
    def:pub elems_rw -> list[JSValue] {
        if self.elems is not None {
            return self.elems;
        }
        el: list[JSValue] = [];
        self.elems = el;
        return el;
    }
    # ── Packed cell_flags bool accessors (P5) ──────────────────────────────
    """[[Extensible]] — false once FLAG_NON_EXTENSIBLE is set (JS one-way)."""
    def:pub is_ext -> bool {
        return (self.cell_flags & FLAG_NON_EXTENSIBLE) == 0;
    }

    """Mark [[PreventExtensions]] (one-way; never cleared on a live object)."""
    def:pub set_non_ext {
        self.cell_flags = self.cell_flags | FLAG_NON_EXTENSIBLE;
    }

    """True for a mapped `arguments` exotic object (parameter-slot aliasing)."""
    def:pub mapped_args -> bool {
        return (self.cell_flags & FLAG_MAPPED_ARGS) != 0;
    }

    """Mark this object a mapped `arguments` exotic."""
    def:pub set_mapped_args {
        self.cell_flags = self.cell_flags | FLAG_MAPPED_ARGS;
    }

    """True for any (mapped or unmapped) `arguments` object."""
    def:pub arguments_obj -> bool {
        return (self.cell_flags & FLAG_IS_ARGUMENTS) != 0;
    }

    """Mark this object an `arguments` object."""
    def:pub set_arguments {
        self.cell_flags = self.cell_flags | FLAG_IS_ARGUMENTS;
    }

    """DATA-ONLY shape→dict conversion (no-op in dict mode).

    INVARIANT: must never run on a map holding SHAPE_ATTR_ACCESSOR entries —
    accessor getter/setter slots live here but their dict-mode home (the
    JSObject accessor side-dicts) is out of reach, so this would corrupt them
    into data properties. The only correct converter for a map that may hold
    accessors is JSObject.pm_ensure_dict(); every jsobject.na.jac entry point
    that can face an accessor converts at the OBJECT level first, which is
    what makes the internal delete() backstop below safe."""
    def:pub ensure_dict -> None {
        if self.mode != MAP_MODE_SHAPE {
            return;
        }
        # Slots are about to go away: invalidate inherited-read ICs holding one.
        if (self.cell_flags & FLAG_IS_PROTO) != 0 {
            proto_epoch_bump();
        }
        ks: list[int] = shape_keys(self.shape_id);
        ei: int = 0;
        while ei < len(ks) {
            ek: int = ks[ei];
            packed: int = shape_lookup(self.shape_id, ek);
            if packed >= 0 {
                self.ent_rw()[ek] = JSProperty(
                    key=ek,
                    value=self.slots[packed // 16],
                    writable=(packed & PROP_WRITABLE) != 0,
                    enumerable=(packed & PROP_ENUMERABLE) != 0,
                    configurable=(packed & PROP_CONFIGURABLE) != 0,
                    deleted=False
                );
                self.ko_rw().append(ek);
            }
            ei = ei + 1;
        }
        self.slots = [];
        self.shape_id = 0;
        self.mode = MAP_MODE_DICT;
    }

    """Return the value for key, or JSValue{tag=Undefined} if not found.

    Accessor entries read as undefined — parity with dict mode, where
    accessor-only keys have no `entries` row (getter dispatch is the VM's
    job, before it ever reaches this data path)."""
    def:pub get(key: int) -> JSValue {
        if self.mode == MAP_MODE_SHAPE {
            packed_g: int = shape_lookup(self.shape_id, key);
            if packed_g < 0 {
                return js_undefined();
            }
            if (packed_g & SHAPE_ATTR_ACCESSOR) != 0 {
                return js_undefined();
            }
            return self.slots[packed_g // 16];
        }
        ent_g: dict[int, JSProperty] = self.ent_ro();
        if key in ent_g {
            return ent_g[key].value;
        }
        return js_undefined();
    }

    """Return the full JSProperty for key, or a sentinel (key=0, deleted=True) if not found.

    Shape mode materializes a fresh JSProperty per hit (accepted through
    Phase 4; Phase 5 adds non-materializing accessors for the hot paths)."""
    def:pub get_property(key: int) -> JSProperty {
        if self.mode == MAP_MODE_SHAPE {
            packed_p: int = shape_lookup(self.shape_id, key);
            # Accessor entries report not-found here (dict parity: no entries
            # row) — descriptor readers use the accessor-specific APIs.
            if packed_p >= 0 and (packed_p & SHAPE_ATTR_ACCESSOR) != 0 {
                packed_p = -1;
            }
            if packed_p >= 0 {
                return JSProperty(
                    key=key,
                    value=self.slots[packed_p // 16],
                    writable=(packed_p & PROP_WRITABLE) != 0,
                    enumerable=(packed_p & PROP_ENUMERABLE) != 0,
                    configurable=(packed_p & PROP_CONFIGURABLE) != 0,
                    deleted=False
                );
            }
            return JSProperty(
                key=0,
                value=js_undefined(),
                writable=False,
                enumerable=False,
                configurable=False,
                deleted=True
            );
        }
        ent_gp: dict[int, JSProperty] = self.ent_ro();
        if key in ent_gp {
            return ent_gp[key];
        }
        # Sentinel: key=0 means "not found"
        return JSProperty(
            key=0,
            value=js_undefined(),
            writable=False,
            enumerable=False,
            configurable=False,
            deleted=True
        );
    }

    """Own DATA property value for `key`, or the hole sentinel when there is
    none (absent, or an accessor) — has_own_data() + get() in one lookup."""
    def:pub get_own_data_or_hole(key: int) -> JSValue {
        if self.mode == MAP_MODE_SHAPE {
            packed_o: int = shape_lookup(self.shape_id, key);
            if packed_o < 0 or (packed_o & SHAPE_ATTR_ACCESSOR) != 0 {
                return jsv_hole();
            }
            return self.slots[packed_o // 16];
        }
        ent_o: dict[int, JSProperty] = self.ent_ro();
        if key in ent_o {
            return ent_o[key].value;
        }
        return jsv_hole();
    }

    """Non-materializing own-data presence test for the property-read IC hot path.

    Returns True iff `key` is a present, non-accessor DATA property — mirroring
    the found-ness of get_property() (shape accessors and missing keys → False;
    dict accessors still return True here and are filtered by the caller's
    accessor-table check, exactly as get_property()'s sentinel path was).

    This returns a scalar and allocates NOTHING. get_property() materializes a
    fresh JSProperty per hit in shape mode, and on the ~75M-calls/build IC read
    path that owned obj-typed result local was never released — leaking ~3GB and
    OOMing vite builds under --gc. The read path only needs (present?, value):
    pair this with the existing non-allocating get() for the value."""
    def:pub has_own_data(key: int) -> bool {
        if self.mode == MAP_MODE_SHAPE {
            packed_h: int = shape_lookup(self.shape_id, key);
            if packed_h < 0 {
                return False;
            }
            if (packed_h & SHAPE_ATTR_ACCESSOR) != 0 {
                return False;
            }
            return True;
        }
        return key in self.ent_ro();
    }

    """Insert or update a property; flags is a PROP_* bitmask.

    Returns 0 on success, -1 when the shape path cannot express the write
    (accessor kind conflict, un-replayable attrs change, transition failure):
    the caller must run JSObject.pm_ensure_dict() and retry — set() never
    converts internally because a map holding accessors can only be converted
    at the object level (see ensure_dict's invariant)."""
    def:pub set(key: int, value: JSValue, flags: int) -> int {
        if self.mode == MAP_MODE_SHAPE {
            packed_s: int = shape_lookup(self.shape_id, key);
            if packed_s >= 0 {
                if (packed_s & SHAPE_ATTR_ACCESSOR) != 0 {
                    return -1;
                }
                if (packed_s & 15) == (flags & 7) {
                    self.slots[packed_s // 16] = value;
                    return 0;
                }
                # Attribute change on an existing key: replay the chain with
                # the new attrs — slot layout is preserved (same key order and
                # spans), so slots stays valid and only shape_id moves.
                nsid_s: int = shape_change_attrs(self.shape_id, key, flags & 7);
                if nsid_s >= 0 {
                    self.shape_id = nsid_s;
                    self.slots[packed_s // 16] = value;
                    return 0;
                }
                return -1;
            }
            child: int = shape_transition_add(self.shape_id, key, flags & 7);
            if child > 0 {
                # Slot-index invariant: this map only ever follows span-1
                # transitions from its own shape, so the new key's slot is
                # exactly len(slots).
                self.shape_id = child;
                self.slots.append(value);
                self.version = self.version + 1;  # key add → invalidate ICs
                if key < 0 or key >= 1000000 {
                    self.brand = self.brand | brand_bit_for_key(key);
                }
                # A new key on a prototype can shadow an inherited one an IC cached.
                if (self.cell_flags & FLAG_IS_PROTO) != 0 {
                    proto_epoch_bump();
                }
                return 0;
            }
            return -1;
        }
        w: bool = (flags & PROP_WRITABLE) != 0;
        e: bool = (flags & PROP_ENUMERABLE) != 0;
        c: bool = (flags & PROP_CONFIGURABLE) != 0;
        ent_s: dict[int, JSProperty] = self.ent_rw();  # materialize dict storage
        if key not in ent_s {
            # A delete leaves the id parked in key_order (removing it eagerly
            # would be O(n) per delete). Re-adding the key must not append a
            # SECOND copy — the key would then enumerate twice. Scan only when
            # key_order actually holds more ids than there are live entries,
            # i.e. only when some delete has left slack; in the common
            # never-deleted case this is a single length compare.
            ko_s: list[int] = self.ko_rw();
            if len(ko_s) > len(ent_s) {
                purged: list[int] = [];
                pi: int = 0;
                pn: int = len(ko_s);
                while pi < pn {
                    pk: int = ko_s[pi];
                    if pk != key {
                        purged.append(pk);
                    }
                    pi = pi + 1;
                }
                self.key_order = purged;
                ko_s = purged;  # keep local in sync with the reassigned field
            }
            ko_s.append(key);
            self.version = self.version + 1;  # shape change → invalidate ICs
            if key < 0 or key >= 1000000 {
                self.brand = self.brand | brand_bit_for_key(key);
            }
            if (self.cell_flags & FLAG_IS_PROTO) != 0 {
                proto_epoch_bump();
            }
        }
        ent_s[key] = JSProperty(
            key=key,
            value=value,
            writable=w,
            enumerable=e,
            configurable=c,
            deleted=False
        );
        return 0;
    }

    """
    Mark a property as deleted and remove it from the map.
    Returns True if the property existed and was deleted, False otherwise.
    """
    def:pub delete(key: int) -> bool {
        if self.mode == MAP_MODE_SHAPE {
            if not shape_has(self.shape_id, key) {
                return False;
            }
            # Deletes are the shape worst case: convert, then dict-delete.
            self.ensure_dict();
        }
        ent_d: dict[int, JSProperty] = self.ent_ro();
        if key in ent_d {
            prop: JSProperty = ent_d[key];
            if not prop.deleted {
                del ent_d[key];
                self.version = self.version + 1;  # shape change → invalidate ICs
                if key < 0 or key >= 1000000 {
                    self.brand = self.brand - (self.brand & brand_bit_for_key(key));
                }
                if (self.cell_flags & FLAG_IS_PROTO) != 0 {
                    proto_epoch_bump();
                }
                return True;
            }
        }
        return False;
    }

    """Return True if the key exists in the map."""
    def:pub has_key(key: int) -> bool {
        if self.mode == MAP_MODE_SHAPE {
            return shape_has(self.shape_id, key);
        }
        return key in self.ent_ro();
    }

    """Return list of enumerable key IDs in insertion order."""
    def:pub keys -> list[int] {
        result: list[int] = [];
        if self.mode == MAP_MODE_SHAPE {
            ks_e: list[int] = shape_keys(self.shape_id);
            ei: int = 0;
            while ei < len(ks_e) {
                packed_k: int = shape_lookup(self.shape_id, ks_e[ei]);
                # Accessor entries excluded — dict parity (keys() reads
                # `entries` only; accessor-only keys never appear there).
                if packed_k >= 0
                    and (packed_k & SHAPE_ATTR_ACCESSOR) == 0
                    and (packed_k & PROP_ENUMERABLE) != 0 {
                    result.append(ks_e[ei]);
                }
                ei = ei + 1;
            }
            return result;
        }
        ko_k: list[int] = self.ko_ro();
        ent_k: dict[int, JSProperty] = self.ent_ro();
        ki: int = 0;
        while ki < len(ko_k) {
            k: int = ko_k[ki];
            if k in ent_k {
                if ent_k[k].enumerable {
                    result.append(k);
                }
            }
            ki = ki + 1;
        }
        return result;
    }

    """Return list of all key IDs in insertion order (including non-enumerable)."""
    def:pub all_keys -> list[int] {
        result: list[int] = [];
        if self.mode == MAP_MODE_SHAPE {
            # Fresh copy — shape_keys() returns the shared shape cache, which
            # callers must never mutate.
            ks_a: list[int] = shape_keys(self.shape_id);
            ai: int = 0;
            while ai < len(ks_a) {
                result.append(ks_a[ai]);
                ai = ai + 1;
            }
            return result;
        }
        ko_a: list[int] = self.ko_ro();
        ent_a: dict[int, JSProperty] = self.ent_ro();
        ki: int = 0;
        while ki < len(ko_a) {
            k: int = ko_a[ki];
            if k in ent_a {
                result.append(k);
            }
            ki = ki + 1;
        }
        return result;
    }

    """Dense-elements → sparse-map converter (no-op when ELEMS_NONE).

    Materializes every non-hole element as an ordinary data property at its
    interned decimal key with default attrs (exactly what dense elements are
    by construction), then drops the dense storage. Forces dict mode first:
    index keys must never enter the shape transition tree (per-index shape
    chains — the same reason the jsobject write funnels bail index keys)."""
    def:pub ensure_sparse -> None {
        if self.elems_kind == ELEMS_NONE {
            return;
        }
        self.pm_ensure_dict();
        es_el: list[JSValue] = self.elems_ro();
        es_i: int = 0;
        es_n: int = len(es_el);
        while es_i < es_n {
            es_v: JSValue = es_el[es_i];
            if not jsv_is_hole(es_v) {
                es_k: int = _IDX_INTERN_CB(es_i);
                if es_k >= 0 {
                    self.set(es_k, es_v, PROP_DEFAULT);
                }
            }
            es_i = es_i + 1;
        }
        self.elems = None;
        self.elems_kind = ELEMS_NONE;
    }

    """Materialize (on first use) and return this object's accessor table (P2).
    In-struct counterpart of jsobject.jac's `_acc_rw`, for methods that install
    accessors while converting shape→dict."""
    def ensure_accessors -> AccessorTable {
        if self.accessors is not None {
            return self.accessors;
        }
        t: AccessorTable = AccessorTable(
            getters={}, setters={}, enumerable={}, configurable={}
        );
        self.accessors = t;
        return t;
    }

    """THE shape→dict converter — the only one safe for accessor-bearing maps.

    Data entries materialize into `entries`; accessor entries (2-slot
    getter/setter pairs) move into the accessor side-dicts. Undefined-valued
    getter/setter slots are RETAINED as undefined-valued dict rows — dict
    mode stores whatever the installer passed, and [[Delete]]'s accessor arm
    keys off row MEMBERSHIP (a `{get: undefined}` accessor must still delete
    through that arm). Insertion order is preserved via key_order, which
    lists accessor-only keys too — exactly the dict-mode invariant
    enumeration depends on."""
    def:pub pm_ensure_dict -> None {
        if self.mode != MAP_MODE_SHAPE {
            return;
        }
        # Slots are about to go away: invalidate inherited-read ICs holding one.
        if (self.cell_flags & FLAG_IS_PROTO) != 0 {
            proto_epoch_bump();
        }
        pes: list[int] = shape_keys(self.shape_id);
        pi: int = 0;
        while pi < len(pes) {
            pk: int = pes[pi];
            packed: int = shape_lookup(self.shape_id, pk);
            if packed >= 0 {
                if (packed & SHAPE_ATTR_ACCESSOR) != 0 {
                    at: AccessorTable = self.ensure_accessors();
                    at.getters[pk] = self.slots[packed // 16];
                    at.setters[pk] = self.slots[packed // 16 + 1];
                    at.enumerable[pk] = (packed & PROP_ENUMERABLE) != 0;
                    at.configurable[pk] = (packed & PROP_CONFIGURABLE) != 0;
                    self.ko_rw().append(pk);
                } else {
                    self.ent_rw()[pk] = JSProperty(
                        key=pk,
                        value=self.slots[packed // 16],
                        writable=(packed & PROP_WRITABLE) != 0,
                        enumerable=(packed & PROP_ENUMERABLE) != 0,
                        configurable=(packed & PROP_CONFIGURABLE) != 0,
                        deleted=False
                    );
                    self.ko_rw().append(pk);
                }
            }
            pi = pi + 1;
        }
        self.slots = [];
        self.shape_id = 0;
        self.mode = MAP_MODE_DICT;
    }
}
# ── Own-property storage (was the separate JSPropertyMap archetype; inlined
# in P3a to drop one allocation + RC header per object). SHAPE mode: layout in
# a shared Shape (shape_id) + flat `slots`; entries/key_order unused. DICT mode
# (fallback): `entries` + insertion-ordered `key_order`; slots empty, shape_id 0.
# Transitions are one-way (shape→dict via ensure_dict()).
# P3b: entries/key_order are LAZY — None until the first dict-mode key is stored,
# so shape-mode objects (the common case) carry neither container. INVARIANT:
# both are non-None iff a dict key has been written. Read via ent_ro()/ko_ro()
# (shared empty when None — never mutate), write via ent_rw()/ko_rw()
# (materialize). Direct `= <list>` reassignment (purge rebuilds) is fine.

# MAP_MODE_DICT
# Accessor (getter/setter) tables. None until the first accessor is installed
# (docs/OBJECT_FOOTPRINT_PLAN.md P2) — replaces the 4 always-allocated dicts
# accessor_getters/setters/enumerable/configurable. Read via _acc_ro(raw)
# (returns a shared empty table when None), write via _acc_rw(raw) (materializes
# it). See runtime/jsobject.jac + AccessorTable above.

# 0 = plain object, 1 = Proxy (see proxy.na.jac)
# `extensible`, `is_mapped_args`, `is_arguments` were inline bools; P5 folded
# them into cell_flags bits (FLAG_NON_EXTENSIBLE / FLAG_MAPPED_ARGS /
# FLAG_IS_ARGUMENTS) to shrink the archetype. Access via the is_ext()/
# mapped_args()/arguments_obj() readers and set_non_ext()/set_mapped_args()/
# set_arguments() setters below. `is_mapped_args` still gates the parameter-slot
# aliasing whose storage lives in realm.args_slots[idx] (ArgsState, Phase 1).
# Proxy internal slots moved to the sparse side-table realm.proxy_slots
# (docs/OBJECT_FOOTPRINT_PLAN.md Phase 1): only class_id==CLASS_ID_PROXY
# objects carry a ProxyState row, so ordinary objects no longer pay 5 inline
# fields for state they never use. See runtime/proxy.jac.
# Opaque binary-data internal slots. Detailed state is held by
# runtime.binary_state records and is never exposed as an own property.
# The view→buffer strong edge (formerly `binary_buffer: JSValue`) now lives in
# the native TypedArrayData/DataViewData record as `buffer_id` (its table id);
# readers reconstruct the handle via jsv_from_object_id and GC traces the edge
# from gc.jac's mark loop (docs/OBJECT_FOOTPRINT_PLAN.md Phase 1).
# 0 ordinary, 1 ArrayBuffer/SAB, 2 TypedArray, 3 DataView
# record index in the corresponding native table
# ── Cell header (A2.1) ─────────────────────────────────────────────────
# CELL_KIND_OBJECT

# Module Namespace Exotic Object (ES §10.4.6): a dynamic/static `import(...)`
# namespace. When set, [[Set]] always fails, [[Delete]] fails for own exports,
# [[SetPrototypeOf]] fails for non-null, and the object is non-extensible with
# a null prototype. The former inline `is_module_namespace: bool` moved to the
# cell_flags FLAG_MODULE_NS bit (docs/OBJECT_FOOTPRINT_PLAN.md Phase 1); read it
# via js_is_module_namespace(). Bindings are installed incrementally during
# module evaluation (mark → export_set → finalize).
# ── Dense array elements (docs/dense_elements_impl_plan.md) ────────────
# elems holds the contiguous index range [0, len(elems)); ELEMS_HOLEY marks
# in-place jsv_hole() sentinels (a hole must NEVER leak to JS — readers fall to
# the slow path). The JS `length` property stays a map prop and may exceed
# len(elems) (trailing implicit holes). Only _KEY_IS_ARRAY arrays get a
# non-NONE kind. P4: elems is LAZY — None until an array first densifies, so
# ordinary (non-array) objects carry no elems list. Read via elems_ro()
# (shared empty when None — never mutate), write via elems_rw() (materialize).
# ELEMS_NONE

# BRAND_* bits of the type-marker keys this object owns (see brand_bit_for_key).
