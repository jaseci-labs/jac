impl _collecting -> bool {
    return int(__mem_load_i8(__global_block("__rc_collecting", 1))) != 0;
}

impl _is_ref_kind(kind: int) -> bool {
    return kind == KIND_STR
        or kind == KIND_REF
        or kind == KIND_TUPLE
        or kind == KIND_ANY;
}

impl __jac_rt_any_eq(a: int, b: int) -> bool {
    return __jac_rt_any_equal(
        __mem_load_i64(a + BOX_TAG),
        __mem_load_i64(a + BOX_PAYLOAD),
        __mem_load_i64(b + BOX_TAG),
        __mem_load_i64(b + BOX_PAYLOAD)
    );
}

impl _any_cmp(a: int, b: int) -> int {
    ta = __mem_load_i64(a + BOX_TAG);
    tb = __mem_load_i64(b + BOX_TAG);
    pa = __mem_load_i64(a + BOX_PAYLOAD);
    pb = __mem_load_i64(b + BOX_PAYLOAD);
    if __jac_rt_any_order(ta, pa, tb, pb, ORDER_LT) {
        return -1;
    }
    if __jac_rt_any_order(tb, pb, ta, pa, ORDER_LT) {
        return 1;
    }
    return 0;
}

impl __jac_rt_elem_retain(bits: int, kind: int) {
    if bits != 0 and _is_ref_kind(kind) {
        __jac_rt_retain(bits);
    }
}

impl __jac_rt_elem_release(bits: int, kind: int) {
    if bits == 0 {
        return;
    }
    if kind == KIND_STR {
        __jac_rt_release_acyclic(bits);
    } elif kind == KIND_REF or kind == KIND_TUPLE or kind == KIND_ANY {
        __jac_rt_release(bits);
    }
}

impl __jac_rt_tuple_new(n: int) -> int {
    box = __jac_rt_alloc(TUPLE_KINDS + n * 2 * SLOT);
    __jac_rt_set_type(box, int(ptr[u8]("tuple")));
    __mem_store_i64(box + TUPLE_LEN, n);
    i = 0;
    while i < n {
        __mem_store_i64(box + TUPLE_KINDS + i * SLOT, KIND_INT);
        __mem_store_i64(box + TUPLE_KINDS + (n + i) * SLOT, 0);
        i += 1;
    }
    flag = __global_block("__jac_rt_tuple_traced", 1);
    if int(__mem_load_i8(flag)) == 0 {
        __jac_rt_trace_register(int(_tuple_drop), int(_tuple_trace));
        __mem_store_i8(flag, i8(1));
    }
    __mem_store_i64(box - HDR_DTOR_BACK, int(_tuple_drop));
    return box;
}

impl __jac_rt_tuple_set(box: int, i: int, bits: int, kind: int) {
    n = __mem_load_i64(box + TUPLE_LEN);
    slot = box + TUPLE_KINDS + (n + i) * SLOT;
    __jac_rt_elem_retain(bits, kind);
    __jac_rt_elem_release(
        __mem_load_i64(slot), __mem_load_i64(box + TUPLE_KINDS + i * SLOT)
    );
    __mem_store_i64(box + TUPLE_KINDS + i * SLOT, kind);
    __mem_store_i64(slot, bits);
}

impl __jac_rt_tuple_get_ref(box: int, i: int) -> int {
    n = __mem_load_i64(box + TUPLE_LEN);
    bits = __mem_load_i64(box + TUPLE_KINDS + (n + i) * SLOT);
    __jac_rt_elem_retain(bits, __mem_load_i64(box + TUPLE_KINDS + i * SLOT));
    return bits;
}

impl __jac_rt_tuple_eq(a: int, b: int) -> bool {
    n = __mem_load_i64(a + TUPLE_LEN);
    if n != __mem_load_i64(b + TUPLE_LEN) {
        return False;
    }
    i = 0;
    while i < n {
        kind = __mem_load_i64(a + TUPLE_KINDS + i * SLOT);
        if kind != __mem_load_i64(b + TUPLE_KINDS + i * SLOT) {
            return False;
        }
        if not __jac_rt_elem_eq(
            __mem_load_i64(a + TUPLE_KINDS + (n + i) * SLOT),
            __mem_load_i64(b + TUPLE_KINDS + (n + i) * SLOT),
            kind
        ) {
            return False;
        }
        i += 1;
    }
    return True;
}

impl _tuple_cmp(a: int, b: int) -> int {
    na = __mem_load_i64(a + TUPLE_LEN);
    nb = __mem_load_i64(b + TUPLE_LEN);
    i = 0;
    while i < na and i < nb {
        kind = __mem_load_i64(a + TUPLE_KINDS + i * SLOT);
        order = _elem_cmp(
            __mem_load_i64(a + TUPLE_KINDS + (na + i) * SLOT),
            __mem_load_i64(b + TUPLE_KINDS + (nb + i) * SLOT),
            kind
        );
        if order != 0 {
            return order;
        }
        i += 1;
    }
    if na < nb {
        return -1;
    }
    if na > nb {
        return 1;
    }
    return 0;
}

impl _seq_cmp(a: int, b: int) -> int {
    na = __mem_load_i64(a + LIST_LEN);
    nb = __mem_load_i64(b + LIST_LEN);
    kind = __mem_load_i64(a + LIST_KIND);
    da = __mem_load_i64(a + LIST_DATA);
    db = __mem_load_i64(b + LIST_DATA);
    i = 0;
    while i < na and i < nb {
        order = _elem_cmp(
            __mem_load_i64(da + i * SLOT), __mem_load_i64(db + i * SLOT), kind
        );
        if order != 0 {
            return order;
        }
        i += 1;
    }
    if na < nb {
        return -1;
    }
    if na > nb {
        return 1;
    }
    return 0;
}

impl _tuple_drop(box: int) {
    collecting = _collecting();
    n = __mem_load_i64(box + TUPLE_LEN);
    i = 0;
    while i < n {
        kind = __mem_load_i64(box + TUPLE_KINDS + i * SLOT);
        if kind == KIND_STR or not collecting {
            __jac_rt_elem_release(
                __mem_load_i64(box + TUPLE_KINDS + (n + i) * SLOT), kind
            );
        }
        i += 1;
    }
    __jac_rt_free_block(box - HDR_TOTAL);
}

impl _tuple_trace(box: int, visit_fn: int) {
    n = __mem_load_i64(box + TUPLE_LEN);
    i = 0;
    while i < n {
        kind = __mem_load_i64(box + TUPLE_KINDS + i * SLOT);
        bits = __mem_load_i64(box + TUPLE_KINDS + (n + i) * SLOT);
        if bits != 0 and (kind == KIND_REF or kind == KIND_TUPLE) {
            __mem_call_dtor(visit_fn, bits);
        }
        i += 1;
    }
}

impl __jac_rt_elem_eq(a: int, b: int, kind: int) -> bool {
    if a == b {
        return True;
    }
    if kind == KIND_FLOAT {
        return __bits_float(a) == __bits_float(b);
    }
    if kind == KIND_TUPLE and a != 0 and b != 0 {
        return __jac_rt_tuple_eq(a, b);
    }
    if kind == KIND_ANY and a != 0 and b != 0 {
        return __jac_rt_any_eq(a, b);
    }
    if kind == KIND_STR and a != 0 and b != 0 {
        an = __jac_rt_str_size(ptr[u8](a));
        bn = __jac_rt_str_size(ptr[u8](b));
        return an == bn and __jac_rt_str_cmp(ptr[u8](a), an, ptr[u8](b), bn) == 0;
    }
    return False;
}

impl _elem_cmp(a: int, b: int, kind: int) -> int {
    if kind == KIND_UINT {
        return _elem_cmp(
            a ^ (-9223372036854775807 - 1), b ^ (-9223372036854775807 - 1), KIND_INT
        );
    }
    if kind == KIND_TUPLE {
        return _tuple_cmp(a, b);
    }
    if kind == KIND_SEQ {
        return _seq_cmp(a, b);
    }
    if kind == KIND_ANY {
        return _any_cmp(a, b);
    }
    if kind == KIND_FLOAT {
        fa = __bits_float(a);
        fb = __bits_float(b);
        if fa < fb {
            return -1;
        }
        if fa > fb {
            return 1;
        }
        return 0;
    }
    if kind == KIND_STR {
        return __jac_rt_str_cmp(
            ptr[u8](a),
            __jac_rt_str_size(ptr[u8](a)),
            ptr[u8](b),
            __jac_rt_str_size(ptr[u8](b))
        );
    }
    if a < b {
        return -1;
    }
    if a > b {
        return 1;
    }
    return 0;
}

impl _list_free(o: int) {
    free(__mem_load_i64(o + LIST_DATA));
    __jac_rt_free_block(o - HDR_TOTAL);
}

impl _list_drop_plain(o: int) {
    _list_free(o);
}

impl _list_drop_str(o: int) {
    n = __mem_load_i64(o + LIST_LEN);
    data = __mem_load_i64(o + LIST_DATA);
    i = 0;
    while i < n {
        bits = __mem_load_i64(data + i * SLOT);
        if bits != 0 {
            __jac_rt_release_acyclic(bits);
        }
        i += 1;
    }
    _list_free(o);
}

impl _list_drop_ref(o: int) {
    if not _collecting() {
        i = __mem_load_i64(o + LIST_LEN);
        data = __mem_load_i64(o + LIST_DATA);
        while i > 0 {
            i -= 1;
            bits = __mem_load_i64(data + i * SLOT);
            if bits != 0 {
                __jac_rt_release(bits);
            }
        }
    }
    _list_free(o);
}

impl _list_trace_ref(o: int, visit_fn: int) {
    n = __mem_load_i64(o + LIST_LEN);
    data = __mem_load_i64(o + LIST_DATA);
    i = 0;
    while i < n {
        bits = __mem_load_i64(data + i * SLOT);
        if bits != 0 {
            __mem_call_dtor(visit_fn, bits);
        }
        i += 1;
    }
}

impl __jac_rt_list_new(cap: int, kind: int) -> int {
    lst = __jac_rt_alloc(LIST_SIZE);
    __jac_rt_set_type(lst, int(ptr[u8]("list")));
    size = 0;
    data = 0;
    if cap > 0 {
        size = cap;
        data = malloc(cap * SLOT);
    }
    __mem_store_i64(lst + LIST_LEN, 0);
    __mem_store_i64(lst + LIST_CAP, size);
    __mem_store_i64(lst + LIST_DATA, data);
    __jac_rt_list_rekind(lst, kind);
    return lst;
}

impl __jac_rt_list_rekind(lst: int, kind: int) {
    __mem_store_i64(lst + LIST_KIND, kind);
    dtor = int(_list_drop_plain);
    if kind == KIND_STR {
        dtor = int(_list_drop_str);
    } elif kind == KIND_REF or kind == KIND_TUPLE or kind == KIND_ANY {
        dtor = int(_list_drop_ref);
        flag = __global_block("__jac_rt_list_traced", 1);
        if int(__mem_load_i8(flag)) == 0 {
            __jac_rt_trace_register(dtor, int(_list_trace_ref));
            __mem_store_i8(flag, i8(1));
        }
    }
    __mem_store_i64(lst - HDR_DTOR_BACK, dtor);
}

impl __jac_rt_list_reserve(lst: int, n: int) {
    cap = __mem_load_i64(lst + LIST_CAP);
    if n <= cap {
        return;
    }
    grown = cap * 2;
    if grown < LIST_MIN_CAP {
        grown = LIST_MIN_CAP;
    }
    while grown < n {
        grown = grown * 2;
    }
    data = realloc(__mem_load_i64(lst + LIST_DATA), grown * SLOT);
    if data == 0 {
        return;
    }
    __mem_store_i64(lst + LIST_DATA, data);
    __mem_store_i64(lst + LIST_CAP, grown);
}

impl __jac_rt_list_push(lst: int, bits: int, kind: int) {
    n = __mem_load_i64(lst + LIST_LEN);
    if n >= __mem_load_i64(lst + LIST_CAP) {
        __jac_rt_list_reserve(lst, n + 1);
    }
    __mem_store_i64(__mem_load_i64(lst + LIST_DATA) + n * SLOT, bits);
    __mem_store_i64(lst + LIST_LEN, n + 1);
    __jac_rt_elem_retain(bits, kind);
}

impl __jac_rt_list_set(lst: int, i: int, bits: int, kind: int) {
    at = __mem_load_i64(lst + LIST_DATA) + i * SLOT;
    old = __mem_load_i64(at);
    __jac_rt_elem_retain(bits, kind);
    __mem_store_i64(at, bits);
    __jac_rt_elem_release(old, kind);
}

impl __jac_rt_list_get_ref(lst: int, i: int, kind: int) -> int {
    bits = __mem_load_i64(__mem_load_i64(lst + LIST_DATA) + i * SLOT);
    if kind == KIND_ANY {
        have = __mem_load_i64(lst + LIST_KIND);
        if have != KIND_ANY {
            return __jac_rt_elem_box(bits, have);
        }
    }
    __jac_rt_elem_retain(bits, kind);
    return bits;
}

impl __jac_rt_list_pop(lst: int, i: int) -> int {
    n = __mem_load_i64(lst + LIST_LEN);
    data = __mem_load_i64(lst + LIST_DATA);
    bits = __mem_load_i64(data + i * SLOT);
    if i < n - 1 {
        memmove(data + i * SLOT, data + (i + 1) * SLOT, (n - 1 - i) * SLOT);
    }
    __mem_store_i64(lst + LIST_LEN, n - 1);
    return bits;
}

impl __jac_rt_list_insert(lst: int, i: int, bits: int, kind: int) {
    n = __mem_load_i64(lst + LIST_LEN);
    __jac_rt_list_reserve(lst, n + 1);
    data = __mem_load_i64(lst + LIST_DATA);
    if i < n {
        memmove(data + (i + 1) * SLOT, data + i * SLOT, (n - i) * SLOT);
    }
    __mem_store_i64(data + i * SLOT, bits);
    __mem_store_i64(lst + LIST_LEN, n + 1);
    __jac_rt_elem_retain(bits, kind);
}

impl __jac_rt_list_clear(lst: int, kind: int) {
    n = __mem_load_i64(lst + LIST_LEN);
    data = __mem_load_i64(lst + LIST_DATA);
    __mem_store_i64(lst + LIST_LEN, 0);
    __mem_store_i64(lst + LIST_CAP, 0);
    __mem_store_i64(lst + LIST_DATA, 0);
    if _is_ref_kind(kind) {
        i = n;
        while i > 0 {
            i -= 1;
            __jac_rt_elem_release(__mem_load_i64(data + i * SLOT), kind);
        }
    }
    free(data);
}

impl __jac_rt_list_delete_range(lst: int, start: int, stop: int, kind: int) {
    n = __mem_load_i64(lst + LIST_LEN);
    if stop <= start {
        return;
    }
    data = __mem_load_i64(lst + LIST_DATA);
    gone = stop - start;
    held = malloc(gone * SLOT);
    memmove(held, data + start * SLOT, gone * SLOT);
    if stop < n {
        memmove(data + start * SLOT, data + stop * SLOT, (n - stop) * SLOT);
    }
    __mem_store_i64(lst + LIST_LEN, n - gone);
    if _is_ref_kind(kind) {
        i = 0;
        while i < gone {
            __jac_rt_elem_release(__mem_load_i64(held + i * SLOT), kind);
            i += 1;
        }
    }
    free(held);
}

impl __jac_rt_list_copy(lst: int, kind: int) -> int {
    n = __mem_load_i64(lst + LIST_LEN);
    made = __jac_rt_list_new(n, kind);
    __mem_store_i64(made + LIST_KIND, __mem_load_i64(lst + LIST_KIND));
    if n > 0 {
        data = __mem_load_i64(made + LIST_DATA);
        memcpy(data, __mem_load_i64(lst + LIST_DATA), n * SLOT);
        __mem_store_i64(made + LIST_LEN, n);
        if _is_ref_kind(kind) {
            i = 0;
            while i < n {
                __jac_rt_elem_retain(__mem_load_i64(data + i * SLOT), kind);
                i += 1;
            }
        }
    }
    return made;
}

impl __jac_rt_list_box(lst: int, tag: int) -> int {
    n = __mem_load_i64(lst + LIST_LEN);
    made = __jac_rt_list_new(n, KIND_ANY);
    if n > 0 {
        src = __mem_load_i64(lst + LIST_DATA);
        data = __mem_load_i64(made + LIST_DATA);
        i = 0;
        while i < n {
            __mem_store_i64(
                data + i * SLOT, __jac_rt_any_box(tag, __mem_load_i64(src + i * SLOT))
            );
            i += 1;
        }
        __mem_store_i64(made + LIST_LEN, n);
    }
    return made;
}

impl __jac_rt_list_extend(dst: int, src: int, kind: int) {
    n = __mem_load_i64(src + LIST_LEN);
    if n <= 0 {
        return;
    }
    base = __mem_load_i64(dst + LIST_LEN);
    __jac_rt_list_reserve(dst, base + n);
    data = __mem_load_i64(dst + LIST_DATA);
    memcpy(data + base * SLOT, __mem_load_i64(src + LIST_DATA), n * SLOT);
    __mem_store_i64(dst + LIST_LEN, base + n);
    if _is_ref_kind(kind) {
        i = base;
        while i < base + n {
            __jac_rt_elem_retain(__mem_load_i64(data + i * SLOT), kind);
            i += 1;
        }
    }
}

impl __jac_rt_list_reverse(lst: int) {
    data = __mem_load_i64(lst + LIST_DATA);
    i = 0;
    j = __mem_load_i64(lst + LIST_LEN) - 1;
    while i < j {
        left = __mem_load_i64(data + i * SLOT);
        __mem_store_i64(data + i * SLOT, __mem_load_i64(data + j * SLOT));
        __mem_store_i64(data + j * SLOT, left);
        i += 1;
        j -= 1;
    }
}

impl __jac_rt_list_index(lst: int, bits: int, kind: int) -> int {
    n = __mem_load_i64(lst + LIST_LEN);
    data = __mem_load_i64(lst + LIST_DATA);
    i = 0;
    while i < n {
        if __jac_rt_elem_eq(__mem_load_i64(data + i * SLOT), bits, kind) {
            return i;
        }
        i += 1;
    }
    return -1;
}

impl __jac_rt_list_contains(lst: int, bits: int, kind: int) -> bool {
    return __jac_rt_list_index(lst, bits, kind) >= 0;
}

impl __jac_rt_list_eq(a: int, b: int, kind: int) -> bool {
    if a == b {
        return True;
    }
    if __mem_load_i64(a + LIST_KIND) != __mem_load_i64(b + LIST_KIND) {
        return __jac_rt_any_equal(TAG_LIST, a, TAG_LIST, b);
    }
    n = __mem_load_i64(a + LIST_LEN);
    if n != __mem_load_i64(b + LIST_LEN) {
        return False;
    }
    da = __mem_load_i64(a + LIST_DATA);
    db = __mem_load_i64(b + LIST_DATA);
    i = 0;
    while i < n {
        if not __jac_rt_elem_eq(
            __mem_load_i64(da + i * SLOT), __mem_load_i64(db + i * SLOT), kind
        ) {
            return False;
        }
        i += 1;
    }
    return True;
}

impl __jac_rt_list_slice(
    lst: int, start: int, stop: int, stride: int, kind: int
) -> int {
    count = 0;
    if stride > 0 and start < stop {
        count = (stop - start + stride - 1) // stride;
    } elif stride < 0 and start > stop {
        count = (start - stop - stride - 1) // (0 - stride);
    }
    made = __jac_rt_list_new(count, kind);
    __mem_store_i64(made + LIST_KIND, __mem_load_i64(lst + LIST_KIND));
    src = __mem_load_i64(lst + LIST_DATA);
    dst = __mem_load_i64(made + LIST_DATA);
    at = start;
    k = 0;
    while k < count {
        bits = __mem_load_i64(src + at * SLOT);
        __mem_store_i64(dst + k * SLOT, bits);
        __jac_rt_elem_retain(bits, kind);
        at += stride;
        k += 1;
    }
    __mem_store_i64(made + LIST_LEN, count);
    return made;
}

impl _merge(src: int, dst: int, lo: int, mid: int, hi: int, kind: int, reverse: bool) {
    i = lo;
    j = mid;
    k = lo;
    while k < hi {
        take_right = False;
        if i >= mid {
            take_right = True;
        } elif j < hi {
            order = _elem_cmp(
                __mem_load_i64(src + j * SLOT), __mem_load_i64(src + i * SLOT), kind
            );
            take_right = (order < 0 and not reverse) or (order > 0 and reverse);
        }
        if take_right {
            __mem_store_i64(dst + k * SLOT, __mem_load_i64(src + j * SLOT));
            j += 1;
        } else {
            __mem_store_i64(dst + k * SLOT, __mem_load_i64(src + i * SLOT));
            i += 1;
        }
        k += 1;
    }
}

impl __jac_rt_list_sort(lst: int, kind: int, reverse: bool) {
    n = __mem_load_i64(lst + LIST_LEN);
    if kind == KIND_REF or n < 2 {
        return;
    }
    data = __mem_load_i64(lst + LIST_DATA);
    scratch = malloc(n * SLOT);
    if scratch == 0 {
        return;
    }
    src = data;
    dst = scratch;
    width = 1;
    while width < n {
        lo = 0;
        while lo < n {
            mid = lo + width;
            if mid > n {
                mid = n;
            }
            hi = mid + width;
            if hi > n {
                hi = n;
            }
            _merge(src, dst, lo, mid, hi, kind, reverse);
            lo = hi;
        }
        held = src;
        src = dst;
        dst = held;
        width = width * 2;
    }
    if src != data {
        memcpy(data, src, n * SLOT);
    }
    free(scratch);
}

impl _merge_keyed(
    src: int, dst: int, lo: int, mid: int, hi: int, keys: int, kind: int, reverse: bool
) {
    i = lo;
    j = mid;
    k = lo;
    while k < hi {
        take_right = False;
        if i >= mid {
            take_right = True;
        } elif j < hi {
            order = _elem_cmp(
                __mem_load_i64(keys + __mem_load_i64(src + j * SLOT) * SLOT),
                __mem_load_i64(keys + __mem_load_i64(src + i * SLOT) * SLOT),
                kind
            );
            take_right = (order < 0 and not reverse) or (order > 0 and reverse);
        }
        if take_right {
            __mem_store_i64(dst + k * SLOT, __mem_load_i64(src + j * SLOT));
            j += 1;
        } else {
            __mem_store_i64(dst + k * SLOT, __mem_load_i64(src + i * SLOT));
            i += 1;
        }
        k += 1;
    }
}

impl __jac_rt_list_sort_keyed(lst: int, keys: int, kind: int, reverse: bool) {
    n = __mem_load_i64(lst + LIST_LEN);
    if n < 2 {
        return;
    }
    first = malloc(n * SLOT);
    second = malloc(n * SLOT);
    if first == 0 or second == 0 {
        free(first);
        free(second);
        return;
    }
    i = 0;
    while i < n {
        __mem_store_i64(first + i * SLOT, i);
        i += 1;
    }
    key_data = __mem_load_i64(keys + LIST_DATA);
    src = first;
    dst = second;
    width = 1;
    while width < n {
        lo = 0;
        while lo < n {
            mid = lo + width;
            if mid > n {
                mid = n;
            }
            hi = mid + width;
            if hi > n {
                hi = n;
            }
            _merge_keyed(src, dst, lo, mid, hi, key_data, kind, reverse);
            lo = hi;
        }
        held = src;
        src = dst;
        dst = held;
        width = width * 2;
    }
    data = __mem_load_i64(lst + LIST_DATA);
    memcpy(dst, data, n * SLOT);
    k = 0;
    while k < n {
        __mem_store_i64(
            data + k * SLOT, __mem_load_i64(dst + __mem_load_i64(src + k * SLOT) * SLOT)
        );
        k += 1;
    }
    free(first);
    free(second);
}
