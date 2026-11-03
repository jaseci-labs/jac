"""
Closure records — shared by vm.jac, the GC and the builtins that read closures.

Does NOT import runtime.realm (that would create a cycle).
"""

import from engine.src.runtime.jsvalue { JSValue, js_undefined }
import from engine.src.runtime.jscell { FLAG_OLD }
import from engine.src.runtime.gc_barrier { gc_log_val }
import from engine.src.bytecode.op { CompiledFunction }
import from engine.src.ffi.libc { realloc, calloc }

# ═══════════════════════════════════════════════════════════════════════════════
# Closure records
# ═══════════════════════════════════════════════════════════════════════════════
# A closure is its fn_val table id (0-based). Its scalar fields are words of a
# raw 208-byte record; records live in chunks of 4096 that never move, found
# through the chunk table (chunk = id >> 12). The four reference fields are
# id-indexed side lists (refcounted values stay in Jac lists). A slot the GC
# freed keeps its old tenant's references until jc_init reuses it (as the
# tombstoned JSClosure object did); the free ids are kept here (_JC_FREE).
#
# GC invariant: every JSValue word here must also be traced in
# runtime/gc.jac's closure arm of gc_trace, or its referent can be swept
# while live.
#
# Word offsets:
#     0 lexical_this (JSValue)
#     8 prototype_obj (JSValue)
#    16 super_class (JSValue)
#    24 fn_props (JSValue)
#    32 home_object (JSValue, default js_undefined())
#    40 object_proto (JSValue, default js_undefined())
#    48 lexical_new_target (JSValue, default js_undefined())
#    56 this_binding_cell (JSValue, default 0)
#    64 class_brand (JSValue, default 0)
#    72 jac_module (JSValue, default js_undefined())
#    80 napi_cb_ptr (int, default 0)
#    88 napi_cb_data (int, default 0)
#    96 cell_kind (int, default 2)
#   104 cell_flags (int, default 0)
#   112 structure_id (int, default 0)
#   120 class_brand_sid (int, default 0)
#   128 home_realm_id (int, default 0)
#   136 call_plain (int, default 0)
#   144 is_arrow (bool)
#   152 is_non_constructor (bool, default False)
#   160 name_deleted (bool, default False)
#   168 length_deleted (bool, default False)
#   176 name_removed (bool, default False)
#   184 length_removed (bool, default False)
#   192 prototype_writable (bool, default True)
#   200 ctor_ok (int: 1 once a constructor entry is known allowed, vm.jac _reg_can_enter_cl)
glob:pub _JC_CHUNKS: int = 0,
     _JC_CHUNKS_CAP: int = 0,
     _JC_COUNT: int = 0,
     _JC_FUNC: list[CompiledFunction] = [],
     _JC_FV: list[list[JSValue]] = [],
     _JC_MF: list[list[CompiledFunction]] = [],
     _JC_CW: list[list[JSValue]] = [],
     _JC_EMPTY_FV: list[JSValue] = [],
     _JC_EMPTY_MF: list[CompiledFunction] = [],
     _JC_EMPTY_CW: list[JSValue] = [],
     # freed closure ids, a raw stack (see jsobject.jac _OBJ_FREE: the ids
     # handed out since the last collection are the entries at
     # [_JC_FREE_N, _JC_FREE_GC) plus the ids at or above _JC_COUNT_GC)
     _JC_FREE: int = 0,
     _JC_FREE_CAP: int = 0,
     _JC_FREE_N: int = 0,
     _JC_FREE_GC: int = 0,
     _JC_COUNT_GC: int = 0;

"""Address of the record of closure `id` (0 <= id < jc_count())."""
def:pub jc_p(id: int) -> int {
    return wrapping_add(
        __mem_load_i64(wrapping_add(_JC_CHUNKS, wrapping_mul(id >> 12, 8))),
        wrapping_mul(id & 4095, 208)
    );
}

"""Number of closure ids handed out (the former len(realm.closures))."""
def:pub jc_count -> int {
    return _JC_COUNT;
}

"""A parked closure id, or -1 when none is parked (jc_alloc's first step,
small enough to inline where closures are made)."""
def:pub jc_pop -> int {
    jp_n: int = _JC_FREE_N;
    if jp_n > 0 {
        _JC_FREE_N = jp_n - 1;
        return __mem_load_i64(wrapping_add(_JC_FREE, wrapping_mul(jp_n - 1, 8)));
    }
    return -1;
}

"""A closure id for a new closure of `f`: a slot the GC freed, else a new
one. The caller initializes it (jc_init) before anything reads it."""
def:pub jc_alloc(f: CompiledFunction) -> int {
    ja_n: int = _JC_FREE_N;
    if ja_n > 0 {
        _JC_FREE_N = ja_n - 1;
        return __mem_load_i64(wrapping_add(_JC_FREE, wrapping_mul(ja_n - 1, 8)));
    }
    ja_new: int = _JC_COUNT;
    ja_c: int = ja_new >> 12;
    if ja_c >= _JC_CHUNKS_CAP {
        ja_cap: int = 64 if _JC_CHUNKS_CAP == 0 else _JC_CHUNKS_CAP * 2;
        ja_t: int = realloc(_JC_CHUNKS, ja_cap * 8);
        ja_k: int = _JC_CHUNKS_CAP;
        while ja_k < ja_cap {
            __mem_store_i64(wrapping_add(ja_t, wrapping_mul(ja_k, 8)), 0);
            ja_k = ja_k + 1;
        }
        _JC_CHUNKS = ja_t;
        _JC_CHUNKS_CAP = ja_cap;
    }
    if __mem_load_i64(wrapping_add(_JC_CHUNKS, wrapping_mul(ja_c, 8))) == 0 {
        __mem_store_i64(wrapping_add(_JC_CHUNKS, wrapping_mul(ja_c, 8)), calloc(4096, 208));
    }
    _JC_COUNT = ja_new + 1;
    _JC_FUNC.append(f);
    _JC_FV.append(_JC_EMPTY_FV);
    _JC_MF.append(_JC_EMPTY_MF);
    _JC_CW.append(_JC_EMPTY_CW);
    return ja_new;
}

"""Park closure id `id` (swept) for jc_alloc to hand out again."""
def:pub jc_free_push(id: int) -> None {
    if _JC_FREE_N >= _JC_FREE_CAP {
        fp_cap: int = 4096 if _JC_FREE_CAP == 0 else _JC_FREE_CAP * 2;
        _JC_FREE = realloc(_JC_FREE, fp_cap * 8);
        _JC_FREE_CAP = fp_cap;
    }
    __mem_store_i64(wrapping_add(_JC_FREE, wrapping_mul(_JC_FREE_N, 8)), id);
    _JC_FREE_N = _JC_FREE_N + 1;
}

"""Number of parked closure ids."""
def:pub jc_free_count -> int {
    return _JC_FREE_N;
}

"""Free-stack entry `p` (the GC's young sweep reads and compacts them)."""
def:pub jc_free_at(p: int) -> int {
    return __mem_load_i64(wrapping_add(_JC_FREE, wrapping_mul(p, 8)));
}

def:pub jc_free_put(p: int, id: int) -> None {
    __mem_store_i64(wrapping_add(_JC_FREE, wrapping_mul(p, 8)), id);
}

def:pub jc_free_set_n(n: int) -> None {
    _JC_FREE_N = n;
}

"""The free-stack top and closure count when the last collection ended."""
def:pub jc_free_gc -> int {
    return _JC_FREE_GC;
}

def:pub jc_count_gc -> int {
    return _JC_COUNT_GC;
}

"""A collection ended: the ids handed out from here on are the next young ones."""
def:pub jc_cycle_end -> None {
    _JC_FREE_GC = _JC_FREE_N;
    _JC_COUNT_GC = _JC_COUNT;
}

"""The closure ids handed out since the last collection (GC verification)."""
def:pub jc_young_ids -> list[int] {
    jy_out: list[int] = [];
    jy_p: int = _JC_FREE_N;
    while jy_p < _JC_FREE_GC {
        jy_out.append(jc_free_at(jy_p));
        jy_p = jy_p + 1;
    }
    jy_i: int = _JC_COUNT_GC;
    while jy_i < _JC_COUNT {
        jy_out.append(jy_i);
        jy_i = jy_i + 1;
    }
    return jy_out;
}

"""(Re)initialize closure `id` as JSClosure(func, free_vals, lexical_this,
prototype_obj, super_class, fn_props, module_fns, is_arrow,
captured_with_objs) was built: every other field at its default (a reused
slot's DEAD tombstone flags are cleared)."""
def:pub jc_init(
    id: int,
    func: CompiledFunction,
    free_vals: list[JSValue],
    lexical_this: JSValue,
    prototype_obj: JSValue,
    super_class: JSValue,
    fn_props: JSValue,
    module_fns: list[CompiledFunction],
    is_arrow: bool,
    captured_with_objs: list[JSValue]
) -> None {
    # (an entry that already holds the value is left: no release / retain)
    if _JC_FUNC[id] is not func {
        _JC_FUNC[id] = func;
    }
    if _JC_FV[id] is not free_vals {
        _JC_FV[id] = free_vals;
    }
    if _JC_MF[id] is not module_fns {
        _JC_MF[id] = module_fns;
    }
    if _JC_CW[id] is not captured_with_objs {
        _JC_CW[id] = captured_with_objs;
    }
    ji_p: int = jc_p(id);
    __mem_store_i64(wrapping_add(ji_p, 0), lexical_this);
    __mem_store_i64(wrapping_add(ji_p, 8), prototype_obj);
    __mem_store_i64(wrapping_add(ji_p, 16), super_class);
    __mem_store_i64(wrapping_add(ji_p, 24), fn_props);
    __mem_store_i64(wrapping_add(ji_p, 32), js_undefined());
    __mem_store_i64(wrapping_add(ji_p, 40), js_undefined());
    __mem_store_i64(wrapping_add(ji_p, 48), js_undefined());
    __mem_store_i64(wrapping_add(ji_p, 56), 0);
    __mem_store_i64(wrapping_add(ji_p, 64), 0);
    __mem_store_i64(wrapping_add(ji_p, 72), js_undefined());
    __mem_store_i64(wrapping_add(ji_p, 80), 0);
    __mem_store_i64(wrapping_add(ji_p, 88), 0);
    __mem_store_i64(wrapping_add(ji_p, 96), 2);
    __mem_store_i64(wrapping_add(ji_p, 104), 0);
    __mem_store_i64(wrapping_add(ji_p, 112), 0);
    __mem_store_i64(wrapping_add(ji_p, 120), 0);
    __mem_store_i64(wrapping_add(ji_p, 128), 0);
    __mem_store_i64(wrapping_add(ji_p, 136), 0);
    __mem_store_i64(wrapping_add(ji_p, 144), 1 if is_arrow else 0);
    __mem_store_i64(wrapping_add(ji_p, 152), 0);
    __mem_store_i64(wrapping_add(ji_p, 160), 0);
    __mem_store_i64(wrapping_add(ji_p, 168), 0);
    __mem_store_i64(wrapping_add(ji_p, 176), 0);
    __mem_store_i64(wrapping_add(ji_p, 184), 0);
    __mem_store_i64(wrapping_add(ji_p, 192), 1);
    __mem_store_i64(wrapping_add(ji_p, 200), 0);
}

"""Initialize closure `id` as an arrow: what make_closure(func, free_vals,
lexical_this, undefined) followed by the arrow fields (is_arrow, lexical
new.target, this-binding cell, module functions, the enclosing closure's
super class, home object, class brand / sid and home realm, the CJS module)
builds, in one write of the record."""
def:pub jc_init_arrow(
    id: int,
    func: CompiledFunction,
    free_vals: list[JSValue],
    module_fns: list[CompiledFunction],
    captured_with_objs: list[JSValue],
    lexical_this: JSValue,
    new_target: JSValue,
    this_binding_cell: JSValue,
    super_class: JSValue,
    home_object: JSValue,
    class_brand: JSValue,
    class_brand_sid: int,
    home_realm_id: int,
    jac_module: JSValue
) -> None {
    if _JC_FUNC[id] is not func {
        _JC_FUNC[id] = func;
    }
    if _JC_FV[id] is not free_vals {
        _JC_FV[id] = free_vals;
    }
    if _JC_MF[id] is not module_fns {
        _JC_MF[id] = module_fns;
    }
    if _JC_CW[id] is not captured_with_objs {
        _JC_CW[id] = captured_with_objs;
    }
    ja_p: int = jc_p(id);
    __mem_store_i64(ja_p, lexical_this);
    __mem_store_i64(wrapping_add(ja_p, 8), js_undefined());
    __mem_store_i64(wrapping_add(ja_p, 16), super_class);
    __mem_store_i64(wrapping_add(ja_p, 24), js_undefined());
    __mem_store_i64(wrapping_add(ja_p, 32), home_object);
    __mem_store_i64(wrapping_add(ja_p, 40), js_undefined());
    __mem_store_i64(wrapping_add(ja_p, 48), new_target);
    __mem_store_i64(wrapping_add(ja_p, 56), this_binding_cell);
    __mem_store_i64(wrapping_add(ja_p, 64), class_brand);
    __mem_store_i64(wrapping_add(ja_p, 72), jac_module);
    __mem_store_i64(wrapping_add(ja_p, 80), 0);
    __mem_store_i64(wrapping_add(ja_p, 88), 0);
    __mem_store_i64(wrapping_add(ja_p, 96), 2);
    __mem_store_i64(wrapping_add(ja_p, 104), 0);
    __mem_store_i64(wrapping_add(ja_p, 112), 0);
    __mem_store_i64(wrapping_add(ja_p, 120), class_brand_sid);
    __mem_store_i64(wrapping_add(ja_p, 128), home_realm_id);
    __mem_store_i64(wrapping_add(ja_p, 136), 0);
    __mem_store_i64(wrapping_add(ja_p, 144), 1);
    __mem_store_i64(wrapping_add(ja_p, 152), 0);
    __mem_store_i64(wrapping_add(ja_p, 160), 0);
    __mem_store_i64(wrapping_add(ja_p, 168), 0);
    __mem_store_i64(wrapping_add(ja_p, 176), 0);
    __mem_store_i64(wrapping_add(ja_p, 184), 0);
    __mem_store_i64(wrapping_add(ja_p, 192), 1);
    __mem_store_i64(wrapping_add(ja_p, 200), 0);
}

"""1 once the closure is known to allow an in-loop constructor entry
(vm.jac _reg_can_enter_cl), else 0."""
def:pub jc_ctor_ok(id: int) -> int {
    return __mem_load_i64(wrapping_add(jc_p(id), 200));
}

def:pub jc_set_ctor_ok(id: int, v: int) -> None {
    __mem_store_i64(wrapping_add(jc_p(id), 200), v);
}

"""The closure's compiled function."""
def:pub jc_func(id: int) -> CompiledFunction {
    return _JC_FUNC[id];
}

def:pub jc_set_func(id: int, v: CompiledFunction) -> None {
    _JC_FUNC[id] = v;
}

"""The captured free-variable values (index = free_vars slot)."""
def:pub jc_free_vals(id: int) -> list[JSValue] {
    return _JC_FV[id];
}

"""The data pointer of the captured values' list (frames read them raw; the
list lives as long as the closure's entry holds it)."""
def:pub jc_free_vals_ptr(id: int) -> int {
    return __list_data_ptr(_JC_FV[id]);
}

def:pub jc_set_free_vals(id: int, v: list[JSValue]) -> None {
    _JC_FV[id] = v;
}

"""The compilation unit's functions the closure belongs to."""
def:pub jc_module_fns(id: int) -> list[CompiledFunction] {
    return _JC_MF[id];
}

def:pub jc_set_module_fns(id: int, v: list[CompiledFunction]) -> None {
    _JC_MF[id] = v;
}

"""The `with` object environment records captured at creation (innermost last)."""
def:pub jc_captured_with_objs(id: int) -> list[JSValue] {
    return _JC_CW[id];
}

def:pub jc_set_captured_with_objs(id: int, v: list[JSValue]) -> None {
    _JC_CW[id] = v;
}

def:pub jc_lexical_this(id: int) -> JSValue {
    return __mem_load_i64(wrapping_add(jc_p(id), 0));
}

def:pub jc_set_lexical_this(id: int, v: JSValue) -> None {
    __mem_store_i64(wrapping_add(jc_p(id), 0), v);
}

def:pub jc_prototype_obj(id: int) -> JSValue {
    return __mem_load_i64(wrapping_add(jc_p(id), 8));
}

def:pub jc_set_prototype_obj(id: int, v: JSValue) -> None {
    __mem_store_i64(wrapping_add(jc_p(id), 8), v);
}

def:pub jc_super_class(id: int) -> JSValue {
    return __mem_load_i64(wrapping_add(jc_p(id), 16));
}

def:pub jc_set_super_class(id: int, v: JSValue) -> None {
    __mem_store_i64(wrapping_add(jc_p(id), 16), v);
}

def:pub jc_fn_props(id: int) -> JSValue {
    return __mem_load_i64(wrapping_add(jc_p(id), 24));
}

def:pub jc_set_fn_props(id: int, v: JSValue) -> None {
    __mem_store_i64(wrapping_add(jc_p(id), 24), v);
}

def:pub jc_home_object(id: int) -> JSValue {
    return __mem_load_i64(wrapping_add(jc_p(id), 32));
}

def:pub jc_set_home_object(id: int, v: JSValue) -> None {
    __mem_store_i64(wrapping_add(jc_p(id), 32), v);
}

def:pub jc_object_proto(id: int) -> JSValue {
    return __mem_load_i64(wrapping_add(jc_p(id), 40));
}

def:pub jc_set_object_proto(id: int, v: JSValue) -> None {
    __mem_store_i64(wrapping_add(jc_p(id), 40), v);
}

def:pub jc_lexical_new_target(id: int) -> JSValue {
    return __mem_load_i64(wrapping_add(jc_p(id), 48));
}

def:pub jc_set_lexical_new_target(id: int, v: JSValue) -> None {
    __mem_store_i64(wrapping_add(jc_p(id), 48), v);
}

def:pub jc_this_binding_cell(id: int) -> JSValue {
    return __mem_load_i64(wrapping_add(jc_p(id), 56));
}

def:pub jc_set_this_binding_cell(id: int, v: JSValue) -> None {
    __mem_store_i64(wrapping_add(jc_p(id), 56), v);
}

def:pub jc_class_brand(id: int) -> JSValue {
    return __mem_load_i64(wrapping_add(jc_p(id), 64));
}

def:pub jc_set_class_brand(id: int, v: JSValue) -> None {
    __mem_store_i64(wrapping_add(jc_p(id), 64), v);
}

def:pub jc_jac_module(id: int) -> JSValue {
    return __mem_load_i64(wrapping_add(jc_p(id), 72));
}

def:pub jc_set_jac_module(id: int, v: JSValue) -> None {
    __mem_store_i64(wrapping_add(jc_p(id), 72), v);
}

def:pub jc_napi_cb_ptr(id: int) -> int {
    return __mem_load_i64(wrapping_add(jc_p(id), 80));
}

def:pub jc_set_napi_cb_ptr(id: int, v: int) -> None {
    __mem_store_i64(wrapping_add(jc_p(id), 80), v);
}

def:pub jc_napi_cb_data(id: int) -> int {
    return __mem_load_i64(wrapping_add(jc_p(id), 88));
}

def:pub jc_set_napi_cb_data(id: int, v: int) -> None {
    __mem_store_i64(wrapping_add(jc_p(id), 88), v);
}

def:pub jc_cell_kind(id: int) -> int {
    return __mem_load_i64(wrapping_add(jc_p(id), 96));
}

def:pub jc_set_cell_kind(id: int, v: int) -> None {
    __mem_store_i64(wrapping_add(jc_p(id), 96), v);
}

def:pub jc_cell_flags(id: int) -> int {
    return __mem_load_i64(wrapping_add(jc_p(id), 104));
}

def:pub jc_set_cell_flags(id: int, v: int) -> None {
    __mem_store_i64(wrapping_add(jc_p(id), 104), v);
}

def:pub jc_structure_id(id: int) -> int {
    return __mem_load_i64(wrapping_add(jc_p(id), 112));
}

def:pub jc_set_structure_id(id: int, v: int) -> None {
    __mem_store_i64(wrapping_add(jc_p(id), 112), v);
}

def:pub jc_class_brand_sid(id: int) -> int {
    return __mem_load_i64(wrapping_add(jc_p(id), 120));
}

def:pub jc_set_class_brand_sid(id: int, v: int) -> None {
    __mem_store_i64(wrapping_add(jc_p(id), 120), v);
}

def:pub jc_home_realm_id(id: int) -> int {
    return __mem_load_i64(wrapping_add(jc_p(id), 128));
}

def:pub jc_set_home_realm_id(id: int, v: int) -> None {
    __mem_store_i64(wrapping_add(jc_p(id), 128), v);
}

def:pub jc_call_plain(id: int) -> int {
    return __mem_load_i64(wrapping_add(jc_p(id), 136));
}

def:pub jc_set_call_plain(id: int, v: int) -> None {
    __mem_store_i64(wrapping_add(jc_p(id), 136), v);
}

def:pub jc_is_arrow(id: int) -> bool {
    return __mem_load_i64(wrapping_add(jc_p(id), 144)) != 0;
}

def:pub jc_set_is_arrow(id: int, v: bool) -> None {
    __mem_store_i64(wrapping_add(jc_p(id), 144), 1 if v else 0);
}

def:pub jc_is_non_constructor(id: int) -> bool {
    return __mem_load_i64(wrapping_add(jc_p(id), 152)) != 0;
}

def:pub jc_set_is_non_constructor(id: int, v: bool) -> None {
    __mem_store_i64(wrapping_add(jc_p(id), 152), 1 if v else 0);
}

def:pub jc_name_deleted(id: int) -> bool {
    return __mem_load_i64(wrapping_add(jc_p(id), 160)) != 0;
}

def:pub jc_set_name_deleted(id: int, v: bool) -> None {
    __mem_store_i64(wrapping_add(jc_p(id), 160), 1 if v else 0);
}

def:pub jc_length_deleted(id: int) -> bool {
    return __mem_load_i64(wrapping_add(jc_p(id), 168)) != 0;
}

def:pub jc_set_length_deleted(id: int, v: bool) -> None {
    __mem_store_i64(wrapping_add(jc_p(id), 168), 1 if v else 0);
}

def:pub jc_name_removed(id: int) -> bool {
    return __mem_load_i64(wrapping_add(jc_p(id), 176)) != 0;
}

def:pub jc_set_name_removed(id: int, v: bool) -> None {
    __mem_store_i64(wrapping_add(jc_p(id), 176), 1 if v else 0);
}

def:pub jc_length_removed(id: int) -> bool {
    return __mem_load_i64(wrapping_add(jc_p(id), 184)) != 0;
}

def:pub jc_set_length_removed(id: int, v: bool) -> None {
    __mem_store_i64(wrapping_add(jc_p(id), 184), 1 if v else 0);
}

def:pub jc_prototype_writable(id: int) -> bool {
    return __mem_load_i64(wrapping_add(jc_p(id), 192)) != 0;
}

def:pub jc_set_prototype_writable(id: int, v: bool) -> None {
    __mem_store_i64(wrapping_add(jc_p(id), 192), 1 if v else 0);
}

"""Generational write barrier (docs/GENERATIONAL_GC.md §4.4): `v`, just
stored into a field of closure `id`, is logged for the next minor
collection when the closure is old."""
def:pub jc_wb(id: int, v: JSValue) -> None {
    if (__mem_load_i64(wrapping_add(jc_p(id), 104)) & FLAG_OLD) != 0 {
        gc_log_val(v);
    }
}

"""jc_wb for every value a list field holds (after it is replaced)."""
def:pub jc_wb_lists(id: int) -> None {
    if (__mem_load_i64(wrapping_add(jc_p(id), 104)) & FLAG_OLD) != 0 {
        for wl_f in _JC_FV[id] {
            gc_log_val(wl_f);
        }
        for wl_w in _JC_CW[id] {
            gc_log_val(wl_w);
        }
    }
}
