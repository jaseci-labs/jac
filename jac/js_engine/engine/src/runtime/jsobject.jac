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

import from engine.src.runtime.gc_barrier { gc_gen_on, gc_rem_obj, gc_young_note }
import from engine.src.runtime.jsobj_type {
    jo_acc_ro,
    jo_acc_rw,
    jo_all_keys,
    jo_arguments_obj,
    jo_bkind,
    jo_brand,
    jo_bslot,
    jo_cell_flags,
    jo_class_id,
    jo_count,
    jo_delete,
    jo_drop_ext,
    jo_eclear,
    jo_eget,
    jo_einit,
    jo_einit_range,
    jo_elem_or_hole,
    jo_elems_kind,
    jo_elen,
    jo_ensure_sparse,
    jo_ent_ro,
    jo_ent_rw,
    jo_ep,
    jo_epush,
    jo_eset,
    jo_eshift,
    jo_ext_rw,
    jo_get,
    jo_get_property,
    jo_has_acc,
    jo_has_ent,
    jo_has_key,
    jo_has_own_data,
    jo_has_own_plain,
    jo_is_ext,
    jo_ko_ro,
    jo_ko_rw,
    jo_mapped_args,
    jo_mode,
    jo_new_id,
    jo_ord_slot,
    jo_own_elem_or_data,
    jo_p,
    jo_pm_ensure_dict,
    jo_prototype_idx,
    jo_s0,
    jo_s1,
    jo_s2,
    jo_s3,
    jo_sclear,
    jo_set,
    jo_set_arguments,
    jo_set_brand,
    jo_set_cell_flags,
    jo_set_elems_kind,
    jo_set_mapped_args,
    jo_set_non_ext,
    jo_set_prototype_idx,
    jo_set_s0,
    jo_set_s1,
    jo_set_s2,
    jo_set_s3,
    jo_set_shape_id,
    jo_set_version,
    jo_sget,
    jo_shape_id,
    jo_slen,
    jo_sp,
    jo_spush,
    jo_sset,
    jo_version,
    jo_wb,
    jo_wb_all
}
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
    jsv_is_cell,
    jsv_cell_kind,
    js_true,
    JS_CELL_KIND_OBJECT,
    JS_CELL_KIND_HTMLDDA,
    JS_CELL_KIND_STRING,
    JS_CELL_KIND_NATIVE
}
import from engine.src.runtime.jsobj_type {
    proto_epoch,
    proto_epoch_bump,
    proto_epoch_bump_gc,
    global_obj_note_write,
    JSProperty,
    JSObjectExt,
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
    FLAG_OLD,
    FLAG_REMEMBERED,
    FLAG_MODULE_NS,
    FLAG_MAPPED_ARGS,
    FLAG_IS_CLASS,
    FLAG_IS_ARGUMENTS,
    FLAG_FROZEN,
    FLAG_SEALED,
    FLAG_NON_EXTENSIBLE,
    FLAG_IS_GLOBAL,
    FLAG_SLOTS_BIG
}
import from engine.src.runtime.shape {
    shape_gate_enabled,
    shape_lookup,
    shape_keys,
    shape_key_count,
    shape_transition_add,
    shape_change_attrs,
    SHAPE_ATTR_ACCESSOR
}
import from engine.src.runtime.realm { Realm, gc_note_alloc, gc_note_alloc_n, gc_mark_byte, objmark_push }
import from engine.src.runtime.mem {
    read_byte,
    write_byte,
    read_u64,
    write_i64,
    str_byte,
    str_nbytes
}
import from engine.src.ffi.libc { getenv, write, calloc, realloc, abort }
import from engine.src.runtime.encoding {
    PROTO_MAX_DEPTH,
    SYMBOL_KEY_BASE,
    BUILTIN_BASE
}
import from engine.src.runtime.jsstring {
    str_intern_index,
    hs_free_n,
    str_from_id,
    str_intern,
    str_intern_lookup,
    str_substr,
    str_id_is_array_index,
    str_id_array_index_value,
    str_id_is_brand_key,
    HEAP_STRING_BASE
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

# gc_gen_on() latched on first use (it is fixed before the first allocation).
glob _OBJ_GEN_ON: int = -1;
# The last [[Prototype]] id _obj_alloc flagged a prototype (0: none).
glob _OBJ_PROTO_NOTED: int = 0;
# Freed object ids: a raw stack of 8-byte ids, _OBJ_FREE_N in use. Only a
# sweep pushes, so between collections the stack only shrinks: the ids
# _obj_alloc handed out since the last collection are the entries at
# [_OBJ_FREE_N, _OBJ_FREE_GC) plus the new ids above _OBJ_COUNT_GC
# (jo_sweep_young). _OBJ_NOTE: allocations not yet accounted (batched).
glob _OBJ_FREE: int = 0,
     _OBJ_FREE_CAP: int = 0,
     _OBJ_FREE_N: int = 0,
     _OBJ_FREE_GC: int = 0,
     _OBJ_COUNT_GC: int = 0,
     _OBJ_NOTE: int = 0;

def _obj_gen -> bool {
    if _OBJ_GEN_ON < 0 {
        _OBJ_GEN_ON = 1 if gc_gen_on() else 0;
    }
    return _OBJ_GEN_ON == 1;
}

"""Mark `prototype_idx` as a prototype (gates the dense-elements index
protector: an index-keyed prop landing on any flagged object clears it).
First time only: also scan for index props it may have acquired BEFORE
becoming a prototype. Amortized once per prototype object."""
def _obj_note_proto(prototype_idx: int) {
    pa_raw: int = prototype_idx;
    jo_set_cell_flags(pa_raw, jo_cell_flags(pa_raw) | FLAG_IS_PROTO);
    if idx_protector_ok() {
        # A Proxy prototype traps EVERY inherited [[Set]]/[[Get]] —
        # no index-key scan can prove it inert.
        if jo_class_id(pa_raw) != 0 {
            idx_protector_clear();
        } elif jo_elems_kind(pa_raw) != ELEMS_NONE and jo_elen(pa_raw) > 0 {
            idx_protector_clear();
        } else {
            for pa_k in jo_all_keys(pa_raw) {
                if _obj_is_array_index_key_id(pa_k) {
                    idx_protector_clear();
                    break;
                }
            }
        }
    }
}

"""JAC_DBG_OBJ=1: the table and free-list sizes every 500000 new ids (out of
_obj_alloc: this str local would make every allocation register an unwind
frame)."""
def _obj_dbg_table(idx: int) -> None {
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
            + str(_OBJ_FREE_N)
            + " live="
            + str(idx - _OBJ_FREE_N)
            + " gc_on="
            + str(_OBJ_REALM.gc_enabled)
            + "\n";
        write(2, odm, str_nbytes(odm));
    }
}

"""Allocate an object record; return its 1-based table id. The common case —
a parked row whose old tenant left no payload, a [[Prototype]] already
flagged (or none), the accounting batch not due — is short enough to inline
where objects are made; everything else is _obj_alloc_full."""
def _obj_alloc(prototype_idx: int) -> int {
    qa_t: int = _OBJ_FREE_N;
    if qa_t > 0
        and _OBJ_NOTE < 31
        and (prototype_idx <= 0 or prototype_idx == _OBJ_PROTO_NOTED) {
        qa_id: int = __mem_load_i64(wrapping_add(_OBJ_FREE, wrapping_mul(qa_t - 1, 8)));
        qa_p: int = jo_p(qa_id);
        qa_e: int = __mem_load_i64(wrapping_add(qa_p, 128));
        if qa_id != _OBJ_PROTO_NOTED
            and (__mem_load_i64(wrapping_add(qa_p, 104)) & (FLAG_IS_PROTO | FLAG_SLOTS_BIG | FLAG_MAPPED_ARGS)) == 0
            and __mem_load_i64(wrapping_add(qa_p, 144)) == 0
            and (qa_e == 0 or __mem_load_i64(wrapping_add(qa_e, 8)) <= 16) {
            _OBJ_FREE_N = qa_t - 1;
            _OBJ_NOTE = _OBJ_NOTE + 1;
            if qa_e != 0 {
                __mem_store_i64(qa_e, 0);  # a kept elements buffer, emptied
            }
            __mem_store_i64(qa_p, prototype_idx);
            __mem_store_i64(wrapping_add(qa_p, 8), 0);  # version
            __mem_store_i64(wrapping_add(qa_p, 16), 0);  # shape_id
            __mem_store_i64(wrapping_add(qa_p, 24), 0);  # sn (a kept buffer stays)
            __mem_store_i64(
                wrapping_add(qa_p, 72), MAP_MODE_SHAPE if shape_gate_enabled() else MAP_MODE_DICT
            );
            __mem_store_i64(wrapping_add(qa_p, 80), 0);  # class_id
            __mem_store_i64(wrapping_add(qa_p, 88), 0);  # binary_kind
            __mem_store_i64(wrapping_add(qa_p, 96), -1);  # binary_slot
            __mem_store_i64(wrapping_add(qa_p, 104), 0);  # cell_flags
            # (oid, word 112: a parked row keeps its own id)
            __mem_store_i64(wrapping_add(qa_p, 120), 0);  # elems_kind
            __mem_store_i64(wrapping_add(qa_p, 136), 0);  # brand
            __mem_store_i8(wrapping_add(_OBJ_REALM.objmark_ptr, wrapping_add(qa_id, -1)), 0);
            return qa_id;
        }
    }
    return _obj_alloc_full(prototype_idx);
}

"""Allocate an object record; return its 1-based table id. A row the GC
parked (free_object_slots) is reused in place: the sweep parks dead rows
without reading them, so the old tenant's payload is released here — a slot
buffer larger than the minimum (FLAG_SLOTS_BIG; a small one is kept for the
new tenant), the elements, the extension record, a mapped-arguments row —
and a freed prototype's id bumps the epoch (inherited-read ICs key on it).
Then the header words are stored through one record address (records are
raw memory, see jsobj_type.jac); a new id's record comes zeroed."""
def _obj_alloc_full(prototype_idx: int) -> int {
    # G0.4: account the allocation (batched: _obj_note_flush)
    _OBJ_NOTE = _OBJ_NOTE + 1;
    if _OBJ_NOTE >= 32 {
        _obj_note_flush();
    }
    # (_OBJ_PROTO_NOTED: the last prototype id flagged; the flag is only ever
    # set, so it holds until that row is reused below)
    if prototype_idx > 0 and prototype_idx != _OBJ_PROTO_NOTED {
        if prototype_idx <= jo_count()
            and (jo_cell_flags(prototype_idx) & FLAG_IS_PROTO) == 0 {
            _obj_note_proto(prototype_idx);
        }
        _OBJ_PROTO_NOTED = prototype_idx;
    }
    oa_mode: int = MAP_MODE_DICT;
    if shape_gate_enabled() {
        oa_mode = MAP_MODE_SHAPE;
    }
    oa_t: int = _OBJ_FREE_N;
    if oa_t > 0 {
        oa_t = oa_t - 1;
        idx: int = __mem_load_i64(wrapping_add(_OBJ_FREE, wrapping_mul(oa_t, 8)));
        _OBJ_FREE_N = oa_t;
        oa_p: int = jo_p(idx);
        if idx == _OBJ_PROTO_NOTED {
            _OBJ_PROTO_NOTED = 0;
        }
        if (__mem_load_i64(wrapping_add(oa_p, 104)) & (FLAG_IS_PROTO | FLAG_SLOTS_BIG | FLAG_MAPPED_ARGS)) != 0
            or __mem_load_i64(wrapping_add(oa_p, 128)) != 0
            or __mem_load_i64(wrapping_add(oa_p, 144)) != 0 {
            _obj_reuse_clean(idx, oa_p);
        }
        __mem_store_i64(oa_p, prototype_idx);
        __mem_store_i64(wrapping_add(oa_p, 8), 0);  # version
        __mem_store_i64(wrapping_add(oa_p, 16), 0);  # shape_id
        __mem_store_i64(wrapping_add(oa_p, 24), 0);  # sn (a kept buffer stays)
        __mem_store_i64(wrapping_add(oa_p, 72), oa_mode);
        __mem_store_i64(wrapping_add(oa_p, 80), 0);  # class_id
        __mem_store_i64(wrapping_add(oa_p, 88), 0);  # binary_kind
        __mem_store_i64(wrapping_add(oa_p, 96), -1);  # binary_slot
        __mem_store_i64(wrapping_add(oa_p, 104), 0);  # cell_flags
        __mem_store_i64(wrapping_add(oa_p, 112), idx);  # oid
        __mem_store_i64(wrapping_add(oa_p, 120), 0);  # elems_kind
        __mem_store_i64(wrapping_add(oa_p, 136), 0);  # brand
        __mem_store_i8(wrapping_add(_OBJ_REALM.objmark_ptr, wrapping_add(idx, -1)), 0);
        return idx;
    }
    return _obj_alloc_new(prototype_idx, oa_mode);
}

"""Account the batched allocations (gc_note_alloc for each, 192 bytes)."""
def _obj_note_flush -> None {
    nf_n: int = _OBJ_NOTE;
    _OBJ_NOTE = 0;
    gc_note_alloc_n(_OBJ_REALM, nf_n, nf_n * 192);
}

"""Double the parked-id stack's capacity."""
def _obj_free_grow -> None {
    fg_cap: int = 4096 if _OBJ_FREE_CAP == 0 else _OBJ_FREE_CAP * 2;
    fg_p: int = realloc(_OBJ_FREE, fg_cap * 8);
    if fg_p == 0 {
        _obj_oom_abort();
    }
    _OBJ_FREE = fg_p;
    _OBJ_FREE_CAP = fg_cap;
}

"""Park object id `id` (a sweep found it dead) for _obj_alloc to reuse."""
def:pub jo_free_push(id: int) -> None {
    if _OBJ_FREE_N >= _OBJ_FREE_CAP {
        fp_cap: int = 4096 if _OBJ_FREE_CAP == 0 else _OBJ_FREE_CAP * 2;
        fp_p: int = realloc(_OBJ_FREE, fp_cap * 8);
        if fp_p == 0 {
            _obj_oom_abort();
        }
        _OBJ_FREE = fp_p;
        _OBJ_FREE_CAP = fp_cap;
    }
    __mem_store_i64(wrapping_add(_OBJ_FREE, wrapping_mul(_OBJ_FREE_N, 8)), id);
    _OBJ_FREE_N = _OBJ_FREE_N + 1;
}

"""Number of parked object ids."""
def:pub jo_free_n -> int {
    return _OBJ_FREE_N;
}

"""A collection ended: the ids handed out from here on are the next young ones."""
def:pub jo_cycle_end -> None {
    _OBJ_FREE_GC = _OBJ_FREE_N;
    _OBJ_COUNT_GC = jo_count();
}

"""The object ids handed out since the last collection (GC verification)."""
def:pub jo_young_ids -> list[int] {
    yi_out: list[int] = [];
    yi_p: int = _OBJ_FREE_N;
    while yi_p < _OBJ_FREE_GC {
        yi_out.append(__mem_load_i64(wrapping_add(_OBJ_FREE, wrapping_mul(yi_p, 8))));
        yi_p = yi_p + 1;
    }
    yi_i: int = _OBJ_COUNT_GC + 1;
    while yi_i <= jo_count() {
        yi_out.append(yi_i);
        yi_i = yi_i + 1;
    }
    return yi_out;
}

"""A minor collection's object sweep over the ids handed out since the last
collection (mark bytes at `mp`, `mlen` of them): an unmarked one (byte 0) is
dead — byte 255 and back on the free stack. The popped stack entries are
compacted in place (the write position never passes the read one). Returns
the number freed."""
def:pub jo_sweep_young(mp: int, mlen: int) -> int {
    sy_freed: int = 0;
    sy_w: int = _OBJ_FREE_N;
    sy_p: int = _OBJ_FREE_N;
    while sy_p < _OBJ_FREE_GC {
        sy_id: int = __mem_load_i64(wrapping_add(_OBJ_FREE, wrapping_mul(sy_p, 8)));
        if sy_id > 0 and sy_id <= mlen
            and __mem_load_i8(wrapping_add(mp, wrapping_add(sy_id, -1))) == 0 {
            __mem_store_i8(wrapping_add(mp, wrapping_add(sy_id, -1)), -1);  # 255: parked
            __mem_store_i64(wrapping_add(_OBJ_FREE, wrapping_mul(sy_w, 8)), sy_id);
            sy_w = sy_w + 1;
            sy_freed = sy_freed + 1;
        }
        sy_p = sy_p + 1;
    }
    _OBJ_FREE_N = sy_w;
    sy_i: int = _OBJ_COUNT_GC + 1;
    sy_n: int = jo_count();
    # (room for every new id first, so the loop stores without a check)
    while sy_i <= sy_n and _OBJ_FREE_N + (sy_n - sy_i + 1) > _OBJ_FREE_CAP {
        _obj_free_grow();
    }
    sy_w = _OBJ_FREE_N;
    while sy_i <= sy_n {
        if sy_i <= mlen and __mem_load_i8(wrapping_add(mp, wrapping_add(sy_i, -1))) == 0 {
            __mem_store_i8(wrapping_add(mp, wrapping_add(sy_i, -1)), -1);  # 255: parked
            __mem_store_i64(wrapping_add(_OBJ_FREE, wrapping_mul(sy_w, 8)), sy_i);
            sy_w = sy_w + 1;
            sy_freed = sy_freed + 1;
        }
        sy_i = sy_i + 1;
    }
    _OBJ_FREE_N = sy_w;
    return sy_freed;
}

"""_obj_alloc's reused row whose old tenant left a payload: a slot buffer
larger than the minimum, elements, an extension record, a mapped-arguments
row; a freed prototype's id bumps the epoch (inherited-read ICs key on it)."""
def _obj_reuse_clean(idx: int, oa_p: int) -> None {
    oa_cf: int = __mem_load_i64(wrapping_add(oa_p, 104));
    if (oa_cf & FLAG_IS_PROTO) != 0 {
        proto_epoch_bump_gc();
    }
    if (oa_cf & FLAG_SLOTS_BIG) != 0 {
        jo_sclear(idx);
    }
    rc_e: int = __mem_load_i64(wrapping_add(oa_p, 128));
    if rc_e != 0 {
        if __mem_load_i64(wrapping_add(rc_e, 8)) <= 16 {
            __mem_store_i64(rc_e, 0);  # a small elements buffer is kept, emptied
        } else {
            jo_eclear(idx);
        }
    }
    if __mem_load_i64(wrapping_add(oa_p, 144)) != 0 {
        jo_drop_ext(idx);
    }
    if (oa_cf & FLAG_MAPPED_ARGS) != 0 and idx in _OBJ_REALM.args_slots {
        del _OBJ_REALM.args_slots[idx];
    }
}

"""_obj_alloc with no parked row: a new id (its record comes zeroed)."""
def _obj_alloc_new(prototype_idx: int, oa_mode: int) -> int {
    idx: int = jo_new_id();  # reserve 0 as null sentinel
    if _OBJDBG != 0 {
        _obj_dbg_table(idx);
    }
    on_p: int = jo_p(idx);
    __mem_store_i64(on_p, prototype_idx);
    __mem_store_i64(wrapping_add(on_p, 72), oa_mode);
    __mem_store_i64(wrapping_add(on_p, 96), -1);  # binary_slot
    __mem_store_i64(wrapping_add(on_p, 112), idx);  # oid
    objmark_push(_OBJ_REALM, 0);  # GC mark byte (a new id is young: above _OBJ_COUNT_GC)
    return idx;
}

"""A fresh ordinary object with [[Prototype]] table id `proto_idx` (-1 =
null) already at the one-property shape `sid` with `v0` in its slot: one
property add from the empty root shape without the transition. `sid` must
be learned from an object built the ordinary way."""
def:pub js_object_new_shaped1(proto_idx: int, sid: int, v0: JSValue) -> JSValue {
    sh1_idx: int = _obj_alloc(proto_idx);
    sh1_p: int = jo_p(sh1_idx);
    __mem_store_i64(wrapping_add(sh1_p, 16), sid);
    __mem_store_i64(wrapping_add(sh1_p, 32), v0);
    __mem_store_i64(wrapping_add(sh1_p, 24), 1);
    __mem_store_i64(wrapping_add(sh1_p, 8), 1);
    return _obj_wrap(sh1_idx);
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
    sh2_p: int = jo_p(sh2_idx);
    __mem_store_i64(wrapping_add(sh2_p, 16), sid);
    __mem_store_i64(wrapping_add(sh2_p, 32), v0);
    __mem_store_i64(wrapping_add(sh2_p, 40), v1);
    __mem_store_i64(wrapping_add(sh2_p, 24), 2);
    __mem_store_i64(wrapping_add(sh2_p, 8), 2);
    return _obj_wrap(sh2_idx);
}

"""The shape of `v` when it is the shape-mode Array js_array_create builds:
the array marker `mk` (slot 0, a data property) then a writable-only
`length` (slot 1), nothing else. -1 otherwise."""
def:pub js_object_array_shape(v: JSValue, mk: int) -> int {
    as_sid: int = js_object_ic_shape(v);
    if as_sid < 0 or jo_mode(jsv_to_table_id(v)) != MAP_MODE_SHAPE {
        return -1;
    }
    if shape_key_count(as_sid) != 2 {
        return -1;
    }
    as_m: int = shape_lookup(as_sid, mk);
    as_l: int = shape_lookup(as_sid, KEY_LENGTH);
    if as_m < 0 or as_m // 16 != 0 or (as_m & SHAPE_ATTR_ACCESSOR) != 0 {
        return -1;
    }
    if as_l < 0 or as_l // 16 != 1 or (as_l & 15) != PROP_WRITABLE {
        return -1;
    }
    return as_sid;
}

"""The Array header of a fresh record at `p` (from _obj_alloc: young, no
slots): shape `sid`, slot 0 the marker (true), slot 1 `length` `len_v`,
version 2 (the two adds), the Array brand."""
def _obj_init_array(p: int, sid: int, len_v: JSValue) -> None {
    __mem_store_i64(wrapping_add(p, 16), sid);
    __mem_store_i64(wrapping_add(p, 32), js_true());
    __mem_store_i64(wrapping_add(p, 40), len_v);
    __mem_store_i64(wrapping_add(p, 24), 2);
    __mem_store_i64(wrapping_add(p, 8), 2);
    __mem_store_i64(wrapping_add(p, 136), BRAND_ARRAY);
}

"""Out of memory for a slot buffer."""
def _obj_oom_abort -> None {
    om_msg: str = "[OBJ] out of memory for a slot buffer\n";
    write(2, om_msg, str_nbytes(om_msg));
    abort();
}

# The values of a literal being born from its template (js_object_new_literal_t),
# a growing scratch buffer. No GC runs while they are copied into the record.
glob _OBJ_LIT_SCRATCH: int = 0,
     _OBJ_LIT_SCRATCH_N: int = 0;

"""Scratch for `n` literal values."""
def _obj_lit_scratch(n: int) -> int {
    if n > _OBJ_LIT_SCRATCH_N {
        _OBJ_LIT_SCRATCH = realloc(_OBJ_LIT_SCRATCH, (n + 4) * 8);
        if _OBJ_LIT_SCRATCH == 0 {
            _obj_oom_abort();
        }
        _OBJ_LIT_SCRATCH_N = n + 4;
    }
    return _OBJ_LIT_SCRATCH;
}

"""js_object_new_literal from a site's template `tmpl` ([n][v0 .. v(n-1)],
the hole where the next value at `src` goes)."""
def:pub js_object_new_literal_t(sid: int, tmpl: int, src: int) -> JSValue {
    nt_n: int = __mem_load_i64(tmpl);
    nt_buf: int = _obj_lit_scratch(nt_n);
    nt_k: int = 0;
    nt_d: int = 0;
    while nt_k < nt_n {
        nt_v: JSValue = __mem_load_i64(wrapping_add(tmpl, wrapping_mul(nt_k + 1, 8)));
        if jsv_is_hole(nt_v) {
            nt_v = __mem_load_i64(wrapping_add(src, wrapping_mul(nt_d, 8)));
            nt_d = nt_d + 1;
        }
        __mem_store_i64(wrapping_add(nt_buf, wrapping_mul(nt_k, 8)), nt_v);
        nt_k = nt_k + 1;
    }
    return js_object_new_literal(sid, nt_buf, nt_n);
}

"""A fresh ordinary object (the `{}` prototype) at shape `sid` with the `n`
values at raw address `src` (8-byte words) in its slots: what `n` define-own
adds from the root shape build (an object-literal site learns `sid` from an
object built that way, vm.jac _obj_lit_make). The hole when objects do not
start in shape mode (the caller then takes the ordinary path)."""
def:pub js_object_new_literal(sid: int, src: int, n: int) -> JSValue {
    if not shape_gate_enabled() {
        return jsv_hole();
    }
    nl_proto: int = -1;
    if jsv_is_object_cell(_ORDINARY_OBJECT_PROTO)
        and jsv_to_table_id(_ORDINARY_OBJECT_PROTO) > 0 {
        nl_proto = jsv_to_table_id(_ORDINARY_OBJECT_PROTO);
    }
    nl_idx: int = 0;
    lq_t: int = _OBJ_FREE_N;
    if lq_t > 0 and _OBJ_NOTE < 31 and (nl_proto <= 0 or nl_proto == _OBJ_PROTO_NOTED) {
        lq_c: int = __mem_load_i64(wrapping_add(_OBJ_FREE, wrapping_mul(lq_t - 1, 8)));
        lq_q: int = jo_p(lq_c);
        lq_e: int = __mem_load_i64(wrapping_add(lq_q, 128));
        if lq_c != _OBJ_PROTO_NOTED
            and (__mem_load_i64(wrapping_add(lq_q, 104)) & (FLAG_IS_PROTO | FLAG_SLOTS_BIG | FLAG_MAPPED_ARGS)) == 0
            and __mem_load_i64(wrapping_add(lq_q, 144)) == 0
            and (lq_e == 0 or __mem_load_i64(wrapping_add(lq_e, 8)) <= 16) {
            _OBJ_FREE_N = lq_t - 1;
            _OBJ_NOTE = _OBJ_NOTE + 1;
            if lq_e != 0 {
                __mem_store_i64(lq_e, 0);  # a kept elements buffer, emptied
            }
            __mem_store_i64(lq_q, nl_proto);
            __mem_store_i64(wrapping_add(lq_q, 8), 0);
            __mem_store_i64(wrapping_add(lq_q, 16), 0);
            __mem_store_i64(wrapping_add(lq_q, 24), 0);
            __mem_store_i64(
                wrapping_add(lq_q, 72), MAP_MODE_SHAPE if shape_gate_enabled() else MAP_MODE_DICT
            );
            __mem_store_i64(wrapping_add(lq_q, 80), 0);
            __mem_store_i64(wrapping_add(lq_q, 88), 0);
            __mem_store_i64(wrapping_add(lq_q, 96), -1);
            __mem_store_i64(wrapping_add(lq_q, 104), 0);
            __mem_store_i64(wrapping_add(lq_q, 120), 0);
            __mem_store_i64(wrapping_add(lq_q, 136), 0);
            __mem_store_i8(wrapping_add(_OBJ_REALM.objmark_ptr, wrapping_add(lq_c, -1)), 0);
            nl_idx = lq_c;
        }
    }
    if nl_idx == 0 {
        nl_idx = _obj_alloc_full(nl_proto);
    }
    nl_p: int = jo_p(nl_idx);
    __mem_store_i64(wrapping_add(nl_p, 16), sid);
    nl_k: int = 0;
    while nl_k < n and nl_k < 4 {
        __mem_store_i64(
            wrapping_add(nl_p, wrapping_add(32, wrapping_mul(nl_k, 8))),
            __mem_load_i64(wrapping_add(src, wrapping_mul(nl_k, 8)))
        );
        nl_k = nl_k + 1;
    }
    if n > 4 {
        # Slots 4.. in one buffer of the capacity the appends would reach
        # (4, 8, 16, ...: jo_spush's growth), reusing a kept one that fits.
        nl_cap: int = 4;
        while nl_cap < n - 4 {
            nl_cap = nl_cap * 2;
        }
        nl_b: int = __mem_load_i64(wrapping_add(nl_p, 64));
        nl_have: int = 0;
        if nl_b != 0 {
            nl_have = __mem_load_i64(wrapping_add(nl_b, 8));
        }
        if nl_have < nl_cap {
            nl_nb: int = realloc(nl_b, 16 + nl_cap * 8);
            if nl_nb == 0 {
                _obj_oom_abort();
            }
            gc_young_note((nl_cap - nl_have) * 8 + (16 if nl_have == 0 else 0));
            __mem_store_i64(wrapping_add(nl_nb, 8), nl_cap);
            __mem_store_i64(wrapping_add(nl_p, 64), nl_nb);
            nl_b = nl_nb;
            if nl_cap > 4 {
                __mem_store_i64(
                    wrapping_add(nl_p, 104), __mem_load_i64(wrapping_add(nl_p, 104)) | FLAG_SLOTS_BIG
                );
            }
        }
        while nl_k < n {
            __mem_store_i64(
                wrapping_add(nl_b, wrapping_add(16, wrapping_mul(nl_k - 4, 8))),
                __mem_load_i64(wrapping_add(src, wrapping_mul(nl_k, 8)))
            );
            nl_k = nl_k + 1;
        }
    }
    __mem_store_i64(wrapping_add(nl_p, 24), nl_k);
    __mem_store_i64(wrapping_add(nl_p, 8), n);
    return _obj_wrap(nl_idx);
}

"""A fresh Array with [[Prototype]] table id `proto_idx`, already at shape
`sid` (js_object_array_shape) with the marker true, `length` `len_v` and
`elements` as its dense elements: what js_array_create's marker add, length
add and per-element pushes build, without the transitions."""
def:pub js_object_new_array(
    proto_idx: int, sid: int, elements: list[JSValue], len_v: JSValue
) -> JSValue {
    na_idx: int = _obj_alloc(proto_idx);
    _obj_init_array(jo_p(na_idx), sid, len_v);
    __mem_store_i64(wrapping_add(jo_p(na_idx), 120), jo_einit(na_idx, elements));
    return _obj_wrap(na_idx);
}

"""js_object_new_array with vals[off .. off+n) as the elements (no list of
them built first)."""
def:pub js_object_new_array_range(
    proto_idx: int, sid: int, vals: list[JSValue], off: int, n: int, len_v: JSValue
) -> JSValue {
    nr_idx: int = 0;
    nq_t: int = _OBJ_FREE_N;
    if nq_t > 0 and _OBJ_NOTE < 31 and (proto_idx <= 0 or proto_idx == _OBJ_PROTO_NOTED) {
        nq_c: int = __mem_load_i64(wrapping_add(_OBJ_FREE, wrapping_mul(nq_t - 1, 8)));
        nq_q: int = jo_p(nq_c);
        nq_e: int = __mem_load_i64(wrapping_add(nq_q, 128));
        if nq_c != _OBJ_PROTO_NOTED
            and (__mem_load_i64(wrapping_add(nq_q, 104)) & (FLAG_IS_PROTO | FLAG_SLOTS_BIG | FLAG_MAPPED_ARGS)) == 0
            and __mem_load_i64(wrapping_add(nq_q, 144)) == 0
            and (nq_e == 0 or __mem_load_i64(wrapping_add(nq_e, 8)) <= 16) {
            _OBJ_FREE_N = nq_t - 1;
            _OBJ_NOTE = _OBJ_NOTE + 1;
            if nq_e != 0 {
                __mem_store_i64(nq_e, 0);  # a kept elements buffer, emptied
            }
            # (the header _obj_init_array leaves, written once)
            __mem_store_i64(nq_q, proto_idx);
            __mem_store_i64(wrapping_add(nq_q, 8), 2);
            __mem_store_i64(wrapping_add(nq_q, 16), sid);
            __mem_store_i64(wrapping_add(nq_q, 24), 2);
            __mem_store_i64(wrapping_add(nq_q, 32), js_true());
            __mem_store_i64(wrapping_add(nq_q, 40), len_v);
            __mem_store_i64(
                wrapping_add(nq_q, 72), MAP_MODE_SHAPE if shape_gate_enabled() else MAP_MODE_DICT
            );
            __mem_store_i64(wrapping_add(nq_q, 80), 0);
            __mem_store_i64(wrapping_add(nq_q, 88), 0);
            __mem_store_i64(wrapping_add(nq_q, 96), -1);
            __mem_store_i64(wrapping_add(nq_q, 104), 0);
            __mem_store_i64(wrapping_add(nq_q, 136), BRAND_ARRAY);
            __mem_store_i8(wrapping_add(_OBJ_REALM.objmark_ptr, wrapping_add(nq_c, -1)), 0);
            nr_idx = nq_c;
        }
    }
    if nr_idx == 0 {
        nr_idx = _obj_alloc_full(proto_idx);
        _obj_init_array(jo_p(nr_idx), sid, len_v);
    }
    nr_p: int = jo_p(nr_idx);
    if n == 0 {
        # (what jo_einit_range answers for no elements, without the call)
        __mem_store_i64(wrapping_add(nr_p, 120), ELEMS_DENSE);
    } else {
        __mem_store_i64(wrapping_add(nr_p, 120), jo_einit_range(nr_idx, vals, off, n));
    }
    return _obj_wrap(nr_idx);
}

"""`[]`: js_object_new_array_range of no values (its own copy, so that one
keeps a single caller and inlines into NEWARRAY)."""
def:pub js_object_new_array_empty(proto_idx: int, sid: int) -> JSValue {
    ner_idx: int = 0;
    ne_t: int = _OBJ_FREE_N;
    if ne_t > 0 and _OBJ_NOTE < 31 and (proto_idx <= 0 or proto_idx == _OBJ_PROTO_NOTED) {
        ne_c: int = __mem_load_i64(wrapping_add(_OBJ_FREE, wrapping_mul(ne_t - 1, 8)));
        ne_q: int = jo_p(ne_c);
        ne_e: int = __mem_load_i64(wrapping_add(ne_q, 128));
        if ne_c != _OBJ_PROTO_NOTED
            and (__mem_load_i64(wrapping_add(ne_q, 104)) & (FLAG_IS_PROTO | FLAG_SLOTS_BIG | FLAG_MAPPED_ARGS)) == 0
            and __mem_load_i64(wrapping_add(ne_q, 144)) == 0
            and (ne_e == 0 or __mem_load_i64(wrapping_add(ne_e, 8)) <= 16) {
            _OBJ_FREE_N = ne_t - 1;
            _OBJ_NOTE = _OBJ_NOTE + 1;
            if ne_e != 0 {
                __mem_store_i64(ne_e, 0);  # a kept elements buffer, emptied
            }
            # (the header _obj_init_array leaves, written once)
            __mem_store_i64(ne_q, proto_idx);
            __mem_store_i64(wrapping_add(ne_q, 8), 2);
            __mem_store_i64(wrapping_add(ne_q, 16), sid);
            __mem_store_i64(wrapping_add(ne_q, 24), 2);
            __mem_store_i64(wrapping_add(ne_q, 32), js_true());
            __mem_store_i64(wrapping_add(ne_q, 40), js_int(0));
            __mem_store_i64(
                wrapping_add(ne_q, 72), MAP_MODE_SHAPE if shape_gate_enabled() else MAP_MODE_DICT
            );
            __mem_store_i64(wrapping_add(ne_q, 80), 0);
            __mem_store_i64(wrapping_add(ne_q, 88), 0);
            __mem_store_i64(wrapping_add(ne_q, 96), -1);
            __mem_store_i64(wrapping_add(ne_q, 104), 0);
            __mem_store_i64(wrapping_add(ne_q, 136), BRAND_ARRAY);
            __mem_store_i8(wrapping_add(_OBJ_REALM.objmark_ptr, wrapping_add(ne_c, -1)), 0);
            ner_idx = ne_c;
        }
    }
    if ner_idx == 0 {
        ner_idx = _obj_alloc_full(proto_idx);
        _obj_init_array(jo_p(ner_idx), sid, js_int(0));
    }
    __mem_store_i64(wrapping_add(jo_p(ner_idx), 120), ELEMS_DENSE);
    return _obj_wrap(ner_idx);
}

"""Whether Array `arr` has the canonical array shape `sid` and holds every
element in its dense buffer (the buffer's count is its length): no index is
an own accessor or other property, and a read runs no JS."""
def:pub js_object_array_dense_full(arr: JSValue, sid: int) -> bool {
    df_p: int = jo_p(jsv_to_table_id(arr));
    if __mem_load_i64(wrapping_add(df_p, 16)) != sid
        or __mem_load_i64(wrapping_add(df_p, 120)) == ELEMS_NONE {
        return False;
    }
    df_e: int = __mem_load_i64(wrapping_add(df_p, 128));
    df_n: int = 0;
    if df_e != 0 {
        df_n = __mem_load_i64(df_e);
    }
    df_len: JSValue = __mem_load_i64(wrapping_add(df_p, 40));
    return jsv_is_int32(df_len) and jsv_to_int32(df_len) == df_n;
}

"""Whether `v` is a plain object: an object cell with no class, binary kind
or brand (not an array, String object, typed array, proxy or other
built-in) and not a module namespace."""
def:pub js_object_is_plain(v: JSValue) -> bool {
    if not jsv_is_object_cell(v) or jsv_to_table_id(v) <= 0 {
        return False;
    }
    ip_p: int = jo_p(jsv_to_table_id(v));
    return __mem_load_i64(wrapping_add(ip_p, 80)) == 0
        and __mem_load_i64(wrapping_add(ip_p, 88)) == 0
        and __mem_load_i64(wrapping_add(ip_p, 136)) == 0
        and (__mem_load_i64(wrapping_add(ip_p, 104)) & FLAG_MODULE_NS) == 0;
}

"""indexOf's scan of `arr`'s dense elements [start, n) for `v`, whose
strict equality is identity there (an int32, boolean, null, undefined or an
object cell; the caller checks): the first index, -1 when absent, -2 when
the scan cannot decide (no element buffer of the length, a hole, a double:
the general loop then runs)."""
def:pub js_object_dense_index_of(arr: JSValue, v: JSValue, start: int, n: int) -> int {
    if not jsv_is_object_cell(arr) {
        return -2;
    }
    di_e: int = __mem_load_i64(wrapping_add(jo_p(jsv_to_table_id(arr)), 128));
    if di_e == 0 or __mem_load_i64(di_e) < n {
        return -2;
    }
    di_i: int = start;
    while di_i < n {
        di_x: JSValue = __mem_load_i64(wrapping_add(di_e, wrapping_add(16, wrapping_mul(di_i, 8))));
        if di_x == v {
            return di_i;
        }
        if jsv_is_hole(di_x) or jsv_is_double(di_x) {
            return -2;
        }
        di_i = di_i + 1;
    }
    return -1;
}

"""push(v) of one value onto the Array `arr` while it has the canonical array
shape `sid` (the marker, then a writable `length` in slot 1), is
extensible, shape-mode, with an element buffer whose count is its length:
the append and the length write (as _vm_array_push's dense arm); the hole
otherwise."""
def:pub js_object_array_push1(arr: JSValue, sid: int, v: JSValue) -> JSValue {
    ap_id: int = jsv_to_table_id(arr);
    ap_p: int = jo_p(ap_id);
    if __mem_load_i64(wrapping_add(ap_p, 16)) != sid
        or __mem_load_i64(wrapping_add(ap_p, 72)) != MAP_MODE_SHAPE
        or (__mem_load_i64(wrapping_add(ap_p, 104)) & FLAG_NON_EXTENSIBLE) != 0
        or __mem_load_i64(wrapping_add(ap_p, 120)) == ELEMS_NONE {
        return jsv_hole();
    }
    ap_e: int = __mem_load_i64(wrapping_add(ap_p, 128));
    ap_n: int = 0;
    if ap_e != 0 {
        ap_n = __mem_load_i64(ap_e);
    }
    ap_len: JSValue = __mem_load_i64(wrapping_add(ap_p, 40));
    if not jsv_is_int32(ap_len) or jsv_to_int32(ap_len) != ap_n or ap_n >= 2147483646 {
        return jsv_hole();
    }
    jo_epush(ap_id, v);
    jo_sset(ap_id, 1, js_int(ap_n + 1));
    return js_int(ap_n + 1);
}

"""GETFIELD's flat cache entry for a data slot one prototype up (vm.jac
_ric_fill_inh: w0 = -2 - (receiver shape << 1 | proto epoch << 26), w1 =
holder id << 32 | slot) applied to `v`: the slot's value while `v` has that
shape, the holder is its [[Prototype]] and the proto epoch stands
(js_object_proto_ic_ok's conditions); the hole otherwise."""
def:pub js_object_ric_get_inh(v: JSValue, w0: int, w1: int) -> JSValue {
    if not jsv_is_object_cell(v) {
        return jsv_hole();
    }
    gi_p: int = jo_p(jsv_to_table_id(v));
    gi_enc: int = -2 - w0;
    if (gi_enc & 1) != 0
        or __mem_load_i64(wrapping_add(gi_p, 16)) != ((gi_enc >> 1) & 33554431)
        or (gi_enc >> 26) != proto_epoch()
        or __mem_load_i64(gi_p) != (w1 >> 32)
        or __mem_load_i64(wrapping_add(gi_p, 72)) != MAP_MODE_SHAPE
        or __mem_load_i64(wrapping_add(gi_p, 80)) != 0
        or __mem_load_i64(wrapping_add(gi_p, 88)) != 0
        or (
            __mem_load_i64(wrapping_add(gi_p, 104))
            & (FLAG_IS_ARGUMENTS | FLAG_IS_CLASS | FLAG_MODULE_NS | FLAG_IS_GLOBAL)
        )
            != 0 {
        return jsv_hole();
    }
    return js_object_slot_at_id(w1 >> 32, w1 & 4294967295);
}

"""GETFIELD's flat cache entry for an inherited getter (vm.jac
_ric_fill_getter: w0 = -2 - (receiver shape << 1 | 1 | proto epoch << 26),
w1 = getter closure id << 32 | [[Prototype]] + 1) on `v`: the getter's
closure id while `v` has that shape and [[Prototype]], the proto epoch
stands and `v` is a plain shape-mode object (the getter IC's conditions);
-1 otherwise."""
def:pub js_object_ric_getter(v: JSValue, w0: int, w1: int) -> int {
    if not jsv_is_object_cell(v) {
        return -1;
    }
    rg_p: int = jo_p(jsv_to_table_id(v));
    rg_enc: int = -2 - w0;
    if (rg_enc & 1) == 0
        or __mem_load_i64(wrapping_add(rg_p, 16)) != ((rg_enc >> 1) & 33554431)
        or (rg_enc >> 26) != proto_epoch()
        or wrapping_add(__mem_load_i64(rg_p), 1) != (w1 & 4294967295)
        or __mem_load_i64(wrapping_add(rg_p, 72)) != MAP_MODE_SHAPE
        or __mem_load_i64(wrapping_add(rg_p, 80)) != 0
        or __mem_load_i64(wrapping_add(rg_p, 88)) != 0
        or (
            __mem_load_i64(wrapping_add(rg_p, 104))
            & (FLAG_IS_ARGUMENTS | FLAG_IS_CLASS | FLAG_MODULE_NS | FLAG_IS_GLOBAL)
        )
            != 0 {
        return -1;
    }
    return w1 >> 32;
}

"""Record that the object with table id `id` is an ArrayBuffer: the lazy
object sweep does not read dead rows, so it checks these for an external
buffer's finalizer (gc_sweep_objects)."""
def:pub js_object_note_array_buffer(id: int) -> None {
    _OBJ_REALM.gc_ab_rows[id] = True;
}

"""An object's table id (for Proxy / internal use; records are addressed by id)."""
def:pub js_object_table_get(idx: int) -> int {
    return idx;
}

# Scalar reads of one object's fields for the VM's hottest paths. They go
# through the table row as a borrowed list element, so unlike
# js_object_table_get / _obj_get (which return an owned JSObject reference:
# a retain plus the caller's release, ~35 instructions per call before any
# work) they take no reference at all. `id` is the 1-based table id (> 0).

"""binary_kind of the object with table id `id`."""
def:pub js_object_binary_kind_id(id: int) -> int {
    return jo_bkind(id);
}

"""Element `i` of `v`'s dense elements when it is there (an own data element:
[[Get]] returns it with nothing observable), else the hole — the caller then
takes the full property path."""
def:pub js_object_dense_elem(v: JSValue, i: int) -> JSValue {
    if i < 0 or not jsv_is_object_cell(v) {
        return jsv_hole();
    }
    de_id: int = jsv_to_table_id(v);
    if de_id <= 0 {
        return jsv_hole();
    }
    de_p: int = jo_p(de_id);
    if __mem_load_i64(wrapping_add(de_p, 120)) == ELEMS_NONE {
        return jsv_hole();
    }
    de_e: int = __mem_load_i64(wrapping_add(de_p, 128));
    if de_e == 0 or i >= __mem_load_i64(de_e) {
        return jsv_hole();
    }
    return __mem_load_i64(wrapping_add(de_e, wrapping_add(16, wrapping_mul(i, 8))));
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
    if dp_id <= 0 or jo_elems_kind(dp_id) == ELEMS_NONE {
        return False;
    }
    if (jo_cell_flags(dp_id) & FLAG_IS_PROTO) != 0 {
        return False;
    }
    if jsv_is_hole(jo_elem_or_hole(dp_id, i)) {
        return False;
    }
    jo_eset(dp_id, i, val);
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
    ih_p: int = jo_p(ih_id);
    if __mem_load_i64(wrapping_add(ih_p, 16)) != sid
        or __mem_load_i64(wrapping_add(ih_p, 80)) != 0
        or __mem_load_i64(wrapping_add(ih_p, 72)) != MAP_MODE_SHAPE
        or (__mem_load_i64(wrapping_add(ih_p, 104)) & (FLAG_MODULE_NS | FLAG_IS_GLOBAL)) != 0 {
        return jsv_hole();
    }
    if si < 4 {
        return __mem_load_i64(wrapping_add(ih_p, wrapping_add(32, wrapping_mul(si, 8))));
    }
    return __mem_load_i64(
        wrapping_add(__mem_load_i64(wrapping_add(ih_p, 64)), wrapping_add(wrapping_mul(si, 8), -16))
    );
}

"""Address of the entry for shape `sid` in a polymorphic GETFIELD site's
table at `tbl` (16 entries of [shape id, slot], vm.jac _ric_fill_get)."""
def:pub js_object_poly_entry(tbl: int, sid: int) -> int {
    return wrapping_add(tbl, wrapping_mul((sid ^ (sid >> 4) ^ (sid >> 8)) & 15, 16));
}

"""A polymorphic GETFIELD site's table (`tbl`) applied to `v`: the slot its
shape's entry names, under js_object_ic_hit's conditions; the hole when `v`
is not such an object or its shape has no entry."""
def:pub js_object_poly_get(v: JSValue, tbl: int) -> JSValue {
    if not jsv_is_object_cell(v) {
        return jsv_hole();
    }
    pg_p: int = jo_p(jsv_to_table_id(v));
    pg_sid: int = __mem_load_i64(wrapping_add(pg_p, 16));
    pg_e: int = js_object_poly_entry(tbl, pg_sid);
    if __mem_load_i64(pg_e) != pg_sid
        or pg_sid <= 0
        or __mem_load_i64(wrapping_add(pg_p, 80)) != 0
        or __mem_load_i64(wrapping_add(pg_p, 72)) != MAP_MODE_SHAPE
        or (__mem_load_i64(wrapping_add(pg_p, 104)) & (FLAG_MODULE_NS | FLAG_IS_GLOBAL)) != 0 {
        return jsv_hole();
    }
    pg_si: int = __mem_load_i64(wrapping_add(pg_e, 8));
    if pg_si < 4 {
        return __mem_load_i64(wrapping_add(pg_p, wrapping_add(32, wrapping_mul(pg_si, 8))));
    }
    return __mem_load_i64(
        wrapping_add(__mem_load_i64(wrapping_add(pg_p, 64)), wrapping_add(wrapping_mul(pg_si, 8), -16))
    );
}

"""slots[si] of table row `id` read in place (JSObject.sget without the
dispatch): the four inline slots, then the slot buffer."""
def _obj_slot_read(id: int, si: int) -> JSValue {
    sr_p: int = jo_p(id);
    if si < 4 {
        return __mem_load_i64(wrapping_add(sr_p, wrapping_add(32, wrapping_mul(si, 8))));
    }
    return __mem_load_i64(
        wrapping_add(__mem_load_i64(wrapping_add(sr_p, 64)), wrapping_add(wrapping_mul(si, 8), -16))
    );
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
    if jo_shape_id(is_id) != sid
        or jo_class_id(is_id) != 0
        or jo_mode(is_id) != MAP_MODE_SHAPE
        or (jo_cell_flags(is_id) & (FLAG_MODULE_NS | FLAG_IS_GLOBAL)) != 0 {
        return False;
    }
    # JSObject.wb, in place: an old row that is not yet remembered joins the
    # remembered set when a cell is stored into it.
    if (jo_cell_flags(is_id) & (FLAG_OLD | FLAG_REMEMBERED)) == FLAG_OLD
        and jsv_is_cell(val) {
        jo_set_cell_flags(is_id, jo_cell_flags(is_id)
            | FLAG_REMEMBERED);
        gc_rem_obj(is_id);
    }
    if si < 2 {
        if si == 0 {
            jo_set_s0(is_id, val);
        } else {
            jo_set_s1(is_id, val);
        }
    } elif si < 4 {
        if si == 2 {
            jo_set_s2(is_id, val);
        } else {
            jo_set_s3(is_id, val);
        }
    } else {
        write_i64(jo_sp(is_id), si * 8 - 16, val);
    }
    return True;
}

"""The register SETFIELD's flat IC entry at address `e` (two words; vm.jac
_ric_fill_set / _ric_fill_add) applied to `v`. w0 > 0: an own-slot write
(shape w0, slot w1; js_object_ic_set_hit). w0 <= -2: a leaf add, with
enc = -2 - w0 = before-shape << 1 | 0 for an object-literal define, or
epoch << 26 | before-shape << 1 | 1 for a [[Set]] add (w1's high half then
the receiver's [[Prototype]] + 1); w1's low half is the after-shape. The add
appends `val` under the after-shape when `v` is an ordinary extensible
shape-mode object, not a prototype, at the before-shape, and for a [[Set]]
add has the fill's [[Prototype]] while the proto epoch is the fill's (what
the site's holder 3 / 4 IC replays); a function value on a define keeps the
handler (its [[HomeObject]]). False: nothing done."""
def:pub js_object_ric_set(v: JSValue, e: int, val: JSValue) -> bool {
    rs_w0: int = __mem_load_i64(e);
    if rs_w0 > 0 {
        return js_object_ic_set_hit(v, rs_w0, __mem_load_i64(wrapping_add(e, 8)), val);
    }
    if rs_w0 > -2 or not jsv_is_object_cell(v) {
        return False;
    }
    rs_id: int = jsv_to_table_id(v);
    if rs_id <= 0 {
        return False;
    }
    rs_p: int = jo_p(rs_id);
    rs_enc: int = -2 - rs_w0;
    if __mem_load_i64(wrapping_add(rs_p, 16)) != ((rs_enc >> 1) & 33554431)
        or __mem_load_i64(wrapping_add(rs_p, 80)) != 0
        or __mem_load_i64(wrapping_add(rs_p, 72)) != MAP_MODE_SHAPE
        or (
            __mem_load_i64(wrapping_add(rs_p, 104))
            & (FLAG_MODULE_NS | FLAG_IS_GLOBAL | FLAG_NON_EXTENSIBLE | FLAG_IS_PROTO)
        )
            != 0 {
        return False;
    }
    rs_w1: int = __mem_load_i64(wrapping_add(e, 8));
    if (rs_enc & 1) != 0 {
        if (rs_enc >> 26) != proto_epoch()
            or wrapping_add(__mem_load_i64(rs_p), 1) != (rs_w1 >> 32) {
            return False;
        }
    } elif jsv_is_cell(val) and jsv_cell_kind(val) == JS_CELL_KIND_NATIVE {
        return False;
    }
    __mem_store_i64(wrapping_add(rs_p, 16), rs_w1 & 4294967295);
    rs_sn: int = __mem_load_i64(wrapping_add(rs_p, 24));
    if rs_sn < 4 and (__mem_load_i64(wrapping_add(rs_p, 104)) & FLAG_OLD) == 0 {
        # an inline slot of a young object: no buffer, no barrier
        __mem_store_i64(wrapping_add(rs_p, wrapping_add(32, wrapping_mul(rs_sn, 8))), val);
        __mem_store_i64(wrapping_add(rs_p, 24), rs_sn + 1);
    } else {
        jo_spush(rs_id, val);
    }
    __mem_store_i64(
        wrapping_add(rs_p, 8), wrapping_add(__mem_load_i64(wrapping_add(rs_p, 8)), 1)
    );
    return True;
}

# The `new` class-metadata cache (js_object_class_meta): 256 entries of four
# words [shape id, [[Prototype]], proto epoch, packed], raw memory calloc'd on
# first use, indexed by the class object's shape id.
glob _NC_TAB: int = 0;

"""Where `new` finds the metadata of class object `id`: packed = the slot of
own data property `kc` (WK_CTOR) | that of `kp` (WK_PROTOTYPE) << 16 |
(that of `kf` (WK_FIELDS) + 1) << 32 | 1 << 48 when `ks` (WK_SUPER) is own.
The caller reads the slots (values are live; a shape fixes the layout). kf's
+ 1 is 0 when it is not own: then for a base class (no ks) a [[Get]] of it
finds nothing on the whole chain either. -1 when the object does not fit
(not ordinary shape-mode, a key missing or an accessor, an inherited kf on a
base class, a chain the check cannot prove). Cached per shape id with the
[[Prototype]] and proto epoch the chain check saw."""
def:pub js_object_class_meta(id: int, kc: int, kp: int, kf: int, ks: int) -> int {
    cm_p: int = jo_p(id);
    if __mem_load_i64(wrapping_add(cm_p, 72)) != MAP_MODE_SHAPE
        or __mem_load_i64(wrapping_add(cm_p, 80)) != 0 {
        return -1;
    }
    cm_sid: int = __mem_load_i64(wrapping_add(cm_p, 16));
    cm_pr: int = __mem_load_i64(cm_p);
    if _NC_TAB != 0 {
        cm_e: int = wrapping_add(_NC_TAB, wrapping_mul(cm_sid & 255, 32));
        if __mem_load_i64(cm_e) == cm_sid
            and __mem_load_i64(wrapping_add(cm_e, 8)) == cm_pr
            and __mem_load_i64(wrapping_add(cm_e, 16)) == proto_epoch() {
            return __mem_load_i64(wrapping_add(cm_e, 24));
        }
    }
    return _obj_class_meta_fill(cm_sid, cm_pr, kc, kp, kf, ks);
}

"""js_object_class_meta's miss: the four own-key lookups, the chain check
for a base class without own fields, then the cache entry."""
def _obj_class_meta_fill(sid: int, pr: int, kc: int, kp: int, kf: int, ks: int) -> int {
    mf_c: int = shape_lookup(sid, kc);
    mf_p: int = shape_lookup(sid, kp);
    mf_f: int = shape_lookup(sid, kf);
    mf_s: int = shape_lookup(sid, ks);
    if mf_c < 0 or mf_p < 0 or ((mf_c | mf_p) & SHAPE_ATTR_ACCESSOR) != 0 {
        return -1;
    }
    if (mf_f >= 0 and (mf_f & SHAPE_ATTR_ACCESSOR) != 0)
        or (mf_s >= 0 and (mf_s & SHAPE_ATTR_ACCESSOR) != 0) {
        return -1;
    }
    if (mf_c >> 4) >= 65535 or (mf_p >> 4) >= 65535 or (mf_f >> 4) >= 65534 {
        return -1;
    }
    mf_packed: int = (mf_c >> 4) | ((mf_p >> 4) << 16);
    if mf_f >= 0 {
        mf_packed = mf_packed | (((mf_f >> 4) + 1) << 32);
    }
    if mf_s >= 0 {
        mf_packed = mf_packed | (1 << 48);
    } elif mf_f < 0 {
        # A base class reads kf with [[Get]]: no object up the chain has it.
        # Each one is (now) flagged a prototype, so a key added to it later
        # bumps the proto epoch and this entry misses.
        mf_q: int = pr;
        mf_n: int = 0;
        while mf_q > 0 {
            if mf_n >= PROTO_MAX_DEPTH {
                return -1;
            }
            mf_qp: int = jo_p(mf_q);
            if __mem_load_i64(wrapping_add(mf_qp, 72)) != MAP_MODE_SHAPE
                or __mem_load_i64(wrapping_add(mf_qp, 80)) != 0
                or __mem_load_i64(wrapping_add(mf_qp, 120)) != ELEMS_NONE
                or shape_lookup(__mem_load_i64(wrapping_add(mf_qp, 16)), kf) >= 0 {
                return -1;
            }
            if (__mem_load_i64(wrapping_add(mf_qp, 104)) & FLAG_IS_PROTO) == 0 {
                _obj_note_proto(mf_q);
            }
            mf_q = __mem_load_i64(mf_qp);
            mf_n = mf_n + 1;
        }
    }
    if _NC_TAB == 0 {
        _NC_TAB = calloc(256, 32);
        if _NC_TAB == 0 {
            return mf_packed;
        }
    }
    mf_e: int = wrapping_add(_NC_TAB, wrapping_mul(sid & 255, 32));
    __mem_store_i64(mf_e, sid);
    __mem_store_i64(wrapping_add(mf_e, 8), pr);
    __mem_store_i64(wrapping_add(mf_e, 16), proto_epoch());
    __mem_store_i64(wrapping_add(mf_e, 24), mf_packed);
    return mf_packed;
}

"""[[Prototype]] table id of the object with table id `id` (0 = null)."""
def:pub js_object_proto_idx_id(id: int) -> int {
    return jo_prototype_idx(id);
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
    dp_raw: int = dp_id;
    if jo_class_id(dp_raw) != 0
        or jo_elems_kind(dp_raw) == ELEMS_NONE
        or (jo_brand(dp_raw) & BRAND_ARRAY) == 0 {
        return False;
    }
    if (jo_cell_flags(dp_raw) & (FLAG_FROZEN | FLAG_SEALED | FLAG_NON_EXTENSIBLE)) != 0 {
        return False;
    }
    dp_n: int = jo_elen(dp_raw);
    if i < dp_n {
        jo_eset(dp_raw, i, val);
        return True;
    }
    if i == dp_n and jo_mode(dp_raw) == MAP_MODE_SHAPE {
        dp_lk: int = shape_lookup(jo_shape_id(dp_raw), KEY_LENGTH);
        if dp_lk >= 0 and (dp_lk & SHAPE_ATTR_ACCESSOR) == 0 {
            dp_len: JSValue = jo_sget(dp_raw, dp_lk // 16);
            if jsv_is_int32(dp_len) and i < jsv_to_int32(dp_len) {
                jo_epush(dp_raw, val);
                return True;
            }
            # At or past the length (filter's result starts at length 0):
            # ArrayDefineOwnProperty grows `length` to i + 1 — allowed only
            # while `length` is writable.
            if jsv_is_int32(dp_len)
                and i >= jsv_to_int32(dp_len)
                and (dp_lk & PROP_WRITABLE) != 0
                and i < 2147483647 {
                jo_epush(dp_raw, val);
                jo_sset(dp_raw, dp_lk // 16, js_int(i + 1));
                return True;
            }
        }
    }
    return False;
}

"""Array.prototype.shift on a plain extensible Array whose dense elements
are all of it (a writable data `length` equal to their count, > 0), while no
prototype carries an index property (idx_protector_ok, checked by the
caller): moving the element words down one is the spec's Get / Set /
DeletePropertyOrThrow sequence, with nothing able to observe it — a hole
moves down as a hole, and a hole at 0 reads as undefined. Returns the
removed element (undefined for a hole), or the hole when `v` does not
qualify — the caller then takes the generic path."""
def:pub js_object_dense_shift(v: JSValue) -> JSValue {
    if not jsv_is_object_cell(v) {
        return jsv_hole();
    }
    ds_id: int = jsv_to_table_id(v);
    if ds_id <= 0 {
        return jsv_hole();
    }
    ds_raw: int = ds_id;
    if jo_class_id(ds_raw) != 0
        or jo_elems_kind(ds_raw) == ELEMS_NONE
        or (jo_brand(ds_raw) & BRAND_ARRAY) == 0
        or jo_mode(ds_raw) != MAP_MODE_SHAPE {
        return jsv_hole();
    }
    if (jo_cell_flags(ds_raw) & (FLAG_FROZEN | FLAG_SEALED | FLAG_NON_EXTENSIBLE)) != 0 {
        return jsv_hole();
    }
    ds_n: int = jo_elen(ds_raw);
    if ds_n == 0 {
        return jsv_hole();
    }
    ds_lk: int = shape_lookup(jo_shape_id(ds_raw), KEY_LENGTH);
    if ds_lk < 0 or (ds_lk & SHAPE_ATTR_ACCESSOR) != 0 or (ds_lk & PROP_WRITABLE) == 0 {
        return jsv_hole();
    }
    ds_len: JSValue = jo_sget(ds_raw, ds_lk // 16);
    if not jsv_is_int32(ds_len) or jsv_to_int32(ds_len) != ds_n {
        return jsv_hole();
    }
    ds_first: JSValue = jo_eget(ds_raw, 0);
    jo_eshift(ds_raw);
    jo_sset(ds_raw, ds_lk // 16, js_int(ds_n - 1));
    if jsv_is_hole(ds_first) {
        return js_undefined();
    }
    return ds_first;
}

"""Array.prototype.pop on the arrays js_object_dense_shift takes (idx_protector_ok
checked by the caller): dropping the last element word and storing the new
length is the spec's Get / DeletePropertyOrThrow / Set sequence, which
nothing can observe. An empty array (length 0) gives undefined, as the spec's
Set of length 0 changes nothing. Returns the removed element (undefined for a
hole), or the hole when `v` does not qualify."""
def:pub js_object_dense_pop(v: JSValue) -> JSValue {
    if not jsv_is_object_cell(v) {
        return jsv_hole();
    }
    dpo_id: int = jsv_to_table_id(v);
    if dpo_id <= 0 {
        return jsv_hole();
    }
    if jo_class_id(dpo_id) != 0
        or jo_elems_kind(dpo_id) == ELEMS_NONE
        or (jo_brand(dpo_id) & BRAND_ARRAY) == 0
        or jo_mode(dpo_id) != MAP_MODE_SHAPE {
        return jsv_hole();
    }
    if (jo_cell_flags(dpo_id) & (FLAG_FROZEN | FLAG_SEALED | FLAG_NON_EXTENSIBLE)) != 0 {
        return jsv_hole();
    }
    dpo_lk: int = shape_lookup(jo_shape_id(dpo_id), KEY_LENGTH);
    if dpo_lk < 0 or (dpo_lk & SHAPE_ATTR_ACCESSOR) != 0 or (dpo_lk & PROP_WRITABLE) == 0 {
        return jsv_hole();
    }
    dpo_n: int = jo_elen(dpo_id);
    dpo_len: JSValue = jo_sget(dpo_id, dpo_lk // 16);
    if not jsv_is_int32(dpo_len) or jsv_to_int32(dpo_len) != dpo_n {
        return jsv_hole();
    }
    if dpo_n == 0 {
        return js_undefined();
    }
    dpo_last: JSValue = jo_eget(dpo_id, dpo_n - 1);
    write_i64(jo_ep(dpo_id), 0, dpo_n - 1);
    jo_sset(dpo_id, dpo_lk // 16, js_int(dpo_n - 1));
    if jsv_is_hole(dpo_last) {
        return js_undefined();
    }
    return dpo_last;
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
    return jo_class_id(po_id) == 0
        and jo_bkind(po_id) == 0
        and (
            jo_cell_flags(po_id)
            & (FLAG_MODULE_NS | FLAG_IS_ARGUMENTS)
        )
            == 0;
}

"""The shape id of `v` when it is a plain ordinary object in shape mode with
no accessor table, no elements and no exotic brand — its own properties are
exactly its shape's keys, each read without side effects — else -1."""
def:pub js_object_plain_shape_id(v: JSValue) -> int {
    if not js_object_is_plain_ordinary(v) {
        return -1;
    }
    ps_id: int = jsv_to_table_id(v);
    if jo_mode(ps_id) != MAP_MODE_SHAPE
        or jo_elems_kind(ps_id) != ELEMS_NONE
        or jo_has_acc(ps_id)
        or (jo_brand(ps_id) & BRAND_STRING_OBJ) != 0
        or (jo_cell_flags(ps_id) & FLAG_MAPPED_ARGS) != 0 {
        return -1;
    }
    return jo_shape_id(ps_id);
}

"""cell_flags of the object with table id `id`."""
def:pub js_object_cell_flags_id(id: int) -> int {
    return jo_cell_flags(id);
}

"""class_id of the object with table id `id`."""
def:pub js_object_class_id_id(id: int) -> int {
    return jo_class_id(id);
}

"""elems_kind of the object with table id `id`."""
def:pub js_object_elems_kind_id(id: int) -> int {
    return jo_elems_kind(id);
}

"""binary_slot of the object with table id `id`."""
def:pub js_object_binary_slot_id(id: int) -> int {
    return jo_bslot(id);
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
    mg_raw: int = mg_id;
    if (jo_cell_flags(mg_raw) & FLAG_IS_GLOBAL) == 0 {
        jo_set_cell_flags(mg_raw, jo_cell_flags(mg_raw) | FLAG_IS_GLOBAL);
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
    is_p: int = jo_p(is_id);
    if __mem_load_i64(wrapping_add(is_p, 80)) != 0
        or (__mem_load_i64(wrapping_add(is_p, 104)) & (FLAG_MODULE_NS | FLAG_IS_GLOBAL)) != 0
        or __mem_load_i64(wrapping_add(is_p, 72)) != MAP_MODE_SHAPE {
        return -1;
    }
    return __mem_load_i64(wrapping_add(is_p, 16));
}

"""slots[si] of the object with table id `id` (an IC hit: the caller has
matched the shape, so the slot exists)."""
def:pub js_object_slot_at_id(id: int, si: int) -> JSValue {
    sa_p: int = jo_p(id);
    if si < 4 {
        return __mem_load_i64(wrapping_add(sa_p, wrapping_add(32, wrapping_mul(si, 8))));
    }
    return __mem_load_i64(
        wrapping_add(__mem_load_i64(wrapping_add(sa_p, 64)), wrapping_add(wrapping_mul(si, 8), -16))
    );
}

"""Table slot index of `v`'s own data property `key` when `v` is an ordinary
shape-mode object that has it (see js_object_ic_shape), else -1. Used once
to learn the layout of closure cells (vm/cell.jac)."""
def:pub js_object_own_data_slot(v: JSValue, key: int) -> int {
    if js_object_ic_shape(v) < 0 {
        return -1;
    }
    ds_p: int = shape_lookup(jo_shape_id(jsv_to_table_id(v)), key);
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
        jo_cell_flags(sw_id)
        & (FLAG_FROZEN | FLAG_SEALED | FLAG_NON_EXTENSIBLE)
    )
        != 0 {
        return False;
    }
    jo_sset(sw_id, si, val);
    return True;
}

"""slots[si] = val on the object with table id `id` (a SET IC hit: the
caller has matched the shape, which guarantees a writable data slot)."""
def:pub js_object_slot_set_at_id(id: int, si: int, val: JSValue) {
    jo_sset(id, si, val);
}

"""Inherited-data IC guard on the receiver (table id `id`): its
[[Prototype]] is still `proto_idx`, it is not a binary view, and it is
neither an arguments object nor a class."""
def:pub js_object_proto_ic_ok(id: int, proto_idx: int) -> bool {
    pk_p: int = jo_p(id);
    return __mem_load_i64(pk_p) == proto_idx
        and __mem_load_i64(wrapping_add(pk_p, 88)) == 0
        and (__mem_load_i64(wrapping_add(pk_p, 104)) & (FLAG_IS_ARGUMENTS | FLAG_IS_CLASS)) == 0;
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
    return jo_brand(ob_id);
}

"""An object's table id (records are addressed by id: kept for callers that
fetched a JSObject handle)."""
def _obj_get(idx: int) -> int {
    return idx;
}

# Mapped-arguments aliasing storage lives in realm.args_slots[idx], not on the
# JSObject (docs/OBJECT_FOOTPRINT_PLAN.md Phase 1). A row exists iff the object's
# is_mapped_args flag is set, so every caller guards on that first.
def _args_row(idx: int) -> ArgsState {
    return _OBJ_REALM.args_slots[idx];
}

# ── Lazy accessor tables (docs/OBJECT_FOOTPRINT_PLAN.md P2) ────────────────────
# An object has no accessor table until the first accessor is installed, so ordinary
# objects carry no getter/setter dicts. Shared read-only empty table for the None
# case — NEVER mutate it; every write path must go through _acc_rw.
glob _ACC_EMPTY: AccessorTable = AccessorTable();

"""Accessor table for READ access: the object's own table, or the shared empty one
when it has no accessors. Result must not be mutated (see _acc_rw for writes)."""
def _acc_ro(raw: int) -> AccessorTable {
    return jo_acc_ro(raw, _ACC_EMPTY);
}

"""Accessor table for WRITE access, materializing it (and the owning edge) on the
object's first accessor install."""
def _acc_rw(raw: int) -> AccessorTable {
    return jo_acc_rw(raw);
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
    idx: int = 0;
    oc_t: int = _OBJ_FREE_N;
    if oc_t > 0 and _OBJ_NOTE < 31 and (proto_idx <= 0 or proto_idx == _OBJ_PROTO_NOTED) {
        oc_c: int = __mem_load_i64(wrapping_add(_OBJ_FREE, wrapping_mul(oc_t - 1, 8)));
        oc_q: int = jo_p(oc_c);
        oc_e: int = __mem_load_i64(wrapping_add(oc_q, 128));
        if oc_c != _OBJ_PROTO_NOTED
            and (__mem_load_i64(wrapping_add(oc_q, 104)) & (FLAG_IS_PROTO | FLAG_SLOTS_BIG | FLAG_MAPPED_ARGS)) == 0
            and __mem_load_i64(wrapping_add(oc_q, 144)) == 0
            and (oc_e == 0 or __mem_load_i64(wrapping_add(oc_e, 8)) <= 16) {
            _OBJ_FREE_N = oc_t - 1;
            _OBJ_NOTE = _OBJ_NOTE + 1;
            if oc_e != 0 {
                __mem_store_i64(oc_e, 0);  # a kept elements buffer, emptied
            }
            __mem_store_i64(oc_q, proto_idx);
            __mem_store_i64(wrapping_add(oc_q, 8), 0);
            __mem_store_i64(wrapping_add(oc_q, 16), 0);
            __mem_store_i64(wrapping_add(oc_q, 24), 0);
            __mem_store_i64(
                wrapping_add(oc_q, 72), MAP_MODE_SHAPE if shape_gate_enabled() else MAP_MODE_DICT
            );
            __mem_store_i64(wrapping_add(oc_q, 80), 0);
            __mem_store_i64(wrapping_add(oc_q, 88), 0);
            __mem_store_i64(wrapping_add(oc_q, 96), -1);
            __mem_store_i64(wrapping_add(oc_q, 104), 0);
            __mem_store_i64(wrapping_add(oc_q, 120), 0);
            __mem_store_i64(wrapping_add(oc_q, 136), 0);
            __mem_store_i8(wrapping_add(_OBJ_REALM.objmark_ptr, wrapping_add(oc_c, -1)), 0);
            idx = oc_c;
        }
    }
    if idx == 0 {
        idx = _obj_alloc_full(proto_idx);
    }
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
    if current_idx <= 0 {
        return js_undefined();
    }
    # Each level read through its record address (one computation per level).
    # Dense elements: an in-range non-hole element is the own property.
    # Holes/out-of-range fall through (the map holds no index keys while
    # dense — invariant) and continue up the prototype chain.
    gt_dix: int = -2;
    for _depth in range(PROTO_MAX_DEPTH) {
        if current_idx <= 0 {
            return js_undefined();
        }
        gt_p: int = jo_p(current_idx);
        if gt_dix == -2 and __mem_load_i64(wrapping_add(gt_p, 120)) != ELEMS_NONE {
            gt_dix = _obj_index_of_key(key);
        }
        gt_own: JSValue = jo_own_elem_or_data(current_idx, key, gt_dix);
        if not jsv_is_hole(gt_own) {
            # Mapped arguments: an aliased index reads the live parameter slot.
            if (__mem_load_i64(wrapping_add(gt_p, 104)) & FLAG_MAPPED_ARGS) != 0 {
                return _go_mapped_arg(current_idx, key, gt_own);
            }
            return gt_own;
        }
        current_idx = __mem_load_i64(gt_p);
    }
    return js_undefined();
}

"""js_object_get's mapped-`arguments` read, kept out of the walk: its owned
ArgsState local would register every js_object_get call for unwind."""
def _go_mapped_arg(current_idx: int, key: int, own_v: JSValue) -> JSValue {
    gt_ars: ArgsState = _args_row(current_idx);
    if key in gt_ars.slot_map {
        ms: int = gt_ars.slot_map[key];
        if ms >= 0 and ms < len(gt_ars.locals) {
            return gt_ars.locals[ms];
        }
    }
    return own_v;
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
    # The common levels (shape mode, no accessor tables) are read here with
    # no owned local; the first level that needs a row handle or the dict
    # hands the rest of the walk to _go_ordinary_slow.
    go_idx: int = jsv_to_table_id(jsobj);
    for _go_depth in range(PROTO_MAX_DEPTH) {
        if go_idx <= 0 {
            return js_undefined();
        }
        if (jo_brand(go_idx) & BRAND_STRING_OBJ) != 0
            and (key == KEY_LENGTH or _obj_is_array_index_key_id(key)) {
            return jsv_hole();
        }
        go_c: int = jo_ord_slot(go_idx, key);
        if go_c >= 0 {
            return jo_sget(go_idx, go_c);
        }
        if go_c == -2 {
            return jsv_hole();
        }
        if go_c <= -3 {
            return _go_ordinary_slow(go_idx, key);
        }
        go_idx = jo_prototype_idx(go_idx);
    }
    return jsv_hole();
}

"""js_object_get_ordinary from level `go_idx` on, with the row handle and
dict reads the lean walk leaves out."""
def _go_ordinary_slow(go_start: int, key: int) -> JSValue {
    go_idx: int = go_start;
    for _go_depth in range(PROTO_MAX_DEPTH) {
        if go_idx <= 0 {
            return js_undefined();
        }
        # A String wrapper is exotic only for `length` and integer-index keys
        # (ES §10.4.3); any other key — every String.prototype method name —
        # resolves like an ordinary object's.
        if (jo_brand(go_idx) & BRAND_STRING_OBJ) != 0
            and (key == KEY_LENGTH or _obj_is_array_index_key_id(key)) {
            return jsv_hole();
        }
        # The common level (shape mode, no accessor tables) is read through
        # the table row, a borrowed reference; see JSObject.ord_slot.
        go_c: int = jo_ord_slot(go_idx, key);
        if go_c >= 0 {
            return jo_sget(go_idx, go_c);
        }
        if go_c == -2 {
            return jsv_hole();
        }
        if go_c <= -3 {
            go_raw: int = go_idx;
            # Accessors first, as the full [[Get]] does: a key can be in both
            # the accessor tables and `entries`, and the accessor wins.
            if jo_has_acc(go_raw) and _go_acc_tables_have(go_raw, key) {
                return jsv_hole();
            }
            if jo_mode(go_raw) == MAP_MODE_SHAPE {
                go_packed: int = shape_lookup(jo_shape_id(go_raw), key);
                if go_packed >= 0 {
                    if (go_packed & SHAPE_ATTR_ACCESSOR) != 0 {
                        return jsv_hole();
                    }
                    return jo_sget(go_raw, go_packed // 16);
                }
            } else {
                go_ent: dict[int, JSProperty] = jo_ent_ro(go_raw);
                if key in go_ent {
                    return go_ent[key].value;
                }
            }
        }
        go_idx = jo_prototype_idx(go_idx);
    }
    return jsv_hole();
}

"""True if `raw` takes plain own-data writes: an ordinary, extensible object
that is not an array, String wrapper, process.env, class, binary view, module
namespace, mapped `arguments` or dense-elements holder."""
def _go_write_plain(raw: int) -> bool {
    return jo_class_id(raw) == 0
        and jo_bkind(raw) == 0
        and jo_elems_kind(raw) == ELEMS_NONE
        and (
            jo_cell_flags(raw)
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
        and (jo_brand(raw) & (BRAND_STRING_OBJ | BRAND_ARRAY | BRAND_ENV_OBJ)) == 0;
}

"""True if `key` is in `raw`'s accessor side tables (get/set/attribute maps —
an accessor whose get and set are both undefined shows only in the latter)."""
def _go_acc_tables_have(raw: int, key: int) -> bool {
    ga_acc: AccessorTable = _acc_ro(raw);
    return key in ga_acc.getters
        or key in ga_acc.setters
        or key in ga_acc.configurable
        or key in ga_acc.enumerable;
}

"""True if `raw` has an accessor (getter and/or setter) own property `key`."""
def _go_has_accessor(raw: int, key: int) -> bool {
    if jo_mode(raw) == MAP_MODE_SHAPE {
        ga_p: int = shape_lookup(jo_shape_id(raw), key);
        if ga_p >= 0 and (ga_p & SHAPE_ATTR_ACCESSOR) != 0 {
            return True;
        }
    }
    if jo_has_acc(raw) {
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
    ad_raw: int = ad_idx;
    if not _go_write_plain(ad_raw) {
        return False;
    }
    if jo_has_key(ad_raw, key) or _go_has_accessor(ad_raw, key) {
        return False;
    }
    if _obj_is_array_index_key_id(key) {
        return False;
    }
    return jo_set(ad_raw, key, val, PROP_DEFAULT) == 0;
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
    so_raw: int = so_idx;
    if not _go_write_plain(so_raw) {
        return False;
    }
    if _go_has_accessor(so_raw, key) {
        return False;
    }
    if jo_mode(so_raw) == MAP_MODE_SHAPE {
        so_p: int = shape_lookup(jo_shape_id(so_raw), key);
        if so_p >= 0 {
            if (so_p & SHAPE_ATTR_ACCESSOR) != 0 or (so_p & PROP_WRITABLE) == 0 {
                return False;
            }
            jo_sset(so_raw, so_p // 16, val);
            return True;
        }
    } else {
        so_ent: dict[int, JSProperty] = jo_ent_ro(so_raw);
        if key in so_ent {
            so_prop: JSProperty = so_ent[key];
            if not so_prop.writable {
                return False;
            }
            so_prop.value = val;
            jo_wb(so_raw, val);
            return True;
        }
    }
    # Not own: an inherited setter, read-only data property or exotic object
    # decides the outcome — leave those to the full path.
    so_pidx: int = jo_prototype_idx(so_raw);
    for _so_depth in range(PROTO_MAX_DEPTH) {
        if so_pidx <= 0 {
            break;
        }
        so_pr: int = so_pidx;
        if jo_class_id(so_pr) != 0
            or jo_bkind(so_pr) != 0
            or jo_elems_kind(so_pr) != ELEMS_NONE
            or (jo_cell_flags(so_pr) & (FLAG_MODULE_NS | FLAG_MAPPED_ARGS)) != 0
            or (jo_brand(so_pr) & BRAND_STRING_OBJ) != 0 {
            return False;
        }
        if _go_has_accessor(so_pr, key) {
            return False;
        }
        if jo_mode(so_pr) == MAP_MODE_SHAPE {
            so_pp: int = shape_lookup(jo_shape_id(so_pr), key);
            if so_pp >= 0 {
                if (so_pp & PROP_WRITABLE) == 0 {
                    return False;
                }
                break;
            }
        } else {
            so_pent: dict[int, JSProperty] = jo_ent_ro(so_pr);
            if key in so_pent {
                if not so_pent[key].writable {
                    return False;
                }
                break;
            }
        }
        so_pidx = jo_prototype_idx(so_pr);
    }
    if _obj_is_array_index_key_id(key) {
        return False;
    }
    return jo_set(so_raw, key, val, PROP_DEFAULT) == 0;
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
    oi_raw: int = oi_idx;
    if jo_mode(oi_raw) != MAP_MODE_SHAPE or not _go_write_plain(oi_raw) {
        return jsv_hole();
    }
    if jo_has_acc(oi_raw) and _go_acc_tables_have(oi_raw, key) {
        return jsv_hole();
    }
    oi_p: int = shape_lookup(jo_shape_id(oi_raw), key);
    if oi_p < 0 or (oi_p & SHAPE_ATTR_ACCESSOR) != 0 or (oi_p & PROP_WRITABLE) == 0 {
        return jsv_hole();
    }
    oi_old: JSValue = jo_sget(oi_raw, oi_p // 16);
    if not jsv_is_int32(oi_old) {
        return jsv_hole();
    }
    oi_new: int = jsv_to_int32(oi_old) + delta;
    if oi_new < -2147483648 or oi_new > 2147483647 {
        return jsv_hole();
    }
    jo_sset(oi_raw, oi_p // 16, js_int(oi_new));
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
    return jo_version(idx);
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
    n: int = jo_count();
    while i < n {
        os_o: int = i + 1;
        if jo_cell_flags(os_o) != CELL_FLAG_DEAD and (
            i >= _OBJ_REALM.objmark_len
            or read_byte(_OBJ_REALM.objmark_ptr, i) != 255
        ) {
            live = live + 1;
            if jo_mode(os_o) == 0 {
                dictm = dictm + 1;
            } else {
                shapem = shapem + 1;
            }
            sslots = sslots + jo_slen(os_o);
            sentries = sentries + len(jo_ent_ro(os_o));
            sko = sko + len(jo_ko_ro(os_o));
            if jo_has_ent(os_o) {
                ent_objs = ent_objs + 1;
            }
            if len(_acc_ro(os_o).getters) > 0 or len(_acc_ro(os_o).setters) > 0 {
                acc_objs = acc_objs + 1;
            }
            if jo_mapped_args(os_o) {
                mapped = mapped + 1;
            }
            if jo_elems_kind(os_o) != ELEMS_NONE {
                arr_objs = arr_objs + 1;
                selems = selems + jo_elen(os_o);
            }
            if jo_ep(os_o) != 0 {
                elem_objs = elem_objs + 1;
            }
            if jo_class_id(os_o) != 0 {
                classful = classful + 1;
            }
            if jo_bkind(os_o) != 0 {
                binaries = binaries + 1;
            }
            if (jo_cell_flags(os_o) & FLAG_MODULE_NS) != 0 {
                modns = modns + 1;
            }
        }
        i = i + 1;
    }
    heap_live: int = len(_OBJ_REALM.heap_strings)
        - hs_free_n();
    intern_n: int = len(_OBJ_REALM.intern_by_str);
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
    write(2, msg, str_nbytes(msg));
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
    raw: int = idx;
    if jo_mapped_args(raw) {
        return out;
    }  # aliased indices need the slow path
    # Non-materializing own-data lookup: get_property() would allocate a fresh
    # JSProperty per call, and on this ~75M-calls/build hot path the owned
    # result local leaked (~3GB, OOMed vite builds under --gc). has_own_data()
    # + get() are both scalar-returning and allocation-free.
    if not jo_has_own_data(raw, key) {
        return out;
    }
    # Accessor own properties are stored with getter/setter tables — if a getter
    # is registered, this is not a plain data prop.
    if key in _acc_ro(raw).getters or key in _acc_ro(raw).setters {
        return out;
    }
    out[0] = js_int(1);
    out[1] = jo_get(raw, key);
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
    raw: int = jsv_to_table_id(jsobj);
    if (jo_cell_flags(raw) & FLAG_IS_PROTO) != 0 {
        proto_epoch_bump();
    }
    if (jo_cell_flags(raw) & FLAG_IS_GLOBAL) != 0 {
        global_obj_note_write(key);
    }
    # An index-keyed prop landing on a PROTOTYPE object invalidates the dense
    # fast paths that skip prototype walks (hole/out-of-range reads, appends).
    if (jo_cell_flags(raw) & FLAG_IS_PROTO) != 0
        and idx_protector_ok()
        and _obj_is_array_index_key_id(key) {
        idx_protector_clear();
    }
    # Dense elements: in-range write / append / small-gap hole-fill stay
    # dense; big gaps or non-extensible new indices degrade or reject.
    if jo_elems_kind(raw) != ELEMS_NONE and _obj_is_array_index_key_id(key) {
        dsi: int = _obj_array_index_sort_key(key);
        dsn: int = jo_elen(raw);
        if dsi < dsn {
            jo_eset(raw, dsi, val);
            return 0;
        }
        # An arguments object's elements never grow past the arguments it was
        # made with: an index at or beyond them is an ordinary property (its
        # `length` does not follow, and an iterator over it stops at `length`).
        if (jo_cell_flags(raw) & FLAG_IS_ARGUMENTS) != 0 {
            jo_ensure_sparse(raw);
        } elif jo_is_ext(raw) {
            if dsi == dsn {
                jo_epush(raw, val);
                return 0;
            }
            if dsi <= dsn + DENSE_GAP_MAX {
                while jo_elen(raw) < dsi {
                    jo_epush(raw, jsv_hole());
                }
                jo_epush(raw, val);
                jo_set_elems_kind(raw, ELEMS_HOLEY);
                return 0;
            }
            jo_ensure_sparse(raw);
        } else {
            return 1;
        }
    }
    # Array-index keys would each mint a transition (per-index shape chains,
    # e.g. filling an array-like) — send them to dict mode instead. Dense
    # element storage is a separate workstream (interpreter_optimizations §3).
    # Accessor-owned keys also convert first: dict-mode [[Set]] treats an
    # accessor-only key as "no data property" (VM handles the setter before
    # ever reaching here) and that semantic must survive the mode change.
    if jo_mode(raw) == MAP_MODE_SHAPE {
        sgp: int = shape_lookup(jo_shape_id(raw), key);
        w_acc: bool = sgp >= 0 and (sgp & SHAPE_ATTR_ACCESSOR) != 0;
        w_idx: bool = _obj_is_array_index_key_id(key);
        # An existing writable data property: [[Set]] only replaces the
        # value, so write its slot. The general path below looked the key up
        # three more times (has_key, get_property -- which allocates -- and
        # set) for the same answer, on ~113M writes in a vite build.
        if sgp >= 0
            and not w_acc
            and not w_idx
            and not jo_mapped_args(raw)
            and not jo_has_acc(raw) {
            if (sgp & PROP_WRITABLE) == 0 {
                return 1;
            }
            jo_sset(raw, sgp // 16, val);
            return 0;
        }
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
                    write(2, dm, str_nbytes(dm));
                }
            }
            jo_pm_ensure_dict(raw);
        }
    }
    if jo_has_key(raw, key) {
        prop: JSProperty = jo_get_property(raw, key);
        if not prop.writable {
            return 1;
        }
        # Mapped arguments: writing an aliased index writes the live parameter slot
        # (and the stored value, kept in sync for descriptor reads).
        if jo_mapped_args(raw) {
            st_ars: ArgsState = _args_row(jsv_to_table_id(jsobj));
            if key in st_ars.slot_map {
                ms: int = st_ars.slot_map[key];
                if ms >= 0 and ms < len(st_ars.locals) {
                    st_ars.locals[ms] = val;
                    jo_wb(raw, val);
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
        if jo_set(raw, key, val, existing_flags) != 0 {
            jo_pm_ensure_dict(raw);
            jo_set(raw, key, val, existing_flags);
        }
        return 0;
    }
    if not jo_is_ext(raw) {
        return 1;
    }
    if jo_set(raw, key, val, PROP_DEFAULT) != 0 {
        jo_pm_ensure_dict(raw);
        jo_set(raw, key, val, PROP_DEFAULT);
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
    raw: int = jsv_to_table_id(jsobj);
    if (jo_cell_flags(raw) & FLAG_IS_GLOBAL) != 0 {
        global_obj_note_write(key);
    }
    if jo_elems_kind(raw) != ELEMS_NONE and _obj_is_array_index_key_id(key) {
        jo_ensure_sparse(raw);
    }
    if jo_mode(raw) == MAP_MODE_SHAPE {
        sgf: int = shape_lookup(jo_shape_id(raw), key);
        if (sgf >= 0 and (sgf & SHAPE_ATTR_ACCESSOR) != 0)
            or _obj_is_array_index_key_id(key) {
            jo_pm_ensure_dict(raw);
        } else {
            # A data property or a new key: the shape entry is the property
            # record. has_key + get_property (which built a JSProperty) +
            # set's own lookup cost three more lookups and an allocation.
            if sgf >= 0 {
                if (sgf & PROP_WRITABLE) == 0 {
                    return 1;
                }
                if (sgf & 15) == (flags & 7) {
                    jo_sset(raw, sgf // 16, val);
                    return 0;
                }
            } elif not jo_is_ext(raw) {
                return 1;
            }
            if jo_set(raw, key, val, flags) != 0 {
                jo_pm_ensure_dict(raw);
                jo_set(raw, key, val, flags);
            }
            return 0;
        }
    }
    if jo_has_key(raw, key) {
        prop: JSProperty = jo_get_property(raw, key);
        if not prop.writable {
            return 1;
        }
    } elif not jo_is_ext(raw) {
        return 1;
    }
    if jo_set(raw, key, val, flags) != 0 {
        jo_pm_ensure_dict(raw);
        jo_set(raw, key, val, flags);
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
    raw: int = jsv_to_table_id(jsobj);
    if (jo_cell_flags(raw) & FLAG_IS_GLOBAL) != 0 {
        global_obj_note_write(key);
    }
    if jo_elems_kind(raw) != ELEMS_NONE and _obj_is_array_index_key_id(key) {
        jo_ensure_sparse(raw);
    }
    if jo_mode(raw) == MAP_MODE_SHAPE and jo_has_key(raw, key) {
        jo_pm_ensure_dict(raw);
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
        if jo_has_key(raw, key) {
            jo_delete(raw, key);
        }
        return True;
    }
    prop: JSProperty = jo_get_property(raw, key);
    if prop.key == 0 {
        return True;
    }
    if not prop.configurable {
        return False;
    }
    if jo_mapped_args(raw) {
        dl_ars: ArgsState = _args_row(jsv_to_table_id(jsobj));
        if key in dl_ars.slot_map {
            del dl_ars.slot_map[key];
        }
    }
    jo_delete(raw, key);
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
    raw: int = jsv_to_table_id(jsobj);
    if (jo_cell_flags(raw) & FLAG_IS_PROTO) != 0 {
        proto_epoch_bump();
    }
    if (jo_cell_flags(raw) & FLAG_IS_GLOBAL) != 0 {
        global_obj_note_write(key);
    }
    # Dense elements are configurable by construction: delete = punch a hole.
    if jo_elems_kind(raw) != ELEMS_NONE and _obj_is_array_index_key_id(key) {
        ddel: int = _obj_array_index_sort_key(key);
        if ddel < jo_elen(raw) and not jsv_is_hole(jo_eget(raw, ddel)) {
            jo_eset(raw, ddel, jsv_hole());
            jo_set_elems_kind(raw, ELEMS_HOLEY);
        }
        return True;
    }
    # Shape mode: any delete of an existing key (data or accessor) leaves
    # shape mode first, then the dict logic below applies verbatim.
    if jo_mode(raw) == MAP_MODE_SHAPE and jo_has_key(raw, key) {
        jo_pm_ensure_dict(raw);
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
        for acc_kk in jo_ko_ro(raw) {
            if acc_kk != key {
                acc_ko_new.append(acc_kk);
            }
        }
        jo_ext_rw(raw).key_order = acc_ko_new;
        return True;
    }
    prop: JSProperty = jo_get_property(raw, key);
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
    if jo_mapped_args(raw) {
        dl_ars: ArgsState = _args_row(jsv_to_table_id(jsobj));
        if key in dl_ars.slot_map {
            del dl_ars.slot_map[key];
        }
    }
    if prop.key != 0 {
        jo_delete(raw, key);
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
def _compact_key_order(raw: int) -> None {
    if jo_mode(raw) == MAP_MODE_SHAPE {
        return;
    }  # no tombstones in shape mode
    ko_c: list[int] = jo_ko_ro(raw);
    ent_c: dict[int, JSProperty] = jo_ent_ro(raw);
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
    jo_ext_rw(raw).key_order = ko_new;
}


# ═══════════════════════════════════════════════════════════════════════════════
# Public API — HasProperty / HasOwnProperty
# ═══════════════════════════════════════════════════════════════════════════════

"""[[HasOwnProperty]](obj, key) — own properties only. ECMAScript §10.1.7."""
def:pub js_object_has_own(jsobj: JSValue, key: int) -> bool {
    if not jsv_is_object_cell(jsobj) {
        return False;
    }
    ho_id: int = jsv_to_table_id(jsobj);
    if ho_id <= 0 {
        return False;
    }
    # Read through the table row (borrowed) unless the accessor tables are
    # needed: an owned _obj_get handle cost a retain and a release per call.
    ho_dix: int = -1;
    if jo_elems_kind(ho_id) != ELEMS_NONE {
        ho_dix = _obj_index_of_key(key);
    }
    if jo_has_own_plain(ho_id, key, ho_dix) {
        return True;
    }
    # No accessor side table: nothing else can hold the key. (The common
    # miss — marker-key probes on plain objects — paid four empty-table
    # lookups, each through its own AccessorTable reference.)
    if not jo_has_acc(ho_id) {
        return False;
    }
    return _ho_in_acc_tables(ho_id, key);
}

"""js_object_has_own's accessor-table probe (an owned row handle, kept out
of the common path)."""
def _ho_in_acc_tables(ho_id: int, key: int) -> bool {
    raw: int = ho_id;
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
    raw: int = jsv_to_table_id(jsobj);
    if jo_mode(raw) == MAP_MODE_SHAPE {
        hac: int = shape_lookup(jo_shape_id(raw), key);
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
        current: int = current_idx;
        if jo_elems_kind(current) != ELEMS_NONE and _obj_is_array_index_key_id(key) {
            dhp: int = _obj_array_index_sort_key(key);
            if dhp < jo_elen(current)
                and not jsv_is_hole(jo_eget(current, dhp)) {
                return True;
            }
        }
        if jo_has_key(current, key) {
            return True;
        }
        if jo_has_acc(current)
            and (key in _acc_ro(current).getters or key in _acc_ro(current).setters) {
            return True;
        }
        current_idx = jo_prototype_idx(current);
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

"""The array index key id `kid` names, or -1 when it is not an array-index
key (_obj_is_array_index_key_id then _obj_array_index_sort_key)."""
def _obj_index_of_key(kid: int) -> int {
    if not _obj_is_array_index_key_id(kid) {
        return -1;
    }
    return _obj_array_index_sort_key(kid);
}

def _obj_array_index_sort_key(kid: int) -> int {
    # Canonical index keys (all the dense-element paths pass) read the
    # per-id memo instead of re-parsing the key text on every lookup.
    sk_v: int = str_id_array_index_value(kid);
    if sk_v >= 0 {
        return sk_v;
    }
    s: str = str_from_id(kid);
    np: int = 0;
    pi: int = 0;
    sn: int = str_nbytes(s);
    # Byte-wise digit test: the previous `ch: str = str_substr(...)` per digit
    # parked an owned 1-byte str in a named local that is never released — two
    # leaked allocations per array-index property get (Array.prototype.join over
    # 800 elements retained 100KB per call).
    while pi < sn {
        cc: int = str_byte(s, pi);
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
    raw: int = jsv_to_table_id(jsobj);
    if jo_class_id(raw) != 0 {
        return False;
    }
    if len(_acc_ro(raw).getters) != 0 or len(_acc_ro(raw).setters) != 0 {
        return False;
    }
    if jo_mapped_args(raw) or (jo_cell_flags(raw) & FLAG_MODULE_NS) != 0 {
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
    raw: int = jsv_to_table_id(jsobj);
    if jo_elems_kind(raw) != ELEMS_NONE {
        de_i: int = from_idx;
        if de_i < 0 {
            de_i = 0;
        }
        de_n: int = jo_elen(raw);
        if de_n > n {
            de_n = n;
        }
        while de_i < de_n {
            if not jsv_is_hole(jo_eget(raw, de_i)) {
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
        if pr_k >= 0 and jo_has_key(raw, pr_k) {
            return pr_i;
        }
        pr_i = pr_i + 1;
    }
    if pr_end >= n {
        return n;
    }
    # A gap wider than the window: the minimum array-index key in [pr_end, n).
    best: int = n;
    for kid in jo_all_keys(raw) {
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
    en_id: int = jsv_to_table_id(jsobj);
    if jo_elems_kind(en_id) != ELEMS_NONE
        and _obj_is_array_index_key_id(kid) {
        den: int = _obj_array_index_sort_key(kid);
        return den < jo_elen(en_id)
            and not jsv_is_hole(jo_eget(en_id, den));
    }
    # Shape mode: data AND accessor entries answer from the packed attrs
    # (get_property reports accessors as not-found, so it can't be used here).
    if jo_mode(en_id) == MAP_MODE_SHAPE {
        oke: int = shape_lookup(jo_shape_id(en_id), kid);
        if oke >= 0 {
            return (oke & PROP_ENUMERABLE) != 0;
        }
        return False;
    }
    return _own_key_enumerable_dict(en_id, kid);
}

"""js_object_own_key_is_enumerable_now's dict-mode half (an owned row
handle and a descriptor, kept out of the shape-mode path)."""
def _own_key_enumerable_dict(en_id: int, kid: int) -> bool {
    raw_e: int = en_id;
    p_e: JSProperty = jo_get_property(raw_e, kid);
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
    if jo_mode(sp_id) != MAP_MODE_SHAPE
        or jo_elems_kind(sp_id) != ELEMS_NONE
        or jo_class_id(sp_id) != 0
        or jo_bkind(sp_id) != 0
        or jo_brand(sp_id) != 0
        or (
            jo_cell_flags(sp_id)
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
    sp_sid: int = jo_shape_id(sp_id);
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
    if jo_mode(ok_id) == MAP_MODE_SHAPE
        and jo_elems_kind(ok_id) == ELEMS_NONE
        and jo_class_id(ok_id) == 0
        and jo_bkind(ok_id) == 0 {
        ok_sid = jo_shape_id(ok_id);
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
    raw: int = jsv_to_table_id(jsobj);
    result: list[int] = [];
    if jo_mode(raw) == MAP_MODE_SHAPE {
        agk: list[int] = shape_keys(jo_shape_id(raw));
        agk_n: int = shape_key_count(jo_shape_id(raw));
        agi: int = 0;
        while agi < agk_n {
            agp: int = shape_lookup(jo_shape_id(raw), agk[agi]);
            if agp >= 0
                and (agp & SHAPE_ATTR_ACCESSOR) != 0
                and not jsv_is_undefined(jo_sget(raw, agp // 16)) {
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
    raw: int = jsv_to_table_id(jsobj);
    if jo_elems_kind(raw) != ELEMS_NONE {
        akd: list[int] = [];
        akd_i: int = 0;
        while akd_i < jo_elen(raw) {
            if not jsv_is_hole(jo_eget(raw, akd_i)) {
                akd.append(str_intern_index(akd_i));
            }
            akd_i = akd_i + 1;
        }
        for akd_k in jo_all_keys(raw) {
            akd.append(akd_k);
        }
        return akd;
    }
    # Shape mode: the shape chain IS the insertion order — data and accessor
    # entries alike — with no tombstones, so no liveness or dedupe filtering.
    if jo_mode(raw) == MAP_MODE_SHAPE {
        return jo_all_keys(raw);
    }
    # Walk insertion order, including accessor-only keys (which live in the
    # accessor dicts, not `entries`, but were appended to key_order on install).
    # Dedupe stale key_order entries (safety net if delete missed a purge).
    result: list[int] = [];
    seen: dict[int, bool] = {};
    ko_ak: list[int] = jo_ko_ro(raw);
    ent_ak: dict[int, JSProperty] = jo_ent_ro(raw);
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

"""Whether the marker must still visit `v`, a value held by an object. An
object child already marked this cycle is (being) traced: pushing it only
made _gc_trace_one pop it, decode it and find the mark. Objects share
prototypes, constructors and module records heavily, so most object edges in
a big heap lead somewhere already marked. Non-cells, interned strings (never
collected), symbols and bigints have nothing to mark; heap strings and
functions are left to _gc_trace_one."""
def _gc_child_pending(v: JSValue, mp: int, mn: int, epoch: int) -> bool {
    if not jsv_is_cell(v) {
        return False;
    }
    gcp_k: int = jsv_cell_kind(v);
    if gcp_k == JS_CELL_KIND_OBJECT or gcp_k == JS_CELL_KIND_HTMLDDA {
        gcp_i: int = jsv_to_table_id(v) - 1;
        return gcp_i < 0 or gcp_i >= mn or read_byte(mp, gcp_i) != epoch;
    }
    if gcp_k == JS_CELL_KIND_STRING {
        return jsv_to_table_id(v) >= HEAP_STRING_BASE;
    }
    return gcp_k == JS_CELL_KIND_NATIVE;
}

"""js_object_gc_children's walk, appending to the GC's work list directly and
skipping non-cells (the tracer drops them on pop anyway): no per-object
result list — that was one allocation plus regrowth for every traced object
(~37M in a vite build) — and absent dict / accessor tables are not walked."""
def:pub js_object_gc_push_children(idx: int, work: list[JSValue]) -> None {
    if idx <= 0 {
        return;
    }
    raw: int = idx;
    pc_mp: int = _OBJ_REALM.objmark_ptr;
    pc_mn: int = _OBJ_REALM.objmark_len;
    pc_epoch: int = gc_mark_byte(_OBJ_REALM);
    si: int = 0;
    sn: int = jo_slen(raw);
    while si < sn {
        pc_sv: JSValue = jo_sget(raw, si);
        if _gc_child_pending(pc_sv, pc_mp, pc_mn, pc_epoch) {
            work.append(pc_sv);
        }
        si = si + 1;
    }
    if jo_ep(raw) != 0 {
        ei: int = 0;
        en: int = jo_elen(raw);
        while ei < en {
            pc_ev: JSValue = jo_eget(raw, ei);
            if _gc_child_pending(pc_ev, pc_mp, pc_mn, pc_epoch) {
                work.append(pc_ev);
            }
            ei = ei + 1;
        }
    }
    if jo_has_ent(raw) {
        pc_ent: dict[int, JSProperty] = jo_ent_ro(raw);
        for k in pc_ent {
            if jsv_is_cell(pc_ent[k].value) {
                work.append(pc_ent[k].value);
            }
        }
    }
    if jo_has_acc(raw) {
        for k in _acc_ro(raw).getters {
            work.append(_acc_ro(raw).getters[k]);
        }
        for k in _acc_ro(raw).setters {
            work.append(_acc_ro(raw).setters[k]);
        }
    }
    # Proxy [[ProxyTarget]] / [[ProxyHandler]] and the mapped-arguments row:
    # see js_object_gc_children below.
    if jo_class_id(raw) == 1 and idx in _OBJ_REALM.proxy_slots {
        work.append(_OBJ_REALM.proxy_slots[idx].target);
        work.append(_OBJ_REALM.proxy_slots[idx].handler);
    }
    if jo_mapped_args(raw) and idx in _OBJ_REALM.args_slots {
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
    raw: int = idx;
    # Shape-mode values live in the flat slots list. Missing this walk is a
    # use-after-free factory: slot values would be invisible to the marker.
    si: int = 0;
    while si < jo_slen(raw) {
        out.append(jo_sget(raw, si));
        si = si + 1;
    }
    # Dense array elements likewise (hole sentinels are non-cells — the
    # tracer ignores them, so no filtering needed here).
    ei: int = 0;
    while ei < jo_elen(raw) {
        out.append(jo_eget(raw, ei));
        ei = ei + 1;
    }
    ent_gc: dict[int, JSProperty] = jo_ent_ro(raw);
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
    if jo_class_id(raw) == 1 and idx in _OBJ_REALM.proxy_slots {
        px_gc: ProxyState = _OBJ_REALM.proxy_slots[idx];
        out.append(px_gc.target);
        out.append(px_gc.handler);
    }
    # Mapped-arguments row: `locals` aliases the activation's live locals list, so
    # its entries must stay reachable while the arguments object is live (Phase 1).
    if jo_mapped_args(raw) and idx in _OBJ_REALM.args_slots {
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
    # The common case without a descriptor record: a plain shape-mode object
    # (js_object_plain_shape_id), not the global object, and a non-index key
    # that is an own {w,e,c} data property (its value replaced) or absent
    # from an extensible object (added) — what ValidateAndApply leaves.
    cd_sid: int = js_object_plain_shape_id(jsobj);
    if cd_sid >= 0 and not _obj_is_array_index_key_id(key) {
        cd_id: int = jsv_to_table_id(jsobj);
        if (jo_cell_flags(cd_id) & FLAG_IS_GLOBAL) == 0 {
            cd_p: int = shape_lookup(cd_sid, key);
            if cd_p >= 0 {
                if (cd_p & 15) == PROP_DEFAULT {
                    jo_sset(cd_id, cd_p // 16, val);
                    return 0;
                }
            } elif jo_is_ext(cd_id)
                and jo_set(cd_id, key, val, PROP_DEFAULT) == 0 {
                return 0;
            }
        }
    }
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
    raw: int = jsv_to_table_id(jsobj);
    # Integrity ops rewrite every descriptor in place — dict mode's job
    # (Phase 6 may revisit with frozen-shape flags; freeze is rare).
    jo_ensure_sparse(raw);
    jo_pm_ensure_dict(raw);
    ks: list[int] = jo_all_keys(raw);
    for k in ks {
        prop: JSProperty = jo_get_property(raw, k);
        if prop.key != 0 {
            # Clear writable + configurable; preserve enumerable.
            flags: int = 0;
            if prop.enumerable {
                flags = flags | PROP_ENUMERABLE;
            }
            jo_set(raw, k, prop.value, flags);
        }
    }
    # Accessors: clear configurable only (writable is N/A).
    for ak in _acc_ro(raw).getters {
        _acc_rw(raw).configurable[ak] = False;
    }
    for ak2 in _acc_ro(raw).setters {
        _acc_rw(raw).configurable[ak2] = False;
    }
    jo_set_non_ext(raw);
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
    raw: int = jsv_to_table_id(jsobj);
    jo_ensure_sparse(raw);
    jo_pm_ensure_dict(raw);  # in-place descriptor rewrite below is dict-only
    ks: list[int] = jo_all_keys(raw);
    for k in ks {
        prop: JSProperty = jo_get_property(raw, k);
        if prop.key != 0 {
            flags: int = 0;
            if prop.writable {
                flags = flags | PROP_WRITABLE;
            }
            if prop.enumerable {
                flags = flags | PROP_ENUMERABLE;
            }
            # configurable cleared
            jo_set(raw, k, prop.value, flags);
        }
    }
    for ak in _acc_ro(raw).getters {
        _acc_rw(raw).configurable[ak] = False;
    }
    for ak2 in _acc_ro(raw).setters {
        _acc_rw(raw).configurable[ak2] = False;
    }
    jo_set_non_ext(raw);
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
    raw: int = jsv_to_table_id(jsobj);
    jo_set_non_ext(raw);
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
    raw: int = jsv_to_table_id(jsobj);
    # Module Namespace Exotic [[IsExtensible]] always returns false (§10.4.6.3),
    # even while the engine still allows privileged export-key installation
    # (raw.is_ext() may remain true until finalize).
    if (jo_cell_flags(raw) & FLAG_MODULE_NS) != 0 {
        return False;
    }
    return jo_is_ext(raw);
}

"""True if `jsobj` is a Module Namespace Exotic Object (§10.4.6)."""
def:pub js_is_module_namespace(jsobj: JSValue) -> bool {
    if not jsv_is_object_cell(jsobj) {
        return False;
    }
    if jsv_to_table_id(jsobj) <= 0 {
        return False;
    }
    # Scalar read of the flags (no owned JSObject handle): asked ~50M times in a
    # vite build, on every namespace-sensitive property access.
    mn_id: int = jsv_to_table_id(jsobj);
    if mn_id > jo_count() {
        return False;
    }
    return (jo_cell_flags(mn_id) & FLAG_MODULE_NS) != 0;
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
    raw: int = jsv_to_table_id(jsobj);
    jo_set_cell_flags(raw, jo_cell_flags(raw) | FLAG_MODULE_NS);
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
    raw: int = jsv_to_table_id(jsobj);
    # Namespace objects get non-default flags and later in-place descriptor
    # rewrites (finalize) — dict mode from the first binding.
    jo_pm_ensure_dict(raw);
    flags: int = PROP_WRITABLE | PROP_ENUMERABLE;
    if key >= SYMBOL_KEY_BASE {
        flags = 0;
    }
    jo_set(raw, key, val, flags);
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
    raw: int = jsv_to_table_id(jsobj);
    jo_pm_ensure_dict(raw);  # in-place entries rewrite below is dict-only
    jo_set_cell_flags(raw, jo_cell_flags(raw) | FLAG_MODULE_NS);
    keys: list[int] = jo_all_keys(raw);
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
        } elif kid in jo_ent_ro(raw) {
            prop: JSProperty = jo_ent_ro(raw)[kid];
            is_sym: bool = kid >= SYMBOL_KEY_BASE;
            w: bool = True;
            e: bool = True;
            if is_sym {
                w = False;
                e = False;
            }
            jo_ent_rw(raw)[kid] = JSProperty(
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
    jo_set_non_ext(raw);
}

"""Object.isFrozen(jsobj). ECMAScript §20.1.2.12."""
def:pub js_object_is_frozen(jsobj: JSValue) -> bool {
    if not jsv_is_object_cell(jsobj) {
        return True;  # primitives are trivially frozen per spec
    }
    if jsv_to_table_id(jsobj) <= 0 {
        return True;
    }
    raw: int = jsv_to_table_id(jsobj);
    if jo_is_ext(raw) {
        return False;
    }
    if jo_elems_kind(raw) != ELEMS_NONE {
        ifd: int = 0;
        while ifd < jo_elen(raw) {
            if not jsv_is_hole(jo_eget(raw, ifd)) {
                return False;
            }
            ifd = ifd + 1;
        }
    }
    # Shape mode: get_property hides accessors (and freeze converts to dict),
    # so a non-frozen shape object answers from the packed attrs directly.
    if jo_mode(raw) == MAP_MODE_SHAPE {
        ifk: list[int] = shape_keys(jo_shape_id(raw));
        ifk_n: int = shape_key_count(jo_shape_id(raw));
        ifi: int = 0;
        while ifi < ifk_n {
            ifp: int = shape_lookup(jo_shape_id(raw), ifk[ifi]);
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
    ks: list[int] = jo_all_keys(raw);
    for k in ks {
        prop: JSProperty = jo_get_property(raw, k);
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
    raw: int = jsv_to_table_id(jsobj);
    if jo_is_ext(raw) {
        return False;
    }
    if jo_elems_kind(raw) != ELEMS_NONE {
        isd: int = 0;
        while isd < jo_elen(raw) {
            if not jsv_is_hole(jo_eget(raw, isd)) {
                return False;
            }
            isd = isd + 1;
        }
    }
    if jo_mode(raw) == MAP_MODE_SHAPE {
        isk: list[int] = shape_keys(jo_shape_id(raw));
        isk_n: int = shape_key_count(jo_shape_id(raw));
        isi: int = 0;
        while isi < isk_n {
            isp: int = shape_lookup(jo_shape_id(raw), isk[isi]);
            if isp >= 0 and (isp & PROP_CONFIGURABLE) != 0 {
                return False;
            }
            isi = isi + 1;
        }
        return True;
    }
    ks: list[int] = jo_all_keys(raw);
    for k in ks {
        prop: JSProperty = jo_get_property(raw, k);
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
    raw: int = jsv_to_table_id(jsobj);
    if jo_prototype_idx(raw) == -1 {
        return js_null();
    }
    return _obj_wrap(jo_prototype_idx(raw));
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
        walk = jo_prototype_idx(walk);
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
    raw: int = obj_idx;
    new_proto_idx: int = -1;
    if jsv_is_object_cell(proto) and jsv_to_table_id(proto) > 0 {
        new_proto_idx = jsv_to_table_id(proto);
    }
    # ES §10.1.14 / Reflect.setPrototypeOf: same current [[Prototype]] succeeds
    # even when the object is non-extensible (before the extensibility rejection).
    if jo_prototype_idx(raw) == new_proto_idx {
        return 0;
    }
    # Module Namespace Exotic [[SetPrototypeOf]] → SetImmutablePrototype (§10.4.6.2):
    # only the current [[Prototype]] (always null) is accepted; any other V → false.
    if (jo_cell_flags(raw) & FLAG_MODULE_NS) != 0 {
        return 1;
    }
    if not jo_is_ext(raw) {
        return 1;
    }
    if _proto_would_cycle(obj_idx, new_proto_idx) {
        return 1;
    }
    jo_set_prototype_idx(raw, new_proto_idx);
    jo_wb_all(raw);
    # Re-linking a prototype changes the chain of every object inheriting from
    # it: invalidate inherited-read ICs (a non-prototype receiver's own link is
    # checked by the IC itself).
    if (jo_cell_flags(raw) & FLAG_IS_PROTO) != 0 {
        proto_epoch_bump();
    }
    # Dense-elements protector: the new prototype may ALREADY carry index
    # properties (e.g. Object.setPrototypeOf(x, [5, 6])). Flag it, and clear
    # the protector if any index-keyed own prop (or dense element) exists on
    # it. Objects deeper in its chain were already prototypes — any index
    # props they gained cleared the protector at write time.
    if new_proto_idx > 0 {
        np_raw: int = new_proto_idx;
        jo_set_cell_flags(np_raw, jo_cell_flags(np_raw) | FLAG_IS_PROTO);
        if idx_protector_ok() {
            if jo_class_id(np_raw) != 0 {
                idx_protector_clear();
            } elif jo_elems_kind(np_raw) != ELEMS_NONE and jo_elen(np_raw) > 0 {
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
    raw: int = jsv_to_table_id(jsobj);
    if (jo_cell_flags(raw) & FLAG_IS_PROTO) != 0 {
        proto_epoch_bump();
    }
    if (jo_cell_flags(raw) & FLAG_IS_GLOBAL) != 0 {
        global_obj_note_write(key);
    }
    # Accessor-owned keys must not grow a parallel data property.  ValidateAndApply
    # converts accessor→data by deleting the accessor first; installing data here
    # would fight the record merge (and fail spuriously after preventExtensions).
    if key in _acc_ro(raw).getters or key in _acc_ro(raw).setters {
        return 1;
    }
    if (jo_cell_flags(raw) & FLAG_IS_PROTO) != 0
        and idx_protector_ok()
        and _obj_is_array_index_key_id(key) {
        idx_protector_clear();
    }
    if jo_elems_kind(raw) != ELEMS_NONE and _obj_is_array_index_key_id(key) {
        if descriptor.writable and descriptor.enumerable and descriptor.configurable {
            ddi: int = _obj_array_index_sort_key(key);
            ddn: int = jo_elen(raw);
            if ddi < ddn {
                jo_eset(raw, ddi, descriptor.value);
                return 0;
            }
            if ddi == ddn and jo_is_ext(raw) {
                jo_epush(raw, descriptor.value);
                return 0;
            }
        }
        jo_ensure_sparse(raw);
    }
    if jo_mode(raw) == MAP_MODE_SHAPE {
        dpk: int = shape_lookup(jo_shape_id(raw), key);
        if dpk >= 0 and (dpk & SHAPE_ATTR_ACCESSOR) != 0 {
            return 1;
        }
        if _obj_is_array_index_key_id(key) {
            jo_pm_ensure_dict(raw);
        }
    }
    existing: JSProperty = jo_get_property(raw, key);
    # Mapped arguments index: validate against the *live* parameter value, not the
    # stale stored one (ES §10.4.4.2 runs OrdinaryDefineOwnProperty on the current
    # state, which for a mapped index is the parameter binding).
    dpf_idx: int = jsv_to_table_id(jsobj);
    dp_is_mapped: bool = False;
    if jo_mapped_args(raw) and existing.key != 0 {
        if key in _args_row(dpf_idx).slot_map {
            dp_is_mapped = True;
        }
    }
    if dp_is_mapped {
        dpf_ars: ArgsState = _args_row(dpf_idx);
        dpm_slot: int = dpf_ars.slot_map[key];
        if dpm_slot >= 0 and dpm_slot < len(dpf_ars.locals) {
            existing.value = dpf_ars.locals[dpm_slot];
            jo_wb(raw, existing.value);
        }
    }
    if existing.key == 0 {
        if not jo_is_ext(raw) {
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
    if jo_set(raw, key, descriptor.value, flags) != 0 {
        jo_pm_ensure_dict(raw);
        jo_set(raw, key, descriptor.value, flags);
    }
    # Mapped-arguments post-step (ES §10.4.4.2): write the new value to the
    # parameter, then de-map if the redefinition made it non-writable.
    if dp_is_mapped {
        dpf_ars2: ArgsState = _args_row(dpf_idx);
        dpm_slot2: int = dpf_ars2.slot_map[key];
        if dpm_slot2 >= 0 and dpm_slot2 < len(dpf_ars2.locals) {
            dpf_ars2.locals[dpm_slot2] = descriptor.value;
            jo_wb(raw, descriptor.value);
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
    raw: int = jsv_to_table_id(jsobj);
    if (jo_cell_flags(raw) & FLAG_IS_GLOBAL) != 0 {
        global_obj_note_write(key);
    }
    if key in _acc_ro(raw).getters or key in _acc_ro(raw).setters {
        return 1;
    }
    if (jo_cell_flags(raw) & FLAG_IS_PROTO) != 0
        and idx_protector_ok()
        and _obj_is_array_index_key_id(key) {
        idx_protector_clear();
    }
    if jo_elems_kind(raw) != ELEMS_NONE and _obj_is_array_index_key_id(key) {
        if descriptor.writable and descriptor.enumerable and descriptor.configurable {
            avi: int = _obj_array_index_sort_key(key);
            avn: int = jo_elen(raw);
            if avi < avn {
                jo_eset(raw, avi, descriptor.value);
                return 0;
            }
            if avi == avn and jo_is_ext(raw) {
                jo_epush(raw, descriptor.value);
                return 0;
            }
        }
        jo_ensure_sparse(raw);
    }
    if jo_mode(raw) == MAP_MODE_SHAPE {
        avk: int = shape_lookup(jo_shape_id(raw), key);
        if avk >= 0 and (avk & SHAPE_ATTR_ACCESSOR) != 0 {
            return 1;
        }
        if _obj_is_array_index_key_id(key) {
            jo_pm_ensure_dict(raw);
        }
    }
    av_idx: int = jsv_to_table_id(jsobj);
    dp_is_mapped: bool = False;
    if jo_mapped_args(raw) {
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
    if jo_set(raw, key, descriptor.value, flags) != 0 {
        jo_pm_ensure_dict(raw);
        jo_set(raw, key, descriptor.value, flags);
    }
    if dp_is_mapped {
        av_ars: ArgsState = _args_row(av_idx);
        dpm_slot2: int = av_ars.slot_map[key];
        if dpm_slot2 >= 0 and dpm_slot2 < len(av_ars.locals) {
            av_ars.locals[dpm_slot2] = descriptor.value;
            jo_wb(raw, descriptor.value);
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
    raw: int = jsv_to_table_id(jsobj);
    # Dense element: a plain writable/enumerable/configurable data descriptor.
    if jo_elems_kind(raw) != ELEMS_NONE and _obj_is_array_index_key_id(key) {
        dgp: int = _obj_array_index_sort_key(key);
        if dgp < jo_elen(raw) and not jsv_is_hole(jo_eget(raw, dgp)) {
            return JSProperty(
                key=key,
                value=jo_eget(raw, dgp),
                writable=True,
                enumerable=True,
                configurable=True,
                deleted=False
            );
        }
    }
    # Shape-mode accessor: surface the present, correctly-flagged descriptor
    # from the packed attrs (get/set values come from get_own_accessor_*).
    if jo_mode(raw) == MAP_MODE_SHAPE {
        gsk: int = shape_lookup(jo_shape_id(raw), key);
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
    gopd_p: JSProperty = jo_get_property(raw, key);
    # Mapped arguments: the descriptor's value reflects the live parameter slot.
    if gopd_p.key != 0 and jo_mapped_args(raw) {
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
    jo_set_arguments(oid);
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
    raw: int = ma_idx;
    jo_pm_ensure_dict(raw);  # aliased indices never take the shape path
    jo_set_mapped_args(raw);
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
    raw: int = ua_idx;
    if jo_mapped_args(raw) {
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
    raw: int = mv_idx;
    if jo_mapped_args(raw) {
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
    return jo_mapped_args(oid) or jo_arguments_obj(oid);
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
    raw: int = am_idx;
    if not jo_mapped_args(raw) {
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
    raw: int = jsv_to_table_id(jsobj);
    if (jo_cell_flags(raw) & FLAG_IS_PROTO) != 0 {
        proto_epoch_bump();
    }
    if (jo_cell_flags(raw) & FLAG_IS_GLOBAL) != 0 {
        global_obj_note_write(key);
    }
    if idx_protector_ok()
        and _obj_is_array_index_key_id(key)
        and (jo_cell_flags(raw) & FLAG_IS_PROTO) != 0 {
        idx_protector_clear();
    }
    if jo_elems_kind(raw) != ELEMS_NONE and _obj_is_array_index_key_id(key) {
        jo_ensure_sparse(raw);
    }
    # Shape mode: accessors are 2-slot (getter, setter) shape entries with
    # SHAPE_ATTR_ACCESSOR. New keys transition; an existing accessor rewrites
    # its getter slot in place; a data→accessor kind change goes to dict mode.
    # (Mapped-arguments objects are always dict mode — the de-map below never
    # applies on the shape arm.)
    if jo_mode(raw) == MAP_MODE_SHAPE {
        sag: int = shape_lookup(jo_shape_id(raw), key);
        if sag >= 0 and (sag & SHAPE_ATTR_ACCESSOR) != 0 {
            jo_sset(raw, sag // 16, getter_fn);
            return 0;
        }
        if sag < 0 {
            sag_child: int = shape_transition_add(
                jo_shape_id(raw),
                key,
                SHAPE_ATTR_ACCESSOR | PROP_ENUMERABLE | PROP_CONFIGURABLE
            );
            if sag_child > 0 {
                jo_set_shape_id(raw, sag_child);
                jo_spush(raw, getter_fn);
                jo_spush(raw, js_undefined());
                jo_set_version(raw, jo_version(raw) + 1);
                return 0;
            }
        }
        jo_pm_ensure_dict(raw);
    }
    _register_accessor_key(raw, key);
    _acc_rw(raw).getters[key] = getter_fn;
    jo_wb(raw, getter_fn);
    # Mapped arguments: turning an aliased index into an accessor de-maps it
    # (ES §10.4.4.2 — an accessor descriptor removes the parameter mapping).
    if jo_mapped_args(raw) {
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
def _register_accessor_key(raw: int, key: int) {
    # Accessor storage lives in the side dicts + key_order until Phase 4 —
    # a shape-mode object leaves shape mode at its first accessor.
    jo_pm_ensure_dict(raw);
    # Append only when absent from insertion order.  Data→accessor conversion
    # deletes the data entry but leaves the key in key_order; re-appending
    # duplicates enumeration (Object.keys / entries live semantics).
    in_order: bool = False;
    for ko in jo_ko_ro(raw) {
        if ko == key {
            in_order = True;
            break;
        }
    }
    if not in_order {
        jo_ko_rw(raw).append(key);
    }
    # Drop any stale data-property sentinel so it cannot fight accessor
    # [[Enumerable]]/[[Configurable]] during later DefineOwnProperty / integrity.
    if key in jo_ent_ro(raw) {
        jo_delete(raw, key);
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
    raw: int = jsv_to_table_id(jsobj);
    # An absent key gets a blind side-dict row below, which makes it an own
    # accessor: that can shadow an inherited property an IC cached.
    if (jo_cell_flags(raw) & FLAG_IS_PROTO) != 0 {
        proto_epoch_bump();
    }
    # Shape mode: an existing accessor's flag flip is an attrs-change replay —
    # the common class-installation pattern (install getter, then
    # enumerable=false) stays in shape mode. Anything else (data key, absent
    # key) reproduces dict mode's blind side-dict seed after converting.
    if jo_mode(raw) == MAP_MODE_SHAPE {
        sae: int = shape_lookup(jo_shape_id(raw), key);
        if sae >= 0 and (sae & SHAPE_ATTR_ACCESSOR) != 0 {
            sae_new: int = (sae & 15) & (15 - PROP_ENUMERABLE);
            if enumerable {
                sae_new = sae_new | PROP_ENUMERABLE;
            }
            if sae_new == (sae & 15) {
                return;
            }
            sae_sid: int = shape_change_attrs(jo_shape_id(raw), key, sae_new);
            if sae_sid >= 0 {
                jo_set_shape_id(raw, sae_sid);
                return;
            }
        }
        jo_pm_ensure_dict(raw);
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
    raw: int = jsv_to_table_id(jsobj);
    # See js_object_set_accessor_enumerable: may create an own accessor row.
    if (jo_cell_flags(raw) & FLAG_IS_PROTO) != 0 {
        proto_epoch_bump();
    }
    if jo_mode(raw) == MAP_MODE_SHAPE {
        sac: int = shape_lookup(jo_shape_id(raw), key);
        if sac >= 0 and (sac & SHAPE_ATTR_ACCESSOR) != 0 {
            sac_new: int = (sac & 15) & (15 - PROP_CONFIGURABLE);
            if configurable {
                sac_new = sac_new | PROP_CONFIGURABLE;
            }
            if sac_new == (sac & 15) {
                return;
            }
            sac_sid: int = shape_change_attrs(jo_shape_id(raw), key, sac_new);
            if sac_sid >= 0 {
                jo_set_shape_id(raw, sac_sid);
                return;
            }
        }
        jo_pm_ensure_dict(raw);
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
    raw: int = jsv_to_table_id(jsobj);
    if (jo_cell_flags(raw) & FLAG_IS_PROTO) != 0 {
        proto_epoch_bump();
    }
    if (jo_cell_flags(raw) & FLAG_IS_GLOBAL) != 0 {
        global_obj_note_write(key);
    }
    if idx_protector_ok()
        and _obj_is_array_index_key_id(key)
        and (jo_cell_flags(raw) & FLAG_IS_PROTO) != 0 {
        idx_protector_clear();
    }
    if jo_elems_kind(raw) != ELEMS_NONE and _obj_is_array_index_key_id(key) {
        jo_ensure_sparse(raw);
    }
    if jo_mode(raw) == MAP_MODE_SHAPE {
        sas: int = shape_lookup(jo_shape_id(raw), key);
        if sas >= 0 and (sas & SHAPE_ATTR_ACCESSOR) != 0 {
            jo_sset(raw, sas // 16 + 1, setter_fn);
            return 0;
        }
        if sas < 0 {
            sas_child: int = shape_transition_add(
                jo_shape_id(raw),
                key,
                SHAPE_ATTR_ACCESSOR | PROP_ENUMERABLE | PROP_CONFIGURABLE
            );
            if sas_child > 0 {
                jo_set_shape_id(raw, sas_child);
                jo_spush(raw, js_undefined());
                jo_spush(raw, setter_fn);
                jo_set_version(raw, jo_version(raw) + 1);
                return 0;
            }
        }
        jo_pm_ensure_dict(raw);
    }
    _register_accessor_key(raw, key);
    _acc_rw(raw).setters[key] = setter_fn;
    jo_wb(raw, setter_fn);
    # Mapped arguments: an accessor setter de-maps the aliased index (see getter).
    if jo_mapped_args(raw) {
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
    raw: int = jsv_to_table_id(jsobj);
    if jo_mode(raw) == MAP_MODE_SHAPE {
        gag: int = shape_lookup(jo_shape_id(raw), key);
        if gag >= 0 and (gag & SHAPE_ATTR_ACCESSOR) != 0 {
            return jo_sget(raw, gag // 16);
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
    raw: int = jsv_to_table_id(jsobj);
    if jo_mode(raw) == MAP_MODE_SHAPE {
        gas: int = shape_lookup(jo_shape_id(raw), key);
        if gas >= 0 and (gas & SHAPE_ATTR_ACCESSOR) != 0 {
            return jo_sget(raw, gas // 16 + 1);
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
        current: int = current_idx;
        if jo_elems_kind(current) != ELEMS_NONE and _obj_is_array_index_key_id(key) {
            dlg: int = _obj_array_index_sort_key(key);
            if dlg < jo_elen(current)
                and not jsv_is_hole(jo_eget(current, dlg)) {
                return js_undefined();  # own data element shadows prototypes
            }
        }
        if jo_mode(current) == MAP_MODE_SHAPE {
            lgp: int = shape_lookup(jo_shape_id(current), key);
            if lgp >= 0 {
                if (lgp & SHAPE_ATTR_ACCESSOR) != 0 {
                    # Getter slot; undefined correctly shadows (setter-only).
                    return jo_sget(current, lgp // 16);
                }
                return js_undefined();  # own data property shadows prototypes
            }
        } else {
            if key in _acc_ro(current).getters {
                return _acc_ro(current).getters[key];
            }
            # Own accessor without [[Get]], or own data property: shadow prototypes.
            if key in _acc_ro(current).setters or jo_has_key(current, key) {
                return js_undefined();
            }
        }
        current_idx = jo_prototype_idx(current);
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
        current: int = current_idx;
        if jo_elems_kind(current) != ELEMS_NONE and _obj_is_array_index_key_id(key) {
            dls: int = _obj_array_index_sort_key(key);
            if dls < jo_elen(current)
                and not jsv_is_hole(jo_eget(current, dls)) {
                return js_undefined();
            }
        }
        if jo_mode(current) == MAP_MODE_SHAPE {
            lsp: int = shape_lookup(jo_shape_id(current), key);
            if lsp >= 0 {
                if (lsp & SHAPE_ATTR_ACCESSOR) != 0 {
                    return jo_sget(current, lsp // 16 + 1);
                }
                return js_undefined();  # own data property shadows prototypes
            }
        } else {
            if key in _acc_ro(current).setters {
                return _acc_ro(current).setters[key];
            }
            # Own accessor without [[Set]], or own data property: shadow prototypes.
            if key in _acc_ro(current).getters or jo_has_key(current, key) {
                return js_undefined();
            }
        }
        current_idx = jo_prototype_idx(current);
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
