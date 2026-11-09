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
    jsv_is_hole,
    jsv_is_cell
}
import from engine.src.runtime.shape {
    shape_transition_add,
    shape_lookup,
    shape_keys,
    shape_key_count,
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
    FLAG_IS_GLOBAL,
    FLAG_SLOTS_BIG,
    FLAG_OLD,
    FLAG_REMEMBERED
}
import from engine.src.runtime.gc_barrier { gc_rem_obj, gc_young_note }
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
import from engine.src.runtime.mem {
    read_u64,
    write_i64,
    str_nbytes
}
import from engine.src.ffi.libc { realloc, free, write, abort, getenv, memmove, calloc }

# JAC_SLOT_CHECK=1: bounds-check every JSObject slot read/write and abort on a
# violation (debug gate for the raw slot buffers; -1 = env not read yet).
glob _SLOT_CHECK: int = -1;

"""Bounds check for JSObject.sget / sset under JAC_SLOT_CHECK (latches the env var)."""
def _slot_check(sc_n: int, i: int, what: str) -> None {
    if _SLOT_CHECK < 0 {
        if getenv("JAC_SLOT_CHECK") != None {
            _SLOT_CHECK = 1;
        } else {
            _SLOT_CHECK = 0;
            return;
        }
    }
    if i < 0 or i >= sc_n {
        sc_msg: str = "[SLOTCHECK] slot "
            + what
            + " at index "
            + str(i)
            + ", object has "
            + str(sc_n)
            + " slots\n";
        write(2, sc_msg, str_nbytes(sc_msg));
        abort();
    }
}

"""Out of memory while growing a slot buffer."""
def _slot_oom(size: int) -> None {
    so_msg: str = "FATAL: slot buffer OOM (size=" + str(size) + ")\n";
    write(2, so_msg, str_nbytes(so_msg));
    abort();
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

"""Per-object state that few objects need: dict-mode property maps and the
accessor table. Created on first use (JSObject.ext_rw), so an ordinary object
carries one null pointer instead of three. (binary_kind / binary_slot stay in
JSObject: typed-array element access reads them on every access, and the
property fast paths test binary_kind on every object.)"""
obj:pub JSObjectExt {
    has entries: dict[int, JSProperty] | None = None,
        key_order: list[int] | None = None,
        accessors: AccessorTable | None = None;
}

"""
Core JavaScript object.

Stored as a raw record (see below); referenced by index via jsv_to_table_id(JSValue).
prototype_idx is the realm.objects index of the prototype object, or -1 for
a null prototype (Object.create(null)).
"""
# ═══════════════════════════════════════════════════════════════════════════════
# JSObject records (raw store, 2026-11-01)
# ═══════════════════════════════════════════════════════════════════════════════
# An object is a 160-byte record in raw memory addressed by its 1-based table
# id: chunk id >> 12 of the chunk table, record id & 4095 in it (4096 records,
# 640 KB, per chunk; chunks never move, so a record's address is stable). The
# fields are the former JSObject's, one 8-byte word each; JSValues are tagged
# ints, so no word needs refcounting. The rare per-object state (dict-mode
# maps, accessor table) is a JSObjectExt in _JO_EXTS, indexed by word 144
# (0 = none). Word offsets:
#    0 prototype_idx (-1 = null)   8 version   16 shape_id   24 sn
#   32 s0  40 s1  48 s2  56 s3      64 sp       72 mode
#   80 class_id  88 binary_kind  96 binary_slot  104 cell_flags
#  112 oid      120 elems_kind  128 ep           136 brand   144 ext
# Address arithmetic is wrapping (an id and an offset never overflow; the
# checked forms cost an overflow test per field).
glob _JO_CHUNKS: int = 0,
     _JO_CHUNKS_CAP: int = 0,
     _JO_COUNT: int = 0,
     _JO_EXTS: list[JSObjectExt] = [],
     _JO_EXT_FREE: list[int] = [];

"""Word `off` of the record at address `p`."""
def:pub jld(p: int, off: int) -> int {
    return __mem_load_i64(wrapping_add(p, off));
}

"""Store `v` as word `off` of the record at address `p`."""
def:pub jst(p: int, off: int, v: int) -> None {
    __mem_store_i64(wrapping_add(p, off), v);
}

"""The write barrier on the record at address `p` (jo_wb without the
address computation)."""
def:pub jo_wb_p(p: int, v: JSValue) -> None {
    wf: int = __mem_load_i64(wrapping_add(p, 104));
    if (wf & (FLAG_OLD | FLAG_REMEMBERED)) == FLAG_OLD and jsv_is_cell(v) {
        __mem_store_i64(wrapping_add(p, 104), wf | FLAG_REMEMBERED);
        gc_rem_obj(__mem_load_i64(wrapping_add(p, 112)));
    }
}

"""Address of the record of table id `id` (>= 0, < jo_count() + 1)."""
def:pub jo_p(id: int) -> int {
    return wrapping_add(
        __mem_load_i64(wrapping_add(_JO_CHUNKS, wrapping_mul(id >> 12, 8))),
        wrapping_mul(id & 4095, 160)
    );
}

"""Number of ids handed out: ids 1..jo_count() name records (the former
len(realm.objects))."""
def:pub jo_count -> int {
    return _JO_COUNT;
}

"""The next table id, its record zeroed (a fresh chunk is calloc'd on first
use). The caller initializes the fields that are not zero by default."""
def:pub jo_new_id -> int {
    nj: int = _JO_COUNT + 1;
    nc: int = nj >> 12;
    if nc >= _JO_CHUNKS_CAP {
        ncap: int = 64;
        if _JO_CHUNKS_CAP > 0 {
            ncap = _JO_CHUNKS_CAP * 2;
        }
        nt: int = realloc(_JO_CHUNKS, ncap * 8);
        if nt == 0 {
            _slot_oom(ncap * 8);
        }
        nk: int = _JO_CHUNKS_CAP;
        while nk < ncap {
            write_i64(nt, nk * 8, 0);
            nk = nk + 1;
        }
        _JO_CHUNKS = nt;
        _JO_CHUNKS_CAP = ncap;
    }
    if read_u64(_JO_CHUNKS, nc * 8) == 0 {
        ncp: int = calloc(4096, 160);
        if ncp == 0 {
            _slot_oom(4096 * 160);
        }
        write_i64(_JO_CHUNKS, nc * 8, ncp);
    }
    _JO_COUNT = nj;
    return nj;
}

# ── field accessors ──────────────────────────────────────────────────────
def:pub jo_prototype_idx(id: int) -> int {
    return __mem_load_i64(wrapping_add(jo_p(id), 0));
}

def:pub jo_set_prototype_idx(id: int, v: int) -> None {
    __mem_store_i64(wrapping_add(jo_p(id), 0), v);
}

def:pub jo_version(id: int) -> int {
    return __mem_load_i64(wrapping_add(jo_p(id), 8));
}

def:pub jo_set_version(id: int, v: int) -> None {
    __mem_store_i64(wrapping_add(jo_p(id), 8), v);
}

def:pub jo_shape_id(id: int) -> int {
    return __mem_load_i64(wrapping_add(jo_p(id), 16));
}

def:pub jo_set_shape_id(id: int, v: int) -> None {
    __mem_store_i64(wrapping_add(jo_p(id), 16), v);
}

def:pub jo_sn(id: int) -> int {
    return __mem_load_i64(wrapping_add(jo_p(id), 24));
}

def:pub jo_set_sn(id: int, v: int) -> None {
    __mem_store_i64(wrapping_add(jo_p(id), 24), v);
}

def:pub jo_s0(id: int) -> JSValue {
    return __mem_load_i64(wrapping_add(jo_p(id), 32));
}

def:pub jo_set_s0(id: int, v: JSValue) -> None {
    __mem_store_i64(wrapping_add(jo_p(id), 32), v);
}

def:pub jo_s1(id: int) -> JSValue {
    return __mem_load_i64(wrapping_add(jo_p(id), 40));
}

def:pub jo_set_s1(id: int, v: JSValue) -> None {
    __mem_store_i64(wrapping_add(jo_p(id), 40), v);
}

def:pub jo_s2(id: int) -> JSValue {
    return __mem_load_i64(wrapping_add(jo_p(id), 48));
}

def:pub jo_set_s2(id: int, v: JSValue) -> None {
    __mem_store_i64(wrapping_add(jo_p(id), 48), v);
}

def:pub jo_s3(id: int) -> JSValue {
    return __mem_load_i64(wrapping_add(jo_p(id), 56));
}

def:pub jo_set_s3(id: int, v: JSValue) -> None {
    __mem_store_i64(wrapping_add(jo_p(id), 56), v);
}

def:pub jo_sp(id: int) -> int {
    return __mem_load_i64(wrapping_add(jo_p(id), 64));
}

def:pub jo_set_sp(id: int, v: int) -> None {
    __mem_store_i64(wrapping_add(jo_p(id), 64), v);
}

def:pub jo_mode(id: int) -> int {
    return __mem_load_i64(wrapping_add(jo_p(id), 72));
}

def:pub jo_set_mode(id: int, v: int) -> None {
    __mem_store_i64(wrapping_add(jo_p(id), 72), v);
}

def:pub jo_class_id(id: int) -> int {
    return __mem_load_i64(wrapping_add(jo_p(id), 80));
}

def:pub jo_set_class_id(id: int, v: int) -> None {
    __mem_store_i64(wrapping_add(jo_p(id), 80), v);
}

def:pub jo_binary_kind(id: int) -> int {
    return __mem_load_i64(wrapping_add(jo_p(id), 88));
}

def:pub jo_set_binary_kind(id: int, v: int) -> None {
    __mem_store_i64(wrapping_add(jo_p(id), 88), v);
}

def:pub jo_binary_slot(id: int) -> int {
    return __mem_load_i64(wrapping_add(jo_p(id), 96));
}

def:pub jo_set_binary_slot(id: int, v: int) -> None {
    __mem_store_i64(wrapping_add(jo_p(id), 96), v);
}

def:pub jo_cell_flags(id: int) -> int {
    return __mem_load_i64(wrapping_add(jo_p(id), 104));
}

def:pub jo_set_cell_flags(id: int, v: int) -> None {
    __mem_store_i64(wrapping_add(jo_p(id), 104), v);
}

def:pub jo_oid(id: int) -> int {
    return __mem_load_i64(wrapping_add(jo_p(id), 112));
}

def:pub jo_set_oid(id: int, v: int) -> None {
    __mem_store_i64(wrapping_add(jo_p(id), 112), v);
}

def:pub jo_elems_kind(id: int) -> int {
    return __mem_load_i64(wrapping_add(jo_p(id), 120));
}

def:pub jo_set_elems_kind(id: int, v: int) -> None {
    __mem_store_i64(wrapping_add(jo_p(id), 120), v);
}

def:pub jo_ep(id: int) -> int {
    return __mem_load_i64(wrapping_add(jo_p(id), 128));
}

def:pub jo_set_ep(id: int, v: int) -> None {
    __mem_store_i64(wrapping_add(jo_p(id), 128), v);
}

def:pub jo_brand(id: int) -> int {
    return __mem_load_i64(wrapping_add(jo_p(id), 136));
}

def:pub jo_set_brand(id: int, v: int) -> None {
    __mem_store_i64(wrapping_add(jo_p(id), 136), v);
}

# ── extension record (rare per-object state) ───────────────────────────
# _JO_EXTS[0] is a shared empty record that is never written (ext index 0 =
# none); a freed index holds it too, until it is handed out again.
glob _JO_EXT_NONE: JSObjectExt = JSObjectExt();

def _jo_exts_init -> None {
    if len(_JO_EXTS) == 0 {
        _JO_EXTS.append(_JO_EXT_NONE);
    }
}

"""The extension record's index of `id`, 0 when it has none."""
def:pub jo_ext_index(id: int) -> int {
    return __mem_load_i64(wrapping_add(jo_p(id), 144));
}

"""Give `id` the extension record `x` (an index from the free list or a new one)."""
def _jo_ext_attach(id: int, x: JSObjectExt) -> None {
    _jo_exts_init();
    xa: int = 0;
    if len(_JO_EXT_FREE) > 0 {
        xa = _JO_EXT_FREE[len(_JO_EXT_FREE) - 1];
        del _JO_EXT_FREE[len(_JO_EXT_FREE) - 1];
        _JO_EXTS[xa] = x;
    } else {
        xa = len(_JO_EXTS);
        _JO_EXTS.append(x);
    }
    __mem_store_i64(wrapping_add(jo_p(id), 144), xa);
}

"""Drop `id`'s extension record (the former `ext = None`)."""
def:pub jo_drop_ext(id: int) -> None {
    xd: int = __mem_load_i64(wrapping_add(jo_p(id), 144));
    if xd != 0 {
        _JO_EXTS[xd] = _JO_EXT_NONE;
        _JO_EXT_FREE.append(xd);
        __mem_store_i64(wrapping_add(jo_p(id), 144), 0);
    }
}

"""The extension record, created on first use."""
def:pub jo_ext_rw(id: int) -> JSObjectExt {
    xr: int = __mem_load_i64(wrapping_add(jo_p(id), 144));
    if xr != 0 {
        return _JO_EXTS[xr];
    }
    return _jo_ext_new(id);
}

def _jo_ext_new(id: int) -> JSObjectExt {
    er_n: JSObjectExt = JSObjectExt();
    _jo_ext_attach(id, er_n);
    return er_n;
}

def _jx_has_acc(x: JSObjectExt) -> bool {
    return x.accessors is not None;
}

def _jx_has_ent(x: JSObjectExt) -> bool {
    return x.entries is not None;
}

def _jx_ent_ro(x: JSObjectExt) -> dict[int, JSProperty] {
    if x.entries is not None {
        return x.entries;
    }
    return _ENT_EMPTY;
}

def _jx_ko_ro(x: JSObjectExt) -> list[int] {
    if x.key_order is not None {
        return x.key_order;
    }
    return _KO_EMPTY;
}

"""True when the object has an accessor table."""
def:pub jo_has_acc(id: int) -> bool {
    xh: int = __mem_load_i64(wrapping_add(jo_p(id), 144));
    return xh != 0 and _jx_has_acc(_JO_EXTS[xh]);
}

"""Dict `entries` for READ access: the object's own dict, or the shared empty
one when it has none yet. Result must not be mutated (see jo_ent_rw)."""
def:pub jo_ent_ro(id: int) -> dict[int, JSProperty] {
    xe: int = __mem_load_i64(wrapping_add(jo_p(id), 144));
    if xe == 0 {
        return _ENT_EMPTY;
    }
    return _jx_ent_ro(_JO_EXTS[xe]);
}

"""True when the object has its own dict-mode `entries`."""
def:pub jo_has_ent(id: int) -> bool {
    xn: int = __mem_load_i64(wrapping_add(jo_p(id), 144));
    return xn != 0 and _jx_has_ent(_JO_EXTS[xn]);
}

"""Dict `entries` for WRITE access, materializing it on first dict-mode store."""
def:pub jo_ent_rw(id: int) -> dict[int, JSProperty] {
    ew_x: JSObjectExt = jo_ext_rw(id);
    ew_e: dict[int, JSProperty] | None = ew_x.entries;
    if ew_e is not None {
        return ew_e;
    }
    e: dict[int, JSProperty] = {};
    ew_x.entries = e;
    return e;
}

"""`key_order` for READ access; shared empty list when the object has none."""
def:pub jo_ko_ro(id: int) -> list[int] {
    xk: int = __mem_load_i64(wrapping_add(jo_p(id), 144));
    if xk == 0 {
        return _KO_EMPTY;
    }
    return _jx_ko_ro(_JO_EXTS[xk]);
}

"""`key_order` for WRITE access, materializing it on first dict-mode store."""
def:pub jo_ko_rw(id: int) -> list[int] {
    kw_x: JSObjectExt = jo_ext_rw(id);
    kw_k: list[int] | None = kw_x.key_order;
    if kw_k is not None {
        return kw_k;
    }
    k: list[int] = [];
    kw_x.key_order = k;
    return k;
}

"""This object's accessor table, materialized on first use."""
def _jo_ensure_accessors(id: int) -> AccessorTable {
    ea_x: JSObjectExt = jo_ext_rw(id);
    ea_a: AccessorTable | None = ea_x.accessors;
    if ea_a is not None {
        return ea_a;
    }
    t: AccessorTable = AccessorTable(
        getters={}, setters={}, enumerable={}, configurable={}
    );
    ea_x.accessors = t;
    return t;
}

"""The object's accessor table for reading, the shared empty one when it has
none (never mutate it)."""
def:pub jo_acc_ro(id: int, empty: AccessorTable) -> AccessorTable {
    xa: int = __mem_load_i64(wrapping_add(jo_p(id), 144));
    if xa == 0 {
        return empty;
    }
    return _jx_acc_ro(_JO_EXTS[xa], empty);
}

def _jx_acc_ro(x: JSObjectExt, empty: AccessorTable) -> AccessorTable {
    if x.accessors is not None {
        return x.accessors;
    }
    return empty;
}

"""The accessor table for writing (materialized on the first install)."""
def:pub jo_acc_rw(id: int) -> AccessorTable {
    return _jo_ensure_accessors(id);
}

# ── former JSObject methods ─────────────────────────────────────────────────

# ── Generational write barrier (docs/GENERATIONAL_GC.md §4.4) ─────────
# oid is the row's own table id (set by _obj_alloc). A reference stored
# into an old object (FLAG_OLD) puts it in the remembered set, once per
# cycle (FLAG_REMEMBERED); a young object pays one flag test.

"""Barrier for storing `v` into this object."""
def:pub jo_wb(id: int, v: JSValue) -> None {
    jo_wb_p(jo_p(id), v);
}

"""Barrier for a store whose values are not at hand (several elements,
the prototype link): remember an old object unconditionally."""
def:pub jo_wb_all(id: int) -> None {
    wa_p: int = jo_p(id);
    wa_f: int = __mem_load_i64(wrapping_add(wa_p, 104));
    if (wa_f & (FLAG_OLD | FLAG_REMEMBERED)) == FLAG_OLD {
        __mem_store_i64(wrapping_add(wa_p, 104), wa_f | FLAG_REMEMBERED);
        gc_rem_obj(__mem_load_i64(wrapping_add(wa_p, 112)));
    }
}

# ── Property slots ─────────────────────────────────────────────────────
# sn slots: 0..3 in the row (s0..s3), 4.. in one raw buffer of 8-byte
# words, [unused][cap][v4 .. v(cap+3)]; sp = 0 means no overflow slots.
# JSValues are tagged ints, so neither needs refcounting. An object with at
# most four properties (every array: marker + length) has no buffer — no
# allocation, and reading a property touches the row only. The buffer is
# freed by sclear (dict conversion, large rows at sweep); a swept small
# row keeps it for the next object (sreset only zeroes sn).

"""Number of slots in use."""
def:pub jo_slen(id: int) -> int {
    return __mem_load_i64(wrapping_add(jo_p(id), 24));
}

"""Slot i, 0 <= i < slen(). Unchecked unless JAC_SLOT_CHECK=1."""
def:pub jo_sget(id: int, i: int) -> JSValue {
    sg_p: int = jo_p(id);
    if _SLOT_CHECK != 0 {
        _slot_check(__mem_load_i64(wrapping_add(sg_p, 24)), i, "read");
    }
    if i < 4 {
        return __mem_load_i64(wrapping_add(sg_p, wrapping_add(32, wrapping_mul(i, 8))));
    }
    return __mem_load_i64(
        wrapping_add(__mem_load_i64(wrapping_add(sg_p, 64)), wrapping_add(wrapping_mul(i, 8), -16))
    );
}

"""Store v in slot i, 0 <= i < slen()."""
def:pub jo_sset(id: int, i: int, v: JSValue) -> None {
    ss_p: int = jo_p(id);
    if _SLOT_CHECK != 0 {
        _slot_check(__mem_load_i64(wrapping_add(ss_p, 24)), i, "write");
    }
    jo_wb_p(ss_p, v);
    if i < 4 {
        __mem_store_i64(wrapping_add(ss_p, wrapping_add(32, wrapping_mul(i, 8))), v);
        return;
    }
    __mem_store_i64(
        wrapping_add(__mem_load_i64(wrapping_add(ss_p, 64)), wrapping_add(wrapping_mul(i, 8), -16)),
        v
    );
}

"""Append v as the new last slot; the buffer's capacity grows 4, 8, 16, ..."""
def:pub jo_spush(id: int, v: JSValue) -> None {
    sp_p: int = jo_p(id);
    jo_wb_p(sp_p, v);
    sp_n: int = __mem_load_i64(wrapping_add(sp_p, 24));
    if sp_n < 4 {
        __mem_store_i64(wrapping_add(sp_p, wrapping_add(32, wrapping_mul(sp_n, 8))), v);
        __mem_store_i64(wrapping_add(sp_p, 24), wrapping_add(sp_n, 1));
        return;
    }
    sp_o: int = sp_n - 4;
    sp_b: int = __mem_load_i64(wrapping_add(sp_p, 64));
    sp_c: int = 0;
    if sp_b != 0 {
        sp_c = __mem_load_i64(wrapping_add(sp_b, 8));
    }
    if sp_o >= sp_c {
        sp_nc: int = 4;
        if sp_c > 0 {
            sp_nc = sp_c * 2;
        }
        sp_new: int = realloc(sp_b, 16 + sp_nc * 8);
        if sp_new == 0 {
            _slot_oom(16 + sp_nc * 8);
        }
        gc_young_note((sp_nc - sp_c) * 8 + (16 if sp_c == 0 else 0));
        __mem_store_i64(wrapping_add(sp_new, 8), sp_nc);
        __mem_store_i64(wrapping_add(sp_p, 64), sp_new);
        sp_b = sp_new;
        if sp_nc > 4 {
            __mem_store_i64(
                wrapping_add(sp_p, 104), __mem_load_i64(wrapping_add(sp_p, 104)) | FLAG_SLOTS_BIG
            );
        }
    }
    __mem_store_i64(wrapping_add(sp_b, wrapping_add(16, wrapping_mul(sp_o, 8))), v);
    __mem_store_i64(wrapping_add(sp_p, 24), wrapping_add(sp_n, 1));
}

"""Drop every slot, keeping the buffer for this row's next object."""
def:pub jo_sreset(id: int) -> None {
    jo_set_sn(id, 0);
}

"""Slot capacity: the four in the row plus the buffer's."""
def:pub jo_scap(id: int) -> int {
    if jo_sp(id) == 0 {
        return 4;
    }
    return 4 + read_u64(jo_sp(id), 8);
}

"""Give back unused buffer capacity (GC sweep, live objects). Capacity grows
4, 8, 16, ... as properties are added, so a 13-property object carried 7
empty slots for as long as it lived; a later add just grows it again."""
def:pub jo_strim(id: int) -> None {
    if jo_sp(id) == 0 {
        return;
    }
    st_n: int = 0;
    if jo_sn(id) > 4 {
        st_n = jo_sn(id) - 4;
    }
    if read_u64(jo_sp(id), 8) - st_n < 3 {
        return;
    }
    if st_n == 0 {
        free(jo_sp(id));
        jo_set_sp(id, 0);
        jo_set_cell_flags(id, jo_cell_flags(id) & ~FLAG_SLOTS_BIG);
        return;
    }
    st_new: int = realloc(jo_sp(id), 16 + st_n * 8);
    if st_new == 0 {
        return;
    }
    write_i64(st_new, 8, st_n);
    jo_set_sp(id, st_new);
    if st_n <= 4 {
        jo_set_cell_flags(id, jo_cell_flags(id) & ~FLAG_SLOTS_BIG);
    }
}

"""Drop every slot and free the buffer."""
def:pub jo_sclear(id: int) -> None {
    jo_set_sn(id, 0);
    if jo_sp(id) != 0 {
        free(jo_sp(id));
        jo_set_sp(id, 0);
        jo_set_cell_flags(id, jo_cell_flags(id) & ~FLAG_SLOTS_BIG);
    }
}

"""Binary kind (BINARY_KIND_*), 0 for an ordinary object."""
def:pub jo_bkind(id: int) -> int {
    return jo_binary_kind(id);
}

"""Binary backing-store slot, -1 when there is none."""
def:pub jo_bslot(id: int) -> int {
    return jo_binary_slot(id);
}

def:pub jo_set_bkind(id: int, k: int) -> None {
    jo_set_binary_kind(id, k);
}

def:pub jo_set_bslot(id: int, s: int) -> None {
    jo_set_binary_slot(id, s);
}

"""Element `i` of the dense elements, or the hole when there are none or
`i` is past them (a hole element is the hole too)."""
def:pub jo_elem_or_hole(id: int, i: int) -> JSValue {
    eh_e: int = __mem_load_i64(wrapping_add(jo_p(id), 128));
    if eh_e == 0 or i < 0 or i >= __mem_load_i64(eh_e) {
        return jsv_hole();
    }
    return __mem_load_i64(wrapping_add(eh_e, wrapping_add(16, wrapping_mul(i, 8))));
}

"""Own element `dix` when `dix` >= 0 (the array index the key names) and
it is present, else the own data property `key`, else the hole: one
level of js_object_get."""
def:pub jo_own_elem_or_data(id: int, key: int, dix: int) -> JSValue {
    if dix >= 0 and __mem_load_i64(wrapping_add(jo_p(id), 120)) != ELEMS_NONE {
        oe_v: JSValue = jo_elem_or_hole(id, dix);
        if not jsv_is_hole(oe_v) {
            return oe_v;
        }
    }
    return jo_get_own_data_or_hole(id, key);
}

"""An own present element `dix` (>= 0, see own_elem_or_data) or an own
property `key` in the shape / property map; the accessor side tables are
the caller's."""
def:pub jo_has_own_plain(id: int, key: int, dix: int) -> bool {
    if dix >= 0 and dix < jo_elen(id) and not jsv_is_hole(jo_eget(id, dix)) {
        return True;
    }
    return jo_has_key(id, key);
}

"""One level of js_object_get_ordinary: the slot of own data property
`key` (>= 0), -1 when a shape-mode object without accessor tables does not
have it, -2 when the read is not ordinary here (a class / binary / dense
/ namespace / mapped-arguments object, or `key` is an accessor), -3 for a
property map and -4 when there are accessor tables — both read by the
caller. A String wrapper's `length` / index keys are the caller's too."""
def:pub jo_ord_slot(id: int, key: int) -> int {
    if jo_class_id(id) != 0
        or jo_bkind(id) != 0
        or jo_elems_kind(id) != ELEMS_NONE
        or (jo_cell_flags(id) & (FLAG_MODULE_NS | FLAG_MAPPED_ARGS)) != 0 {
        return -2;
    }
    if jo_has_acc(id) {
        return -4;
    }
    if jo_mode(id) != MAP_MODE_SHAPE {
        return -3;
    }
    os_p: int = shape_lookup(jo_shape_id(id), key);
    if os_p < 0 {
        return -1;
    }
    if (os_p & SHAPE_ATTR_ACCESSOR) != 0 {
        return -2;
    }
    return os_p // 16;
}

"""The property-IC hit test and read in one: slots[si] when this is an
ordinary shape-mode object of shape `sid` (the js_object_ic_shape
conditions), else the hole."""
def:pub jo_ic_slot(id: int, sid: int, si: int) -> JSValue {
    ic_p: int = jo_p(id);
    if __mem_load_i64(wrapping_add(ic_p, 80)) != 0
        or __mem_load_i64(wrapping_add(ic_p, 72)) != MAP_MODE_SHAPE
        or __mem_load_i64(wrapping_add(ic_p, 16)) != sid {
        return jsv_hole();
    }
    if (__mem_load_i64(wrapping_add(ic_p, 104)) & (FLAG_MODULE_NS | FLAG_IS_GLOBAL)) != 0 {
        return jsv_hole();
    }
    return jo_sget(id, si);
}

"""The SET-IC hit test and write in one (see ic_slot); False when the
shape does not match."""
def:pub jo_ic_slot_set(id: int, sid: int, si: int, val: JSValue) -> bool {
    if jo_class_id(id) != 0 or jo_mode(id) != MAP_MODE_SHAPE or jo_shape_id(id) != sid {
        return False;
    }
    if (jo_cell_flags(id) & (FLAG_MODULE_NS | FLAG_IS_GLOBAL)) != 0 {
        return False;
    }
    jo_sset(id, si, val);
    return True;
}

# ── Dense elements (P4) ────────────────────────────────────────────────
# One raw buffer of 8-byte words, [len][cap][e0 .. e(cap-1)], laid out like
# the slots; ep = 0 means none. (A list[JSValue] cost a 64-byte list object
# plus a doubling buffer per array, ~2.4M arrays in a vite build.)

"""Number of dense elements."""
def:pub jo_elen(id: int) -> int {
    el_e: int = __mem_load_i64(wrapping_add(jo_p(id), 128));
    if el_e == 0 {
        return 0;
    }
    return __mem_load_i64(el_e);
}

"""Element i, 0 <= i < elen(). Unchecked unless JAC_SLOT_CHECK=1."""
def:pub jo_eget(id: int, i: int) -> JSValue {
    eg_e: int = __mem_load_i64(wrapping_add(jo_p(id), 128));
    if _SLOT_CHECK != 0 {
        _slot_check(jo_elen(id), i, "element read");
    }
    return __mem_load_i64(wrapping_add(eg_e, wrapping_add(16, wrapping_mul(i, 8))));
}

"""Store v as element i, 0 <= i < elen()."""
def:pub jo_eset(id: int, i: int, v: JSValue) -> None {
    es_p: int = jo_p(id);
    if _SLOT_CHECK != 0 {
        _slot_check(jo_elen(id), i, "element write");
    }
    jo_wb_p(es_p, v);
    __mem_store_i64(
        wrapping_add(__mem_load_i64(wrapping_add(es_p, 128)), wrapping_add(16, wrapping_mul(i, 8))), v
    );
}

"""Append v as the new last element; capacity grows 4, 8, 16, ..."""
def:pub jo_epush(id: int, v: JSValue) -> None {
    ep_p: int = jo_p(id);
    jo_wb_p(ep_p, v);
    ep_b: int = __mem_load_i64(wrapping_add(ep_p, 128));
    ep_n: int = 0;
    ep_c: int = 0;
    if ep_b != 0 {
        ep_n = __mem_load_i64(ep_b);
        ep_c = __mem_load_i64(wrapping_add(ep_b, 8));
    }
    if ep_n >= ep_c {
        ep_nc: int = 4;
        if ep_c > 0 {
            ep_nc = ep_c * 2;
        }
        ep_new: int = realloc(ep_b, 16 + ep_nc * 8);
        if ep_new == 0 {
            _slot_oom(16 + ep_nc * 8);
        }
        gc_young_note((ep_nc - ep_c) * 8 + (16 if ep_c == 0 else 0));
        __mem_store_i64(ep_new, ep_n);
        __mem_store_i64(wrapping_add(ep_new, 8), ep_nc);
        __mem_store_i64(wrapping_add(ep_p, 128), ep_new);
        ep_b = ep_new;
    }
    __mem_store_i64(wrapping_add(ep_b, wrapping_add(16, wrapping_mul(ep_n, 8))), v);
    __mem_store_i64(ep_b, wrapping_add(ep_n, 1));
}

"""Make `vals` the elements of an object that has none, in a buffer of
exactly their size; ELEMS_HOLEY when one of them is the hole, else
ELEMS_DENSE (what an epush per element builds, without the regrowth)."""
def:pub jo_einit(id: int, vals: list[JSValue]) -> int {
    jo_wb_all(id);
    ei_n: int = len(vals);
    if ei_n == 0 {
        return ELEMS_DENSE;
    }
    ei_p: int = realloc(jo_ep(id), 16 + ei_n * 8);
    if ei_p == 0 {
        _slot_oom(16 + ei_n * 8);
    }
    gc_young_note(16 + ei_n * 8);
    write_i64(ei_p, 0, ei_n);
    write_i64(ei_p, 8, ei_n);
    ei_kind: int = ELEMS_DENSE;
    ei_k: int = 0;
    while ei_k < ei_n {
        ei_v: JSValue = vals[ei_k];
        if jsv_is_hole(ei_v) {
            ei_kind = ELEMS_HOLEY;
        }
        write_i64(ei_p, 16 + ei_k * 8, ei_v);
        ei_k = ei_k + 1;
    }
    jo_set_ep(id, ei_p);
    return ei_kind;
}

"""einit of vals[off .. off+n) (NEWARRAY's registers, no slice list)."""
def:pub jo_einit_range(id: int, vals: list[JSValue], off: int, n: int) -> int {
    er_r: int = jo_p(id);
    jo_wb_all(id);
    if n == 0 {
        return ELEMS_DENSE;
    }
    er_p: int = __mem_load_i64(wrapping_add(er_r, 128));
    if er_p == 0 or __mem_load_i64(wrapping_add(er_p, 8)) < n {
        er_p = realloc(er_p, 16 + n * 8);
        if er_p == 0 {
            _slot_oom(16 + n * 8);
        }
        gc_young_note(16 + n * 8);
        __mem_store_i64(wrapping_add(er_p, 8), n);
    }
    # (a kept buffer that fits is filled in place)
    __mem_store_i64(er_p, n);
    # vals[off .. off+n) (the caller's registers) read in place
    er_src: int = wrapping_add(__list_data_ptr(vals), wrapping_mul(off, 8));
    er_kind: int = ELEMS_DENSE;
    er_k: int = 0;
    while er_k < n {
        er_v: JSValue = __mem_load_i64(wrapping_add(er_src, wrapping_mul(er_k, 8)));
        if jsv_is_hole(er_v) {
            er_kind = ELEMS_HOLEY;
        }
        __mem_store_i64(wrapping_add(er_p, wrapping_add(16, wrapping_mul(er_k, 8))), er_v);
        er_k = er_k + 1;
    }
    __mem_store_i64(wrapping_add(er_r, 128), er_p);
    return er_kind;
}

"""Remove element 0, moving the rest down one; elen() must be > 0."""
def:pub jo_eshift(id: int) -> None {
    es_n: int = read_u64(jo_ep(id), 0);
    if es_n > 1 {
        memmove(jo_ep(id) + 16, jo_ep(id) + 24, (es_n - 1) * 8);
    }
    write_i64(jo_ep(id), 0, es_n - 1);
}

"""Drop every element and free the buffer."""
def:pub jo_eclear(id: int) -> None {
    if jo_ep(id) != 0 {
        free(jo_ep(id));
        jo_set_ep(id, 0);
    }
}

"""Give back unused element capacity (GC sweep, live arrays); see strim."""
def:pub jo_etrim(id: int) -> None {
    if jo_ep(id) == 0 {
        return;
    }
    et_n: int = read_u64(jo_ep(id), 0);
    if et_n != 0 and read_u64(jo_ep(id), 8) - et_n < 3 {
        return;
    }
    if et_n == 0 {
        free(jo_ep(id));
        jo_set_ep(id, 0);
        return;
    }
    et_new: int = realloc(jo_ep(id), 16 + et_n * 8);
    if et_new == 0 {
        return;
    }
    write_i64(et_new, 8, et_n);
    jo_set_ep(id, et_new);
}
# ── Packed cell_flags bool accessors (P5) ──────────────────────────────
"""[[Extensible]] — false once FLAG_NON_EXTENSIBLE is set (JS one-way)."""
def:pub jo_is_ext(id: int) -> bool {
    return (__mem_load_i64(wrapping_add(jo_p(id), 104)) & FLAG_NON_EXTENSIBLE) == 0;
}

"""Mark [[PreventExtensions]] (one-way; never cleared on a live object)."""
def:pub jo_set_non_ext(id: int) {
    jo_set_cell_flags(id, jo_cell_flags(id) | FLAG_NON_EXTENSIBLE);
}

"""True for a mapped `arguments` exotic object (parameter-slot aliasing)."""
def:pub jo_mapped_args(id: int) -> bool {
    return (jo_cell_flags(id) & FLAG_MAPPED_ARGS) != 0;
}

"""Mark this object a mapped `arguments` exotic."""
def:pub jo_set_mapped_args(id: int) {
    jo_set_cell_flags(id, jo_cell_flags(id) | FLAG_MAPPED_ARGS);
}

"""True for any (mapped or unmapped) `arguments` object."""
def:pub jo_arguments_obj(id: int) -> bool {
    return (jo_cell_flags(id) & FLAG_IS_ARGUMENTS) != 0;
}

"""Mark this object an `arguments` object."""
def:pub jo_set_arguments(id: int) {
    jo_set_cell_flags(id, jo_cell_flags(id) | FLAG_IS_ARGUMENTS);
}

"""DATA-ONLY shape→dict conversion (no-op in dict mode).

INVARIANT: must never run on a map holding SHAPE_ATTR_ACCESSOR entries —
accessor getter/setter slots live here but their dict-mode home (the
JSObject accessor side-dicts) is out of reach, so this would corrupt them
into data properties. The only correct converter for a map that may hold
accessors is JSObject.pm_ensure_dict(); every jsobject.na.jac entry point
that can face an accessor converts at the OBJECT level first, which is
what makes the internal delete() backstop below safe."""
def:pub jo_ensure_dict(id: int) -> None {
    if jo_mode(id) != MAP_MODE_SHAPE {
        return;
    }
    # Slots are about to go away: invalidate inherited-read ICs holding one.
    if (jo_cell_flags(id) & FLAG_IS_PROTO) != 0 {
        proto_epoch_bump();
    }
    ks: list[int] = shape_keys(jo_shape_id(id));
    ks_n: int = shape_key_count(jo_shape_id(id));
    ei: int = 0;
    while ei < ks_n {
        ek: int = ks[ei];
        packed: int = shape_lookup(jo_shape_id(id), ek);
        if packed >= 0 {
            jo_ent_rw(id)[ek] = JSProperty(
                key=ek,
                value=jo_sget(id, packed // 16),
                writable=(packed & PROP_WRITABLE) != 0,
                enumerable=(packed & PROP_ENUMERABLE) != 0,
                configurable=(packed & PROP_CONFIGURABLE) != 0,
                deleted=False
            );
            jo_ko_rw(id).append(ek);
        }
        ei = ei + 1;
    }
    jo_sclear(id);
    jo_set_shape_id(id, 0);
    jo_set_mode(id, MAP_MODE_DICT);
}

"""Return the value for key, or JSValue{tag=Undefined} if not found.

Accessor entries read as undefined — parity with dict mode, where
accessor-only keys have no `entries` row (getter dispatch is the VM's
job, before it ever reaches this data path)."""
def:pub jo_get(id: int, key: int) -> JSValue {
    if jo_mode(id) == MAP_MODE_SHAPE {
        packed_g: int = shape_lookup(jo_shape_id(id), key);
        if packed_g < 0 {
            return js_undefined();
        }
        if (packed_g & SHAPE_ATTR_ACCESSOR) != 0 {
            return js_undefined();
        }
        return jo_sget(id, packed_g // 16);
    }
    ent_g: dict[int, JSProperty] = jo_ent_ro(id);
    if key in ent_g {
        return ent_g[key].value;
    }
    return js_undefined();
}

"""Return the full JSProperty for key, or a sentinel (key=0, deleted=True) if not found.

Shape mode materializes a fresh JSProperty per hit (accepted through
Phase 4; Phase 5 adds non-materializing accessors for the hot paths)."""
def:pub jo_get_property(id: int, key: int) -> JSProperty {
    if jo_mode(id) == MAP_MODE_SHAPE {
        packed_p: int = shape_lookup(jo_shape_id(id), key);
        # Accessor entries report not-found here (dict parity: no entries
        # row) — descriptor readers use the accessor-specific APIs.
        if packed_p >= 0 and (packed_p & SHAPE_ATTR_ACCESSOR) != 0 {
            packed_p = -1;
        }
        if packed_p >= 0 {
            return JSProperty(
                key=key,
                value=jo_sget(id, packed_p // 16),
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
    ent_gp: dict[int, JSProperty] = jo_ent_ro(id);
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
def:pub jo_get_own_data_or_hole(id: int, key: int) -> JSValue {
    go_p: int = jo_p(id);
    if __mem_load_i64(wrapping_add(go_p, 72)) == MAP_MODE_SHAPE {
        packed_o: int = shape_lookup(__mem_load_i64(wrapping_add(go_p, 16)), key);
        if packed_o < 0 or (packed_o & SHAPE_ATTR_ACCESSOR) != 0 {
            return jsv_hole();
        }
        go_i: int = packed_o >> 4;
        if go_i < 4 {
            return __mem_load_i64(wrapping_add(go_p, wrapping_add(32, wrapping_mul(go_i, 8))));
        }
        return __mem_load_i64(
            wrapping_add(__mem_load_i64(wrapping_add(go_p, 64)), wrapping_add(wrapping_mul(go_i, 8), -16))
        );
    }
    return _jo_own_data_dict(id, key);
}

"""get_own_data_or_hole's dict-mode half, kept out of the shape-mode
path: its owned map local would register the whole method for unwind."""
def _jo_own_data_dict(id: int, key: int) -> JSValue {
    ent_o: dict[int, JSProperty] = jo_ent_ro(id);
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
def:pub jo_has_own_data(id: int, key: int) -> bool {
    if jo_mode(id) == MAP_MODE_SHAPE {
        packed_h: int = shape_lookup(jo_shape_id(id), key);
        if packed_h < 0 {
            return False;
        }
        if (packed_h & SHAPE_ATTR_ACCESSOR) != 0 {
            return False;
        }
        return True;
    }
    return key in jo_ent_ro(id);
}

"""Insert or update a property; flags is a PROP_* bitmask.

Returns 0 on success, -1 when the shape path cannot express the write
(accessor kind conflict, un-replayable attrs change, transition failure):
the caller must run JSObject.pm_ensure_dict() and retry — set() never
converts internally because a map holding accessors can only be converted
at the object level (see ensure_dict's invariant)."""
def:pub jo_set(id: int, key: int, value: JSValue, flags: int) -> int {
    if jo_mode(id) == MAP_MODE_SHAPE {
        packed_s: int = shape_lookup(jo_shape_id(id), key);
        if packed_s >= 0 {
            if (packed_s & SHAPE_ATTR_ACCESSOR) != 0 {
                return -1;
            }
            if (packed_s & 15) == (flags & 7) {
                jo_sset(id, packed_s // 16, value);
                return 0;
            }
            # Attribute change on an existing key: replay the chain with
            # the new attrs — slot layout is preserved (same key order and
            # spans), so slots stays valid and only shape_id moves.
            nsid_s: int = shape_change_attrs(jo_shape_id(id), key, flags & 7);
            if nsid_s >= 0 {
                jo_set_shape_id(id, nsid_s);
                jo_sset(id, packed_s // 16, value);
                return 0;
            }
            return -1;
        }
        child: int = shape_transition_add(jo_shape_id(id), key, flags & 7);
        if child > 0 {
            # Slot-index invariant: this map only ever follows span-1
            # transitions from its own shape, so the new key's slot is
            # exactly len(slots).
            jo_set_shape_id(id, child);
            jo_spush(id, value);
            jo_set_version(id, jo_version(id) + 1);  # key add → invalidate ICs
            if key < 0 or key >= 1000000 {
                jo_set_brand(id, jo_brand(id) | brand_bit_for_key(key));
            }
            # A new key on a prototype can shadow an inherited one an IC cached.
            if (jo_cell_flags(id) & FLAG_IS_PROTO) != 0 {
                proto_epoch_bump();
            }
            return 0;
        }
        return -1;
    }
    return _jo_set_dict(id, key, value, flags);
}

"""set's dict-mode half (its map and list locals would register the
shape-mode path for unwind too)."""
def _jo_set_dict(id: int, key: int, value: JSValue, flags: int) -> int {
    w: bool = (flags & PROP_WRITABLE) != 0;
    e: bool = (flags & PROP_ENUMERABLE) != 0;
    c: bool = (flags & PROP_CONFIGURABLE) != 0;
    ent_s: dict[int, JSProperty] = jo_ent_rw(id);  # materialize dict storage
    if key not in ent_s {
        # A delete leaves the id parked in key_order (removing it eagerly
        # would be O(n) per delete). Re-adding the key must not append a
        # SECOND copy — the key would then enumerate twice. Scan only when
        # key_order actually holds more ids than there are live entries,
        # i.e. only when some delete has left slack; in the common
        # never-deleted case this is a single length compare.
        ko_s: list[int] = jo_ko_rw(id);
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
            jo_ext_rw(id).key_order = purged;
            ko_s = purged;  # keep local in sync with the reassigned field
        }
        ko_s.append(key);
        jo_set_version(id, jo_version(id) + 1);  # shape change → invalidate ICs
        if key < 0 or key >= 1000000 {
            jo_set_brand(id, jo_brand(id) | brand_bit_for_key(key));
        }
        if (jo_cell_flags(id) & FLAG_IS_PROTO) != 0 {
            proto_epoch_bump();
        }
    }
    jo_wb(id, value);
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
def:pub jo_delete(id: int, key: int) -> bool {
    if jo_mode(id) == MAP_MODE_SHAPE {
        if not shape_has(jo_shape_id(id), key) {
            return False;
        }
        # Deletes are the shape worst case: convert, then dict-delete.
        jo_ensure_dict(id);
    }
    ent_d: dict[int, JSProperty] = jo_ent_ro(id);
    if key in ent_d {
        prop: JSProperty = ent_d[key];
        if not prop.deleted {
            del ent_d[key];
            jo_set_version(id, jo_version(id) + 1);  # shape change → invalidate ICs
            if key < 0 or key >= 1000000 {
                jo_set_brand(id, jo_brand(id) - (jo_brand(id) & brand_bit_for_key(key)));
            }
            if (jo_cell_flags(id) & FLAG_IS_PROTO) != 0 {
                proto_epoch_bump();
            }
            return True;
        }
    }
    return False;
}

"""Return True if the key exists in the map."""
def:pub jo_has_key(id: int, key: int) -> bool {
    hk_p: int = jo_p(id);
    if __mem_load_i64(wrapping_add(hk_p, 72)) == MAP_MODE_SHAPE {
        return shape_has(__mem_load_i64(wrapping_add(hk_p, 16)), key);
    }
    return key in jo_ent_ro(id);
}

"""Return list of enumerable key IDs in insertion order."""
def:pub jo_keys(id: int) -> list[int] {
    result: list[int] = [];
    if jo_mode(id) == MAP_MODE_SHAPE {
        ks_e: list[int] = shape_keys(jo_shape_id(id));
        ks_e_n: int = shape_key_count(jo_shape_id(id));
        ei: int = 0;
        while ei < ks_e_n {
            packed_k: int = shape_lookup(jo_shape_id(id), ks_e[ei]);
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
    ko_k: list[int] = jo_ko_ro(id);
    ent_k: dict[int, JSProperty] = jo_ent_ro(id);
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
def:pub jo_all_keys(id: int) -> list[int] {
    result: list[int] = [];
    if jo_mode(id) == MAP_MODE_SHAPE {
        # Fresh copy — shape_keys() returns the shared shape cache, which
        # callers must never mutate.
        ks_a: list[int] = shape_keys(jo_shape_id(id));
        ks_a_n: int = shape_key_count(jo_shape_id(id));
        ai: int = 0;
        while ai < ks_a_n {
            result.append(ks_a[ai]);
            ai = ai + 1;
        }
        return result;
    }
    ko_a: list[int] = jo_ko_ro(id);
    ent_a: dict[int, JSProperty] = jo_ent_ro(id);
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
def:pub jo_ensure_sparse(id: int) -> None {
    if jo_elems_kind(id) == ELEMS_NONE {
        return;
    }
    jo_pm_ensure_dict(id);
    es_i: int = 0;
    es_n: int = jo_elen(id);
    while es_i < es_n {
        es_v: JSValue = jo_eget(id, es_i);
        if not jsv_is_hole(es_v) {
            es_k: int = _IDX_INTERN_CB(es_i);
            if es_k >= 0 {
                jo_set(id, es_k, es_v, PROP_DEFAULT);
            }
        }
        es_i = es_i + 1;
    }
    jo_eclear(id);
    jo_set_elems_kind(id, ELEMS_NONE);
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
def:pub jo_pm_ensure_dict(id: int) -> None {
    if jo_mode(id) != MAP_MODE_SHAPE {
        return;
    }
    # Slots are about to go away: invalidate inherited-read ICs holding one.
    if (jo_cell_flags(id) & FLAG_IS_PROTO) != 0 {
        proto_epoch_bump();
    }
    pes: list[int] = shape_keys(jo_shape_id(id));
    pes_n: int = shape_key_count(jo_shape_id(id));
    pi: int = 0;
    while pi < pes_n {
        pk: int = pes[pi];
        packed: int = shape_lookup(jo_shape_id(id), pk);
        if packed >= 0 {
            if (packed & SHAPE_ATTR_ACCESSOR) != 0 {
                at: AccessorTable = _jo_ensure_accessors(id);
                at.getters[pk] = jo_sget(id, packed // 16);
                at.setters[pk] = jo_sget(id, packed // 16 + 1);
                at.enumerable[pk] = (packed & PROP_ENUMERABLE) != 0;
                at.configurable[pk] = (packed & PROP_CONFIGURABLE) != 0;
                jo_ko_rw(id).append(pk);
            } else {
                jo_ent_rw(id)[pk] = JSProperty(
                    key=pk,
                    value=jo_sget(id, packed // 16),
                    writable=(packed & PROP_WRITABLE) != 0,
                    enumerable=(packed & PROP_ENUMERABLE) != 0,
                    configurable=(packed & PROP_CONFIGURABLE) != 0,
                    deleted=False
                );
                jo_ko_rw(id).append(pk);
            }
        }
        pi = pi + 1;
    }
    jo_sclear(id);
    jo_set_shape_id(id, 0);
    jo_set_mode(id, MAP_MODE_DICT);
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
