impl _collecting -> bool {
    return int(__mem_load_i8(__global_block("__rc_collecting", 1))) != 0;
}

impl _mul64(a: int, b: int) -> int {
    a0 = a & LOW16;
    a1 = (a >> 16) & LOW16;
    a2 = (a >> 32) & LOW16;
    a3 = (a >> 48) & LOW16;
    b0 = b & LOW16;
    b1 = (b >> 16) & LOW16;
    b2 = (b >> 32) & LOW16;
    b3 = (b >> 48) & LOW16;
    acc = a0 * b0;
    r0 = acc & LOW16;
    acc = (acc >> 16) + a0 * b1 + a1 * b0;
    r1 = acc & LOW16;
    acc = (acc >> 16) + a0 * b2 + a1 * b1 + a2 * b0;
    r2 = acc & LOW16;
    acc = (acc >> 16) + a0 * b3 + a1 * b2 + a2 * b1 + a3 * b0;
    r3 = acc & LOW16;
    if r3 > 32767 {
        r3 -= 65536;
    }
    return r3 * LIMB3_SCALE + ((r2 << 32) | (r1 << 16) | r0);
}

impl _shr(z: int, n: int) -> int {
    return (z >> n) & (HASH_MASK >> (n - 1));
}

impl _mix(z: int) -> int {
    m = _mul64(z ^ _shr(z, 30), MIX_A);
    m = _mul64(m ^ _shr(m, 27), MIX_B);
    return m ^ _shr(m, 31);
}

impl _str_hash(text: int) -> int {
    n = __jac_rt_str_size(ptr[u8](text));
    hi = FNV_HI;
    lo = FNV_LO;
    if n > 0 {
        data = ptr[u8](text).view(n);
        i = 0;
        while i < n {
            lo = lo ^ int(data[i]);
            low = lo * FNV_PRIME_LOW;
            hi = (hi * FNV_PRIME_LOW + (lo << 8) + (low >> 32)) & LOW32;
            lo = low & LOW32;
            i += 1;
        }
    }
    return ((hi & 2147483647) << 32) | lo;
}

impl _hash(bits: int, kind: int) -> int {
    if kind == KIND_STR {
        return _str_hash(bits) & HASH_MASK;
    }
    value = bits;
    if kind == KIND_FLOAT and value == NEG_ZERO_BITS {
        value = 0;
    }
    return _mix(value) & HASH_MASK;
}

impl _grow_cap(n: int) -> int {
    cap = DICT_MIN_CAP;
    while cap < n * 2 {
        cap = cap * 2;
    }
    return cap;
}

impl _tables(d: int, cap: int, is_set: bool) {
    vals = 0;
    if not is_set {
        vals = malloc(cap * SLOT);
    }
    ctrl = malloc(cap * 2 * CELL);
    memset(ctrl, i32(255), cap * 2 * CELL);
    __mem_store_i64(d + DICT_LEN, 0);
    __mem_store_i64(d + DICT_CAP, cap);
    __mem_store_i64(d + DICT_KEYS, malloc(cap * SLOT));
    __mem_store_i64(d + DICT_VALS, vals);
    __mem_store_i64(d + DICT_CTRL, ctrl);
    __mem_store_i64(d + DICT_USED, 0);
    __mem_store_i64(d + DICT_ORDER, malloc(cap * SLOT));
}

impl _cell(d: int, i: int) -> int {
    return int(__mem_load_i32(__mem_load_i64(d + DICT_CTRL) + i * CELL));
}

impl _probe(d: int, h: int, key: int, key_kind: int) -> int {
    mask = __mem_load_i64(d + DICT_CAP) * 2 - 1;
    ctrl = __mem_load_i64(d + DICT_CTRL);
    keys = __mem_load_i64(d + DICT_KEYS);
    order = __mem_load_i64(d + DICT_ORDER);
    i = h & mask;
    perturb = h;
    free_cell = -1;
    index = int(__mem_load_i32(ctrl + i * CELL));
    while index != CELL_EMPTY {
        if index == CELL_DELETED {
            if free_cell < 0 {
                free_cell = i;
            }
        } elif __mem_load_i64(order + index * SLOT) == h
            and __jac_rt_elem_eq(__mem_load_i64(keys + index * SLOT), key, key_kind) {
            return i;
        }
        perturb = perturb >> PERTURB_SHIFT;
        i = (i * 5 + 1 + (perturb & mask)) & mask;
        index = int(__mem_load_i32(ctrl + i * CELL));
    }
    if free_cell < 0 {
        free_cell = i;
    }
    return -free_cell - 1;
}

impl _empty_cell(d: int, h: int) -> int {
    mask = __mem_load_i64(d + DICT_CAP) * 2 - 1;
    ctrl = __mem_load_i64(d + DICT_CTRL);
    i = h & mask;
    perturb = h;
    while int(__mem_load_i32(ctrl + i * CELL)) != CELL_EMPTY {
        perturb = perturb >> PERTURB_SHIFT;
        i = (i * 5 + 1 + (perturb & mask)) & mask;
    }
    return i;
}

impl _append(d: int, h: int, key: int, val: int) {
    cell = _empty_cell(d, h);
    index = __mem_load_i64(d + DICT_USED);
    __mem_store_i64(__mem_load_i64(d + DICT_KEYS) + index * SLOT, key);
    vals = __mem_load_i64(d + DICT_VALS);
    if vals != 0 {
        __mem_store_i64(vals + index * SLOT, val);
    }
    __mem_store_i64(__mem_load_i64(d + DICT_ORDER) + index * SLOT, h);
    __mem_store_i32(__mem_load_i64(d + DICT_CTRL) + cell * CELL, i32(index));
    __mem_store_i64(d + DICT_USED, index + 1);
    __mem_store_i64(d + DICT_LEN, __mem_load_i64(d + DICT_LEN) + 1);
}

impl _rebuild(d: int, cap: int, is_set: bool) {
    used = __mem_load_i64(d + DICT_USED);
    keys = __mem_load_i64(d + DICT_KEYS);
    vals = __mem_load_i64(d + DICT_VALS);
    order = __mem_load_i64(d + DICT_ORDER);
    ctrl = __mem_load_i64(d + DICT_CTRL);
    _tables(d, cap, is_set);
    e = 0;
    while e < used {
        h = __mem_load_i64(order + e * SLOT);
        if h >= 0 {
            val = 0;
            if vals != 0 {
                val = __mem_load_i64(vals + e * SLOT);
            }
            _append(d, h, __mem_load_i64(keys + e * SLOT), val);
        }
        e += 1;
    }
    free(keys);
    free(vals);
    free(order);
    free(ctrl);
}

impl _store(d: int, h: int, key: int, val: int, key_kind: int, val_kind: int) {
    cell = -1;
    if __mem_load_i64(d + DICT_CAP) > 0 {
        found = _probe(d, h, key, key_kind);
        if found >= 0 {
            if val_kind >= 0 {
                at = __mem_load_i64(d + DICT_VALS) + _cell(d, found) * SLOT;
                old = __mem_load_i64(at);
                __jac_rt_elem_retain(val, val_kind);
                __mem_store_i64(at, val);
                __jac_rt_elem_release(old, val_kind);
            }
            return;
        }
        cell = -found - 1;
    }
    index = __mem_load_i64(d + DICT_USED);
    if index >= __mem_load_i64(d + DICT_CAP) {
        _rebuild(d, _grow_cap(__mem_load_i64(d + DICT_LEN)), val_kind < 0);
        cell = _empty_cell(d, h);
        index = __mem_load_i64(d + DICT_USED);
    }
    __mem_store_i64(__mem_load_i64(d + DICT_KEYS) + index * SLOT, key);
    if val_kind >= 0 {
        __mem_store_i64(__mem_load_i64(d + DICT_VALS) + index * SLOT, val);
    }
    __mem_store_i64(__mem_load_i64(d + DICT_ORDER) + index * SLOT, h);
    __mem_store_i32(__mem_load_i64(d + DICT_CTRL) + cell * CELL, i32(index));
    __mem_store_i64(d + DICT_USED, index + 1);
    __mem_store_i64(d + DICT_LEN, __mem_load_i64(d + DICT_LEN) + 1);
    __jac_rt_elem_retain(key, key_kind);
    if val_kind >= 0 {
        __jac_rt_elem_retain(val, val_kind);
    }
}

impl _unlink(d: int, cell: int, index: int, val_kind: int) {
    __mem_store_i32(__mem_load_i64(d + DICT_CTRL) + cell * CELL, i32(CELL_DELETED));
    __mem_store_i64(__mem_load_i64(d + DICT_ORDER) + index * SLOT, -1);
    live = __mem_load_i64(d + DICT_LEN) - 1;
    __mem_store_i64(d + DICT_LEN, live);
    if __mem_load_i64(d + DICT_USED) - live <= live {
        return;
    }
    if live == 0 {
        cap = __mem_load_i64(d + DICT_CAP);
        memset(__mem_load_i64(d + DICT_CTRL), i32(255), cap * 2 * CELL);
        __mem_store_i64(d + DICT_USED, 0);
        return;
    }
    _rebuild(d, _grow_cap(live), val_kind < 0);
}

impl __jac_rt_dict_new(key_kind: int, val_kind: int) -> int {
    d = __jac_rt_alloc(DICT_SIZE);
    if val_kind < 0 {
        __jac_rt_set_type(d, int(ptr[u8]("set")));
    } else {
        __jac_rt_set_type(d, int(ptr[u8]("dict")));
    }
    __mem_store_i64(d + DICT_LEN, 0);
    __mem_store_i64(d + DICT_CAP, 0);
    __mem_store_i64(d + DICT_KEYS, 0);
    __mem_store_i64(d + DICT_VALS, 0);
    __mem_store_i64(d + DICT_CTRL, 0);
    __mem_store_i64(d + DICT_USED, 0);
    __mem_store_i64(d + DICT_ORDER, 0);
    __mem_store_i64(d - HDR_DTOR_BACK, _dtor_for(key_kind, val_kind));
    return d;
}

impl __jac_rt_dict_len(d: int) -> int {
    return __mem_load_i64(d + DICT_LEN);
}

impl __jac_rt_dict_find(d: int, key: int, key_kind: int) -> int {
    if __mem_load_i64(d + DICT_LEN) == 0 {
        return -1;
    }
    found = _probe(d, _hash(key, key_kind), key, key_kind);
    if found < 0 {
        return -1;
    }
    return _cell(d, found);
}

impl __jac_rt_dict_set(d: int, key: int, val: int, key_kind: int, val_kind: int) {
    _store(d, _hash(key, key_kind), key, val, key_kind, val_kind);
}

impl __jac_rt_dict_del(d: int, key: int, key_kind: int, val_kind: int) -> bool {
    if __mem_load_i64(d + DICT_LEN) == 0 {
        return False;
    }
    found = _probe(d, _hash(key, key_kind), key, key_kind);
    if found < 0 {
        return False;
    }
    index = _cell(d, found);
    held_key = __mem_load_i64(__mem_load_i64(d + DICT_KEYS) + index * SLOT);
    held_val = 0;
    if val_kind >= 0 {
        held_val = __mem_load_i64(__mem_load_i64(d + DICT_VALS) + index * SLOT);
    }
    _unlink(d, found, index, val_kind);
    __jac_rt_elem_release(held_key, key_kind);
    if val_kind >= 0 {
        __jac_rt_elem_release(held_val, val_kind);
    }
    return True;
}

impl __jac_rt_dict_key_at(d: int, index: int) -> int {
    return __mem_load_i64(__mem_load_i64(d + DICT_KEYS) + index * SLOT);
}

impl __jac_rt_dict_val_at(d: int, index: int) -> int {
    return __mem_load_i64(__mem_load_i64(d + DICT_VALS) + index * SLOT);
}

impl __jac_rt_dict_key_ref(d: int, index: int, key_kind: int) -> int {
    bits = __mem_load_i64(__mem_load_i64(d + DICT_KEYS) + index * SLOT);
    __jac_rt_elem_retain(bits, key_kind);
    return bits;
}

impl __jac_rt_dict_val_ref(d: int, index: int, val_kind: int) -> int {
    bits = __mem_load_i64(__mem_load_i64(d + DICT_VALS) + index * SLOT);
    __jac_rt_elem_retain(bits, val_kind);
    return bits;
}

impl __jac_rt_dict_next(d: int, index: int) -> int {
    used = __mem_load_i64(d + DICT_USED);
    order = __mem_load_i64(d + DICT_ORDER);
    i = index + 1;
    while i < used {
        if __mem_load_i64(order + i * SLOT) >= 0 {
            return i;
        }
        i += 1;
    }
    return -1;
}

impl __jac_rt_dict_pop(
    d: int, key: int, key_kind: int, val_kind: int, found_out: int
) -> int {
    found = -1;
    if __mem_load_i64(d + DICT_LEN) != 0 {
        found = _probe(d, _hash(key, key_kind), key, key_kind);
    }
    if found < 0 {
        if found_out != 0 {
            __mem_store_i64(found_out, 0);
        }
        return 0;
    }
    index = _cell(d, found);
    held_key = __mem_load_i64(__mem_load_i64(d + DICT_KEYS) + index * SLOT);
    held_val = 0;
    if val_kind >= 0 {
        held_val = __mem_load_i64(__mem_load_i64(d + DICT_VALS) + index * SLOT);
    }
    _unlink(d, found, index, val_kind);
    if found_out != 0 {
        __mem_store_i64(found_out, 1);
    }
    if val_kind < 0 {
        return held_key;
    }
    __jac_rt_elem_release(held_key, key_kind);
    return held_val;
}

impl __jac_rt_dict_clear(d: int, key_kind: int, val_kind: int) {
    used = __mem_load_i64(d + DICT_USED);
    keys = __mem_load_i64(d + DICT_KEYS);
    vals = __mem_load_i64(d + DICT_VALS);
    order = __mem_load_i64(d + DICT_ORDER);
    ctrl = __mem_load_i64(d + DICT_CTRL);
    __mem_store_i64(d + DICT_LEN, 0);
    __mem_store_i64(d + DICT_CAP, 0);
    __mem_store_i64(d + DICT_KEYS, 0);
    __mem_store_i64(d + DICT_VALS, 0);
    __mem_store_i64(d + DICT_CTRL, 0);
    __mem_store_i64(d + DICT_USED, 0);
    __mem_store_i64(d + DICT_ORDER, 0);
    e = 0;
    while e < used {
        if __mem_load_i64(order + e * SLOT) >= 0 {
            __jac_rt_elem_release(__mem_load_i64(keys + e * SLOT), key_kind);
            if vals != 0 and val_kind >= 0 {
                __jac_rt_elem_release(__mem_load_i64(vals + e * SLOT), val_kind);
            }
        }
        e += 1;
    }
    free(keys);
    free(vals);
    free(order);
    free(ctrl);
}

impl __jac_rt_dict_copy(d: int, key_kind: int, val_kind: int) -> int {
    made = __jac_rt_dict_new(key_kind, val_kind);
    n = __mem_load_i64(d + DICT_LEN);
    if n == 0 {
        return made;
    }
    _tables(made, _grow_cap(n), val_kind < 0);
    used = __mem_load_i64(d + DICT_USED);
    keys = __mem_load_i64(d + DICT_KEYS);
    vals = __mem_load_i64(d + DICT_VALS);
    order = __mem_load_i64(d + DICT_ORDER);
    e = 0;
    while e < used {
        h = __mem_load_i64(order + e * SLOT);
        if h >= 0 {
            key = __mem_load_i64(keys + e * SLOT);
            val = 0;
            if val_kind >= 0 {
                val = __mem_load_i64(vals + e * SLOT);
                __jac_rt_elem_retain(val, val_kind);
            }
            __jac_rt_elem_retain(key, key_kind);
            _append(made, h, key, val);
        }
        e += 1;
    }
    return made;
}

impl __jac_rt_dict_update(dst: int, src: int, key_kind: int, val_kind: int) {
    if dst == src {
        return;
    }
    e = 0;
    while e < __mem_load_i64(src + DICT_USED) {
        h = __mem_load_i64(__mem_load_i64(src + DICT_ORDER) + e * SLOT);
        if h >= 0 {
            val = 0;
            if val_kind >= 0 {
                val = __mem_load_i64(__mem_load_i64(src + DICT_VALS) + e * SLOT);
            }
            _store(
                dst,
                h,
                __mem_load_i64(__mem_load_i64(src + DICT_KEYS) + e * SLOT),
                val,
                key_kind,
                val_kind
            );
        }
        e += 1;
    }
}

impl __jac_rt_dict_eq(a: int, b: int, key_kind: int, val_kind: int) -> bool {
    if a == b {
        return True;
    }
    n = __mem_load_i64(a + DICT_LEN);
    if n != __mem_load_i64(b + DICT_LEN) {
        return False;
    }
    if n == 0 {
        return True;
    }
    used = __mem_load_i64(a + DICT_USED);
    keys = __mem_load_i64(a + DICT_KEYS);
    vals = __mem_load_i64(a + DICT_VALS);
    order = __mem_load_i64(a + DICT_ORDER);
    other_vals = __mem_load_i64(b + DICT_VALS);
    e = 0;
    while e < used {
        h = __mem_load_i64(order + e * SLOT);
        if h >= 0 {
            found = _probe(b, h, __mem_load_i64(keys + e * SLOT), key_kind);
            if found < 0 {
                return False;
            }
            if val_kind >= 0
                and not __jac_rt_elem_eq(
                    __mem_load_i64(vals + e * SLOT),
                    __mem_load_i64(other_vals + _cell(b, found) * SLOT),
                    val_kind
                ) {
                return False;
            }
        }
        e += 1;
    }
    return True;
}

impl _drop_release(bits: int, kind: int, collecting: bool) {
    if bits == 0 {
        return;
    }
    if kind == KIND_STR {
        __jac_rt_release_acyclic(bits);
    } elif kind == KIND_REF and not collecting {
        __jac_rt_release(bits);
    }
}

impl _dict_drop(o: int, key_kind: int, val_kind: int) {
    collecting = _collecting();
    used = __mem_load_i64(o + DICT_USED);
    keys = __mem_load_i64(o + DICT_KEYS);
    vals = __mem_load_i64(o + DICT_VALS);
    order = __mem_load_i64(o + DICT_ORDER);
    if key_kind == KIND_STR
        or key_kind == KIND_REF
        or val_kind == KIND_STR
        or val_kind == KIND_REF {
        e = 0;
        while e < used {
            if __mem_load_i64(order + e * SLOT) >= 0 {
                _drop_release(__mem_load_i64(keys + e * SLOT), key_kind, collecting);
                if vals != 0 {
                    _drop_release(
                        __mem_load_i64(vals + e * SLOT), val_kind, collecting
                    );
                }
            }
            e += 1;
        }
    }
    free(keys);
    free(vals);
    free(order);
    free(__mem_load_i64(o + DICT_CTRL));
    __jac_rt_free_block(o - HDR_TOTAL);
}

impl _dict_trace(o: int, visitor: int, key_ref: bool, val_ref: bool) {
    used = __mem_load_i64(o + DICT_USED);
    keys = __mem_load_i64(o + DICT_KEYS);
    vals = __mem_load_i64(o + DICT_VALS);
    order = __mem_load_i64(o + DICT_ORDER);
    e = 0;
    while e < used {
        if __mem_load_i64(order + e * SLOT) >= 0 {
            if key_ref {
                child = __mem_load_i64(keys + e * SLOT);
                if child != 0 {
                    __mem_call_dtor(visitor, child);
                }
            }
            if val_ref and vals != 0 {
                child = __mem_load_i64(vals + e * SLOT);
                if child != 0 {
                    __mem_call_dtor(visitor, child);
                }
            }
        }
        e += 1;
    }
}

impl _dict_drop_pp(o: int) {
    _dict_drop(o, KIND_INT, KIND_INT);
}

impl _dict_drop_ps(o: int) {
    _dict_drop(o, KIND_INT, KIND_STR);
}

impl _dict_drop_pr(o: int) {
    _dict_drop(o, KIND_INT, KIND_REF);
}

impl _dict_drop_sp(o: int) {
    _dict_drop(o, KIND_STR, KIND_INT);
}

impl _dict_drop_ss(o: int) {
    _dict_drop(o, KIND_STR, KIND_STR);
}

impl _dict_drop_sr(o: int) {
    _dict_drop(o, KIND_STR, KIND_REF);
}

impl _dict_drop_rp(o: int) {
    _dict_drop(o, KIND_REF, KIND_INT);
}

impl _dict_drop_rs(o: int) {
    _dict_drop(o, KIND_REF, KIND_STR);
}

impl _dict_drop_rr(o: int) {
    _dict_drop(o, KIND_REF, KIND_REF);
}

impl _dict_trace_pr(o: int, visitor: int) {
    _dict_trace(o, visitor, False, True);
}

impl _dict_trace_sr(o: int, visitor: int) {
    _dict_trace(o, visitor, False, True);
}

impl _dict_trace_rp(o: int, visitor: int) {
    _dict_trace(o, visitor, True, False);
}

impl _dict_trace_rs(o: int, visitor: int) {
    _dict_trace(o, visitor, True, False);
}

impl _dict_trace_rr(o: int, visitor: int) {
    _dict_trace(o, visitor, True, True);
}

impl _kind_class(kind: int) -> int {
    if kind == KIND_STR or kind == KIND_REF {
        return kind;
    }
    return KIND_INT;
}

impl _dtor_for(key_kind: int, val_kind: int) -> int {
    kc = _kind_class(key_kind);
    vc = _kind_class(val_kind);
    if kc == KIND_REF or vc == KIND_REF {
        _register_traces();
    }
    dtor = int(_dict_drop_pp);
    if kc == KIND_STR {
        dtor = int(_dict_drop_sp);
        if vc == KIND_STR {
            dtor = int(_dict_drop_ss);
        } elif vc == KIND_REF {
            dtor = int(_dict_drop_sr);
        }
    } elif kc == KIND_REF {
        dtor = int(_dict_drop_rp);
        if vc == KIND_STR {
            dtor = int(_dict_drop_rs);
        } elif vc == KIND_REF {
            dtor = int(_dict_drop_rr);
        }
    } elif vc == KIND_STR {
        dtor = int(_dict_drop_ps);
    } elif vc == KIND_REF {
        dtor = int(_dict_drop_pr);
    }
    return dtor;
}

impl _register_traces -> None {
    flag = __global_block("__jac_rt_dict_traced", 1);
    if int(__mem_load_i8(flag)) != 0 {
        return;
    }
    __jac_rt_trace_register(int(_dict_drop_pr), int(_dict_trace_pr));
    __jac_rt_trace_register(int(_dict_drop_sr), int(_dict_trace_sr));
    __jac_rt_trace_register(int(_dict_drop_rp), int(_dict_trace_rp));
    __jac_rt_trace_register(int(_dict_drop_rs), int(_dict_trace_rs));
    __jac_rt_trace_register(int(_dict_drop_rr), int(_dict_trace_rr));
    __mem_store_i8(flag, i8(1));
}
