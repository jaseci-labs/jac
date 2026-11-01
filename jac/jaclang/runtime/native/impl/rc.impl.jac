impl _g_gc_disabled -> int {
    return __global_block("__rc_gc_disabled", 1);
}

impl _g_threaded -> int {
    return __global_block("__jac_rc_threaded", 1);
}

impl _g_pool_free -> int {
    return __global_block("__jac_pool_free", 64);
}

impl _g_pool_count -> int {
    return __global_block("__jac_pool_count", 64);
}

impl _g_roots_buf -> int {
    return __global_block("__rc_roots_buf", 8);
}

impl _g_roots_cap -> int {
    return __global_block("__rc_roots_cap", 8);
}

impl _g_roots_count -> int {
    return __global_block("__rc_roots_count", 8);
}

impl _g_roots_threshold -> int {
    return __global_block("__rc_roots_threshold", 8);
}

impl _g_traced -> int {
    return __global_block("__rc_traced", 8);
}

impl _g_collecting -> int {
    return __global_block("__rc_collecting", 1);
}

impl _g_release_depth -> int {
    return __global_block("__rc_release_depth", 8);
}

impl _g_cycles_enabled -> int {
    return __global_block("__rc_cycles_enabled", 1);
}

impl _g_garbage_buf -> int {
    return __global_block("__rc_garbage_buf", 8);
}

impl _g_garbage_cap -> int {
    return __global_block("__rc_garbage_cap", 8);
}

impl _g_garbage_count -> int {
    return __global_block("__rc_garbage_count", 8);
}

impl _g_treg_keys -> int {
    return __global_block("__rc_treg_keys", 8);
}

impl _g_treg_vals -> int {
    return __global_block("__rc_treg_vals", 8);
}

impl _g_treg_cap -> int {
    return __global_block("__rc_treg_cap", 8);
}

impl _g_treg_count -> int {
    return __global_block("__rc_treg_count", 8);
}

impl _flag_on(addr: int) -> bool {
    return int(__mem_load_i8(addr)) != 0;
}

impl _threaded -> bool {
    return int(__atomic_load_i8(_g_threaded(), 0)) != 0;
}

impl _roots_threshold -> int {
    cell = _g_roots_threshold();
    limit = __mem_load_i64(cell);
    if limit == 0 {
        limit = RC_CYCLE_THRESHOLD;
        __mem_store_i64(cell, limit);
    }
    return limit;
}

impl _magic_ok(o: int) -> bool {
    return ((__mem_load_i64(o - HDR_ALLOC_ID_BACK) >> 32) & 65535) == HDR_MAGIC;
}

impl _color_bits(o: int) -> int {
    return (__mem_load_i64(o - HDR_ALLOC_ID_BACK) >> RC_COLOR_SHIFT)
        & (7 | RC_UNTRACED_BIT);
}

impl _color_store(o: int, color: int) {
    at = o - HDR_ALLOC_ID_BACK;
    __mem_store_i64(
        at, (__mem_load_i64(at) & ~RC_WORD_COLOR_BITS) | (color << RC_COLOR_SHIFT)
    );
}

impl _color_reset(o: int) {
    at = o - HDR_ALLOC_ID_BACK;
    __mem_store_i64(at, __mem_load_i64(at) & ~RC_WORD_ROOT_BITS);
}

impl _mark_untraced(o: int) {
    at = o - HDR_ALLOC_ID_BACK;
    __mem_store_i64(at, __mem_load_i64(at) | RC_WORD_UNTRACED);
}

impl _clear_buffered(o: int) {
    at = o - HDR_ALLOC_ID_BACK;
    __mem_store_i64(at, __mem_load_i64(at) & ~RC_WORD_BUFFERED);
}

impl _not_root(o: int) -> bool {
    bits = _color_bits(o);
    return (bits & 3) == RC_COLOR_PURPLE or (bits & RC_UNTRACED_BIT) != 0;
}

impl _mark_root(o: int) {
    at = o - HDR_ALLOC_ID_BACK;
    __mem_store_i64(at, (__mem_load_i64(at) & ~RC_WORD_ROOT_BITS) | RC_WORD_ROOT_BITS);
    _push_root(o);
}

impl _utf8_forget(o: int) {
    before = __atomic_add_i64(__global_block("__jac_utf8_epoch", 8), 1, 5);
    held = 0;
    if __atomic_load_i64(__global_block("__jac_utf8_tls_state", 8), 2) == 1 {
        held = pthread_getspecific(
            __mem_load_i64(__global_block("__jac_utf8_tls_key", 8))
        );
    }
    if held == 0 {
        return;
    }
    after = before + 1;
    way = 0;
    while way < UTF8_CURSOR_WAYS {
        at = held + (1 + way * UTF8_CURSOR_WORDS) * 8;
        base_at = at + UTF8_CURSOR_BASE * 8;
        epoch_at = at + UTF8_CURSOR_EPOCH * 8;
        used_at = at + UTF8_CURSOR_USED * 8;
        if __mem_load_i64(base_at) == o {
            __mem_store_i64(base_at, 0);
            __mem_store_i64(used_at, 0);
        } elif __mem_load_i64(epoch_at) == before {
            __mem_store_i64(epoch_at, after);
        }
        way += 1;
    }
}

impl _utf8_forget_on_free(o: int) {
    tag = __mem_load_i64(o - HDR_DTOR_BACK);
    if (tag & (STR_LEN_TAG_BIT | ~STR_LEN_PAYLOAD_MASK)) == STR_LEN_TAG_BIT
        and ((tag & STR_LEN_PAYLOAD_MASK) >> STR_LEN_TAG_SHIFT)
            >= UTF8_CURSOR_MIN_BYTES {
        _utf8_forget(o);
    }
}

impl _raw_free(o: int) {
    _utf8_forget_on_free(o);
    __jac_rt_free_block(o - HDR_ALLOC_ID_BACK);
}

impl _unbuffer(o: int) {
    buf = __mem_load_i64(_g_roots_buf());
    count = __mem_load_i64(_g_roots_count());
    index = __mem_load_i64(o - HDR_ALLOC_ID_BACK) & RC_WORD_SLOT_MASK;
    if index < count and __mem_load_i64(buf + index * 8) == o {
        __mem_store_i64(buf + index * 8, 0);
    } else {
        i = count;
        while i != 0 {
            i -= 1;
            if __mem_load_i64(buf + i * 8) == o {
                __mem_store_i64(buf + i * 8, 0);
                break;
            }
        }
    }
    _clear_buffered(o);
}

impl _release_impl(o: int, may_cycle: bool) {
    if o == 0 or _flag_on(_g_gc_disabled()) {
        return;
    }
    count_at = o - HDR_RC_BACK;
    old = __mem_load_i64(count_at);
    if old == RC_SENTINEL or not _magic_ok(o) or old == 0 {
        return;
    }
    prev = old;
    if _threaded() {
        prev = __atomic_sub_i64(count_at, 1, 4);
    } else {
        __mem_store_i64(count_at, old - 1);
    }
    if prev != 1 {
        if _flag_on(_g_gc_disabled())
            or _flag_on(_g_collecting())
            or not _flag_on(_g_cycles_enabled())
            or not may_cycle {
            return;
        }
        if _not_root(o) {
            return;
        }
        _mark_root(o);
        return;
    }
    if (_color_bits(o) & RC_BUFFERED_BIT) != 0 {
        if _flag_on(_g_collecting()) {
            return;
        }
        _unbuffer(o);
    }
    dtor = __mem_load_i64(o - HDR_DTOR_BACK);
    if dtor == 0 or (dtor & STR_LEN_TAG_BIT) != 0 {
        _raw_free(o);
        return;
    }
    depth = _g_release_depth();
    __mem_store_i64(depth, __mem_load_i64(depth) + 1);
    __mem_call_dtor(dtor, o);
    __mem_store_i64(depth, __mem_load_i64(depth) - 1);
}

impl _release_fast(o: int, may_cycle: bool) {
    if o == 0 {
        return;
    }
    if int(__mem_load_i8(o - HDR_RC_BACK + 7)) == RC_SENTINEL_TOP or not _magic_ok(o) {
        return;
    }
    count_at = o - HDR_RC_BACK;
    old = __mem_load_i64(count_at);
    if old <= 1 or _threaded() {
        _release_impl(o, may_cycle);
        return;
    }
    __mem_store_i64(count_at, old - 1);
    if may_cycle and not _not_root(o) {
        __jac_rt_possible_root(o);
    }
}

impl _push_root(o: int) {
    dtor = __mem_load_i64(o - HDR_DTOR_BACK);
    if dtor == 0 or __jac_rt_trace_lookup(dtor) == 0 {
        _color_reset(o);
        _mark_untraced(o);
        return;
    }
    count_at = _g_roots_count();
    cap_at = _g_roots_cap();
    buf_at = _g_roots_buf();
    cap = __mem_load_i64(cap_at);
    if __mem_load_i64(count_at) >= cap {
        grown = ROOTS_INITIAL_CAP;
        if cap != 0 {
            grown = cap * 2;
        }
        fresh = realloc(__mem_load_i64(buf_at), grown * 8);
        if fresh == 0 {
            return;
        }
        __mem_store_i64(buf_at, fresh);
        __mem_store_i64(cap_at, grown);
    }
    slot = __mem_load_i64(count_at);
    __mem_store_i64(__mem_load_i64(buf_at) + slot * 8, o);
    word_at = o - HDR_ALLOC_ID_BACK;
    __mem_store_i64(
        word_at,
        (__mem_load_i64(word_at) & ~RC_WORD_SLOT_MASK) | (slot & RC_WORD_SLOT_MASK)
    );
    __mem_store_i64(count_at, slot + 1);
    if slot + 1 < _roots_threshold() {
        return;
    }
    if _flag_on(_g_collecting())
        or not _flag_on(_g_cycles_enabled())
        or __mem_load_i64(_g_release_depth()) != 0 {
        return;
    }
    __jac_rt_collect_cycles();
}

impl _push_garbage(o: int) {
    count_at = _g_garbage_count();
    cap_at = _g_garbage_cap();
    buf_at = _g_garbage_buf();
    cap = __mem_load_i64(cap_at);
    if __mem_load_i64(count_at) >= cap {
        grown = ROOTS_INITIAL_CAP;
        if cap != 0 {
            grown = cap * 2;
        }
        fresh = realloc(__mem_load_i64(buf_at), grown * 8);
        if fresh == 0 {
            return;
        }
        __mem_store_i64(buf_at, fresh);
        __mem_store_i64(cap_at, grown);
    }
    slot = __mem_load_i64(count_at);
    __mem_store_i64(__mem_load_i64(buf_at) + slot * 8, o);
    __mem_store_i64(count_at, slot + 1);
}

impl _treg_hash(key: int, mask: int) -> int {
    return ((key >> 4) ^ (key >> 17)) & mask;
}

impl _treg_put(keys: int, vals: int, mask: int, key: int, val: int) {
    i = _treg_hash(key, mask);
    while True {
        held = __mem_load_i64(keys + i * 8);
        if held == 0 or held == key {
            __mem_store_i64(keys + i * 8, key);
            __mem_store_i64(vals + i * 8, val);
            return;
        }
        i = (i + 1) & mask;
    }
}

impl _treg_slot(key: int) -> int {
    cap = __mem_load_i64(_g_treg_cap());
    if cap == 0 {
        return 0;
    }
    mask = cap - 1;
    keys = __mem_load_i64(_g_treg_keys());
    i = _treg_hash(key, mask);
    while True {
        held = __mem_load_i64(keys + i * 8);
        if held == key {
            return __mem_load_i64(_g_treg_vals()) + i * 8;
        }
        if held == 0 {
            return 0;
        }
        i = (i + 1) & mask;
    }
    return 0;
}

impl _trace_dispatch(o: int, visitor: int) {
    if (_color_bits(o) & RC_UNTRACED_BIT) != 0 {
        return;
    }
    dtor = __mem_load_i64(o - HDR_DTOR_BACK);
    slot = 0;
    if dtor != 0 {
        slot = _treg_slot(dtor);
    }
    if slot == 0 or __mem_load_i64(slot) == 0 {
        _mark_untraced(o);
        return;
    }
    cell = ptr[JacRtTraceSlot](slot).view(1)[0];
    cell.trace(ptr[u8](o), ptr[u8](visitor));
}

impl _mark_gray(o: int) {
    if o == 0 or (_color_bits(o) & 3) == RC_COLOR_GRAY {
        return;
    }
    _color_store(o, RC_COLOR_GRAY);
    traced = _g_traced();
    __mem_store_i64(traced, __mem_load_i64(traced) + 1);
    _trace_dispatch(o, int(_mark_gray_visitor));
}

impl _mark_gray_visitor(child: int) {
    if child == 0 {
        return;
    }
    count_at = child - HDR_RC_BACK;
    count = __mem_load_i64(count_at);
    if count == RC_SENTINEL {
        return;
    }
    __mem_store_i64(count_at, count - 1);
    _mark_gray(child);
}

impl _scan_black(o: int) {
    if o == 0 or (_color_bits(o) & 3) == RC_COLOR_BLACK {
        return;
    }
    _color_store(o, RC_COLOR_BLACK);
    _trace_dispatch(o, int(_scan_black_visitor));
}

impl _scan_black_visitor(child: int) {
    if child == 0 {
        return;
    }
    count_at = child - HDR_RC_BACK;
    count = __mem_load_i64(count_at);
    if count == RC_SENTINEL {
        return;
    }
    __mem_store_i64(count_at, count + 1);
    if (_color_bits(child) & 3) == RC_COLOR_BLACK {
        return;
    }
    _scan_black(child);
}

impl _scan(o: int) {
    if o == 0 or (_color_bits(o) & 3) != RC_COLOR_GRAY {
        return;
    }
    if __mem_load_i64(o - HDR_RC_BACK) != 0 {
        _scan_black(o);
        return;
    }
    _color_store(o, RC_COLOR_WHITE);
    _trace_dispatch(o, int(_scan_visitor));
}

impl _scan_visitor(child: int) {
    if child == 0 or __mem_load_i64(child - HDR_RC_BACK) == RC_SENTINEL {
        return;
    }
    _scan(child);
}

impl _collect_white(o: int) {
    if o == 0 {
        return;
    }
    bits = _color_bits(o);
    if (bits & 3) != RC_COLOR_WHITE or (bits & RC_BUFFERED_BIT) != 0 {
        return;
    }
    _color_reset(o);
    _trace_dispatch(o, int(_collect_white_visitor));
    _push_garbage(o);
}

impl _collect_white_visitor(child: int) {
    if child == 0 {
        return;
    }
    count_at = child - HDR_RC_BACK;
    count = __mem_load_i64(count_at);
    if count == RC_SENTINEL {
        return;
    }
    if (_color_bits(child) & 3) == RC_COLOR_WHITE {
        _collect_white(child);
        return;
    }
    __mem_store_i64(count_at, count + 1);
}

impl _root_pass(count: int, phase: int) {
    buf = __mem_load_i64(_g_roots_buf());
    i = 0;
    while i < count {
        o = __mem_load_i64(buf + i * 8);
        if o != 0 {
            if phase == 1 {
                _mark_gray(o);
            } elif phase == 2 {
                _scan(o);
            } else {
                _clear_buffered(o);
                _collect_white(o);
            }
        }
        i += 1;
    }
}

impl _reclaim_one(o: int) {
    dtor = __mem_load_i64(o - HDR_DTOR_BACK);
    if dtor == 0 or (dtor & STR_LEN_TAG_BIT) != 0 {
        _raw_free(o);
        return;
    }
    __mem_call_dtor(dtor, o);
}

impl _reclaim_garbage -> None {
    count_at = _g_garbage_count();
    n = __mem_load_i64(count_at);
    buf = __mem_load_i64(_g_garbage_buf());
    i = 0;
    while i < n {
        _reclaim_one(__mem_load_i64(buf + i * 8));
        i += 1;
    }
    __mem_store_i64(count_at, 0);
}

impl __jac_rt_alloc(size: int) -> int {
    total = (size + HDR_TOTAL + 15) & -16;
    pool_class = 0;
    raw = 0;
    if total >= POOL_MIN_TOTAL and total <= POOL_MAX_TOTAL {
        index = (total >> 4) - 3;
        pool_class = index + 1;
        if not _threaded() {
            head_at = _g_pool_free() + index * 8;
            head = __mem_load_i64(head_at);
            if head != 0 {
                __mem_store_i64(head_at, __mem_load_i64(head));
                count_at = _g_pool_count() + index * 8;
                __mem_store_i64(count_at, __mem_load_i64(count_at) - 1);
                raw = head;
            }
        }
    }
    if raw == 0 {
        raw = malloc(total);
    }
    __mem_store_i64(raw, HDR_MAGIC_SHIFT_BASE | (pool_class << POOL_CLASS_SHIFT));
    __mem_store_i64(raw + HDR_TOTAL - HDR_TAG_BACK, int(ptr[u8]("raw")));
    __mem_store_i64(raw + HDR_TOTAL - HDR_RC_BACK, 1);
    __mem_store_i64(raw + HDR_TOTAL - HDR_DTOR_BACK, 0);
    return raw + HDR_TOTAL;
}

impl __jac_rt_set_type(o: int, tag: int) {
    if o == 0 {
        return;
    }
    __mem_store_i64(o - HDR_TAG_BACK, tag);
}

impl __jac_rt_retain(o: int) {
    if o == 0 {
        return;
    }
    count_at = o - HDR_RC_BACK;
    old = __mem_load_i64(count_at);
    if old == RC_SENTINEL or not _magic_ok(o) {
        return;
    }
    if _threaded() {
        __atomic_add_i64(count_at, 1, 0);
    } else {
        __mem_store_i64(count_at, old + 1);
    }
}

impl __jac_rt_release(o: int) {
    _release_fast(o, True);
}

impl __jac_rt_release_acyclic(o: int) {
    _release_fast(o, False);
}

impl __jac_rt_release_impl(o: int, may_cycle: bool) {
    _release_impl(o, may_cycle);
}

impl __jac_rt_possible_root(o: int) {
    if _flag_on(_g_gc_disabled())
        or _flag_on(_g_collecting())
        or not _flag_on(_g_cycles_enabled()) {
        return;
    }
    if _not_root(o) {
        return;
    }
    _mark_root(o);
}

impl __jac_rt_free_block(raw: int) {
    if _flag_on(_g_gc_disabled()) {
        return;
    }
    pool_class = (__mem_load_i64(raw) >> POOL_CLASS_SHIFT) & POOL_CLASS_MASK;
    if pool_class != 0 and pool_class <= POOL_CLASSES and not _threaded() {
        index = pool_class - 1;
        count_at = _g_pool_count() + index * 8;
        count = __mem_load_i64(count_at);
        if count < POOL_CAP {
            head_at = _g_pool_free() + index * 8;
            __mem_store_i64(raw, __mem_load_i64(head_at));
            __mem_store_i64(head_at, raw);
            __mem_store_i64(count_at, count + 1);
            return;
        }
    }
    free(raw);
}

impl __jac_rt_safe_free(raw: int) {
    if _flag_on(_g_gc_disabled()) {
        return;
    }
    free(raw);
}

impl __jac_rt_gc_disable -> None {
    __mem_store_i8(_g_gc_disabled(), i8(1));
}

impl __jac_rt_gc_enable -> None {
    __mem_store_i8(_g_gc_disabled(), i8(0));
}

impl __jac_rt_cycles_enable -> None {
    __mem_store_i8(_g_cycles_enabled(), i8(1));
}

impl __jac_rt_mark_threaded -> None {
    __atomic_store_i8(_g_threaded(), i8(1), 0);
}

impl __jac_rt_collect_cycles -> None {
    collecting = _g_collecting();
    if _flag_on(collecting) {
        return;
    }
    __mem_store_i8(collecting, i8(1));
    traced_at = _g_traced();
    __mem_store_i64(traced_at, 0);
    count = __mem_load_i64(_g_roots_count());
    if count != 0 {
        _root_pass(count, 1);
        _root_pass(count, 2);
        _root_pass(count, 3);
    }
    traced = __mem_load_i64(traced_at);
    garbage = __mem_load_i64(_g_garbage_count());
    live = 0;
    if traced > garbage {
        live = traced - garbage;
    }
    paced = live // RC_CYCLE_PACE;
    if paced > RC_CYCLE_THRESHOLD {
        __mem_store_i64(_g_roots_threshold(), paced);
    } else {
        __mem_store_i64(_g_roots_threshold(), RC_CYCLE_THRESHOLD);
    }
    _reclaim_garbage();
    __mem_store_i64(_g_roots_count(), 0);
    __mem_store_i8(collecting, i8(0));
}

impl __jac_rt_trace_register(dtor: int, trace: int) {
    cap_at = _g_treg_cap();
    count_at = _g_treg_count();
    keys_at = _g_treg_keys();
    vals_at = _g_treg_vals();
    cap = __mem_load_i64(cap_at);
    if (__mem_load_i64(count_at) + 1) * 2 >= cap {
        grown = TREG_INITIAL_CAP;
        if cap != 0 {
            grown = cap * 2;
        }
        fresh_keys = calloc(grown, 8);
        fresh_vals = calloc(grown, 8);
        old_keys = __mem_load_i64(keys_at);
        old_vals = __mem_load_i64(vals_at);
        j = 0;
        while j < cap {
            key = __mem_load_i64(old_keys + j * 8);
            if key != 0 {
                _treg_put(
                    fresh_keys,
                    fresh_vals,
                    grown - 1,
                    key,
                    __mem_load_i64(old_vals + j * 8)
                );
            }
            j += 1;
        }
        free(old_keys);
        free(old_vals);
        __mem_store_i64(keys_at, fresh_keys);
        __mem_store_i64(vals_at, fresh_vals);
        __mem_store_i64(cap_at, grown);
    }
    _treg_put(
        __mem_load_i64(keys_at),
        __mem_load_i64(vals_at),
        __mem_load_i64(cap_at) - 1,
        dtor,
        trace
    );
    __mem_store_i64(count_at, __mem_load_i64(count_at) + 1);
}

impl __jac_rt_trace_lookup(dtor: int) -> int {
    slot = _treg_slot(dtor);
    if slot == 0 {
        return 0;
    }
    return __mem_load_i64(slot);
}

impl jac_retain(o: ptr[u8]) {
    __jac_rt_retain(int(o));
}

impl jac_release(o: ptr[u8]) {
    __jac_rt_release(int(o));
}
