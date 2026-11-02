import from c {
    def malloc(n: int) -> int;  def free(p: int) -> None;  def memset(
        p: int, c: i32, n: int
    ) -> int;
}

glob KIND_INT: int = 0,
     KIND_FLOAT: int = 1,
     KIND_BOOL: int = 2,
     KIND_STR: int = 3,
     KIND_REF: int = 4,
     KIND_TUPLE: int = 5,
     KIND_ANY: int = 6,
     TAG_INT: int = 0,
     TAG_FLOAT: int = 1,
     TAG_STR: int = 2,
     TAG_BOOL: int = 7,
     TAG_NONE: int = 8,
     INT_FLOAT_LIMIT: float = 9.0e18,
     KIND_NONE: int = -1;

glob DICT_LEN: int = 0,
     DICT_CAP: int = 8,
     DICT_KEYS: int = 16,
     DICT_VALS: int = 24,
     DICT_CTRL: int = 32,
     DICT_USED: int = 40,
     DICT_ORDER: int = 48,
     DICT_SIZE: int = 56,
     DICT_MIN_CAP: int = 4,
     SLOT: int = 8,
     CELL: int = 4,
     CELL_EMPTY: int = -1,
     CELL_DELETED: int = -2,
     PERTURB_SHIFT: int = 5,
     HDR_DTOR_BACK: int = 8,
     HDR_TOTAL: int = 32;

glob HASH_MASK: int = 9223372036854775807,
     LOW32: int = 4294967295,
     LOW16: int = 65535,
     LIMB3_SCALE: int = 281474976710656,
     NEG_ZERO_BITS: int = -9223372036854775807 - 1,
     FNV_HI: int = 3421674724,
     FNV_LO: int = 2216829733,
     FNV_PRIME_LOW: int = 435,
     MIX_A: int = -4658895280553007687,
     MIX_B: int = -7723592293110705685;

def:pub __jac_rt_dict_new(key_kind: int, val_kind: int) -> int;

def:pub __jac_rt_dict_len(d: int) -> int;

def:pub __jac_rt_dict_find(d: int, key: int, key_kind: int) -> int;

def:pub __jac_rt_dict_set(d: int, key: int, val: int, key_kind: int, val_kind: int);

def:pub __jac_rt_dict_del(d: int, key: int, key_kind: int, val_kind: int) -> bool;

def:pub __jac_rt_dict_key_at(d: int, index: int) -> int;

def:pub __jac_rt_dict_val_at(d: int, index: int) -> int;

def:pub __jac_rt_dict_key_ref(d: int, index: int, key_kind: int) -> int;

def:pub __jac_rt_dict_val_ref(d: int, index: int, val_kind: int) -> int;

def:pub __jac_rt_dict_next(d: int, index: int) -> int;

def:pub __jac_rt_dict_pop(
    d: int, key: int, key_kind: int, val_kind: int, found_out: int
) -> int;

def:pub __jac_rt_dict_clear(d: int, key_kind: int, val_kind: int);

def:pub __jac_rt_dict_copy(d: int, key_kind: int, val_kind: int) -> int;

def:pub __jac_rt_dict_update(dst: int, src: int, key_kind: int, val_kind: int);

def:pub __jac_rt_dict_eq(a: int, b: int, key_kind: int, val_kind: int) -> bool;

def:pub __jac_rt_dict_popitem(d: int, key_kind: int, val_kind: int, key_out: int) -> int;

def:pub __jac_rt_set_filter(a: int, b: int, kind: int, keep_shared: bool) -> int;

def:pub __jac_rt_set_xor(a: int, b: int, kind: int) -> int;

def:pub __jac_rt_set_within(a: int, b: int, kind: int) -> bool;

def:pub __jac_rt_set_disjoint(a: int, b: int, kind: int) -> bool;

def _set_has(s: int, h: int, key: int, kind: int) -> bool;

def _collecting -> bool;

def _mul64(a: int, b: int) -> int;

def _shr(z: int, n: int) -> int;

def _mix(z: int) -> int;

def _str_hash(text: int) -> int;

def _hash(bits: int, kind: int) -> int;

def _tuple_hash(box: int) -> int;

def _any_hash(box: int) -> int;

def _grow_cap(n: int) -> int;

def _tables(d: int, cap: int, is_set: bool);

def _cell(d: int, i: int) -> int;

def _probe(d: int, h: int, key: int, key_kind: int) -> int;

def _empty_cell(d: int, h: int) -> int;

def _append(d: int, h: int, key: int, val: int);

def _rebuild(d: int, cap: int, is_set: bool);

def _store(d: int, h: int, key: int, val: int, key_kind: int, val_kind: int);

def _unlink(d: int, cell: int, index: int, val_kind: int);

def _drop_release(bits: int, kind: int, collecting: bool);

def _dict_drop(o: int, key_kind: int, val_kind: int);

def _dict_trace(o: int, visit_fn: int, key_ref: bool, val_ref: bool);

def _dict_drop_pp(o: int);

def _dict_drop_ps(o: int);

def _dict_drop_pr(o: int);

def _dict_drop_sp(o: int);

def _dict_drop_ss(o: int);

def _dict_drop_sr(o: int);

def _dict_drop_rp(o: int);

def _dict_drop_rs(o: int);

def _dict_drop_rr(o: int);

def _dict_trace_pr(o: int, visit_fn: int);

def _dict_trace_sr(o: int, visit_fn: int);

def _dict_trace_rp(o: int, visit_fn: int);

def _dict_trace_rs(o: int, visit_fn: int);

def _dict_trace_rr(o: int, visit_fn: int);

def _kind_class(kind: int) -> int;

def _dtor_for(key_kind: int, val_kind: int) -> int;

def _register_traces -> None;
