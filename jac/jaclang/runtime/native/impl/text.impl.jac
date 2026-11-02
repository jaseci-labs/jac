impl _byte(at: int) -> int {
    return int(__mem_load_i8(at)) & 255;
}

impl _cont(byte: int) -> bool {
    return (byte & 192) == 128;
}

impl _width_at(data: int, n: int, off: int) -> int {
    w = 1;
    while off + w < n and _cont(_byte(data + off + w)) {
        w += 1;
    }
    return w;
}

impl _start_before(data: int, off: int) -> int {
    i = off - 1;
    while i > 0 and _cont(_byte(data + i)) {
        i -= 1;
    }
    return i;
}

impl _decode_at(data: int, n: int, off: int) -> int {
    lead = _byte(data + off);
    if lead < 128 {
        return lead;
    }
    w = _width_at(data, n, off);
    cp = lead & 7;
    if w == 2 {
        cp = lead & 31;
    } elif w == 3 {
        cp = lead & 15;
    }
    i = 1;
    while i < w {
        cp = (cp << 6) | (_byte(data + off + i) & 63);
        i += 1;
    }
    return cp;
}

impl _count_starts(data: int, lo: int, hi: int) -> int {
    count = 0;
    i = lo;
    while i < hi {
        if not _cont(_byte(data + i)) {
            count += 1;
        }
        i += 1;
    }
    return count;
}

impl _seek(data: int, n: int, k0: int, off0: int, k: int) -> int {
    c = k0;
    i = off0;
    while c < k and i < n {
        i += _width_at(data, n, i);
        c += 1;
    }
    return i;
}

impl _seek_back(data: int, k0: int, off0: int, k: int) -> int {
    c = k0;
    i = off0;
    while c > k and i > 0 {
        i = _start_before(data, i);
        c -= 1;
    }
    return i;
}

impl _is_ascii(owner: int, data: int, n: int) -> bool {
    if n == 0 {
        return True;
    }
    if owner == 0 or owner != data {
        return False;
    }
    tag = __mem_load_i64(owner + STR_TAG_OFF);
    return (tag & 1) != 0 and tag < 0 and ((tag & STR_LEN_PAYLOAD_MASK) >> 1) == n;
}

impl _utf8_block_free(block: int) {
    free(block);
}

impl _utf8_block -> int {
    state_at = __global_block("__jac_utf8_tls_state", 8);
    key_at = __global_block("__jac_utf8_tls_key", 8);
    if __atomic_load_i64(state_at, 2) != 1 {
        if __atomic_cas_i64(state_at, 0, 2, 4) == 0 {
            if int(pthread_key_create(key_at, int(_utf8_block_free))) != 0 {
                __atomic_store_i64(state_at, 0, 3);
                return 0;
            }
            __atomic_store_i64(state_at, 1, 3);
        } else {
            spins = 0;
            while __atomic_load_i64(state_at, 2) == 2 {
                spins += 1;
            }
            if __atomic_load_i64(state_at, 2) != 1 {
                return 0;
            }
        }
    }
    key = __mem_load_i64(key_at);
    held = pthread_getspecific(key);
    if held == 0 {
        held = calloc(1, UTF8_BLOCK_BYTES);
        if held == 0 {
            return 0;
        }
        pthread_setspecific(key, held);
    }
    return held;
}

impl _utf8_fill(at: int, base: int, data: int, n: int, epoch: int, tick: int) {
    __mem_store_i64(at + CUR_BASE, base);
    __mem_store_i64(at + CUR_DATA, data);
    __mem_store_i64(at + CUR_LEN, n);
    __mem_store_i64(at + CUR_EPOCH, epoch);
    __mem_store_i64(at + CUR_TOTAL, -1);
    __mem_store_i64(at + CUR_K, 0);
    __mem_store_i64(at + CUR_OFF, 0);
    __mem_store_i64(at + CUR_USED, tick);
}

impl _utf8_entry(owner: int, data: int, n: int) -> int {
    if n < UTF8_CURSOR_MIN_BYTES or owner == 0 or not __jac_rt_is_heap(owner) {
        return 0;
    }
    tag = __mem_load_i64(owner + STR_TAG_OFF);
    if (tag & STR_KEYED_BITS) != 1
        or ((tag & STR_LEN_PAYLOAD_MASK) >> 1) < UTF8_CURSOR_MIN_BYTES {
        return 0;
    }
    blk = _utf8_block();
    if blk == 0 {
        return 0;
    }
    now = __atomic_load_i64(__global_block("__jac_utf8_epoch", 8), 2);
    tick = __mem_load_i64(blk) + 1;
    __mem_store_i64(blk, tick);
    oldest = 0;
    oldest_use = 0;
    way = 0;
    while way < UTF8_CURSOR_WAYS {
        at = blk + (1 + way * UTF8_CURSOR_WORDS) * 8;
        if __mem_load_i64(at + CUR_BASE) == owner
            and __mem_load_i64(at + CUR_DATA) == data
            and __mem_load_i64(at + CUR_LEN) == n {
            if __mem_load_i64(at + CUR_EPOCH) == now {
                __mem_store_i64(at + CUR_USED, tick);
            } else {
                _utf8_fill(at, owner, data, n, now, tick);
            }
            return at;
        }
        used = __mem_load_i64(at + CUR_USED);
        if way == 0 or used < oldest_use {
            oldest = way;
            oldest_use = used;
        }
        way += 1;
    }
    victim = blk + (1 + oldest * UTF8_CURSOR_WORDS) * 8;
    _utf8_fill(victim, owner, data, n, now, tick);
    return victim;
}

impl _cp_offset(owner: int, data: int, n: int, k: int) -> int {
    if k <= 0 {
        return 0;
    }
    if _is_ascii(owner, data, n) {
        return k if k < n else n;
    }
    cursor = _utf8_entry(owner, data, n);
    if cursor == 0 {
        return _seek(data, n, 0, 0, k);
    }
    total = __mem_load_i64(cursor + CUR_TOTAL);
    if total >= 0 and k >= total {
        return n;
    }
    cur_k = __mem_load_i64(cursor + CUR_K);
    cur_off = __mem_load_i64(cursor + CUR_OFF);
    near = k - cur_k if k >= cur_k else cur_k - k;
    tail = total - k if total >= 0 else STOP_MAX;
    off = 0;
    if near <= k and near <= tail {
        if k >= cur_k {
            off = _seek(data, n, cur_k, cur_off, k);
        } else {
            off = _seek_back(data, cur_k, cur_off, k);
        }
    } elif tail < k {
        off = _seek_back(data, total, n, k);
    } else {
        off = _seek(data, n, 0, 0, k);
    }
    if off < n {
        __mem_store_i64(cursor + CUR_K, k);
        __mem_store_i64(cursor + CUR_OFF, off);
    }
    return off;
}

impl _cp_total(owner: int, data: int, n: int) -> int {
    if _is_ascii(owner, data, n) {
        return n;
    }
    cursor = _utf8_entry(owner, data, n);
    if cursor != 0 {
        known = __mem_load_i64(cursor + CUR_TOTAL);
        if known >= 0 {
            return known;
        }
    }
    total = _count_starts(data, 0, n);
    if cursor != 0 {
        __mem_store_i64(cursor + CUR_TOTAL, total);
    }
    return total;
}

impl __jac_rt_utf8_width(data: ptr[u8], n: int, off: int) -> int {
    return _width_at(int(data), n, off);
}

impl __jac_rt_str_cp_offset(owner: ptr[u8], data: ptr[u8], n: int, k: int) -> int {
    return _cp_offset(int(owner), int(data), n, k);
}

impl __jac_rt_str_cp_total(owner: ptr[u8], data: ptr[u8], n: int) -> int {
    return _cp_total(int(owner), int(data), n);
}

impl __jac_rt_sb_new(cap: int) -> int {
    sb = malloc(SB_SIZE);
    size = cap if cap > SB_MIN_CAP else SB_MIN_CAP;
    __mem_store_i64(sb + SB_LEN, 0);
    __mem_store_i64(sb + SB_CAP, size);
    __mem_store_i64(sb + SB_DATA, malloc(size));
    return sb;
}

impl _sb_reserve(sb: int, extra: int) {
    need = __mem_load_i64(sb + SB_LEN) + extra;
    cap = __mem_load_i64(sb + SB_CAP);
    if need <= cap {
        return;
    }
    while cap < need {
        cap = cap * 2;
    }
    __mem_store_i64(sb + SB_DATA, realloc(__mem_load_i64(sb + SB_DATA), cap));
    __mem_store_i64(sb + SB_CAP, cap);
}

impl _sb_range(sb: int, at: int, n: int) {
    if n <= 0 {
        return;
    }
    _sb_reserve(sb, n);
    size = __mem_load_i64(sb + SB_LEN);
    memcpy(__mem_load_i64(sb + SB_DATA) + size, at, n);
    __mem_store_i64(sb + SB_LEN, size + n);
}

impl _sb_repeat(sb: int, at: int, n: int, times: int) {
    k = 0;
    while k < times {
        _sb_range(sb, at, n);
        k += 1;
    }
}

impl __jac_rt_sb_add(sb: int, data: ptr[u8], n: int) {
    _sb_range(sb, int(data), n);
}

impl __jac_rt_sb_byte(sb: int, byte: int) {
    _sb_reserve(sb, 1);
    size = __mem_load_i64(sb + SB_LEN);
    __mem_store_i8(__mem_load_i64(sb + SB_DATA) + size, i8(byte));
    __mem_store_i64(sb + SB_LEN, size + 1);
}

impl __jac_rt_sb_int(sb: int, value: int) {
    buf = __thread_local_block("jac_rt_sb_int", 32);
    pos = 24;
    rest = value;
    if rest == 0 {
        pos -= 1;
        __mem_store_i8(buf + pos, i8(48));
    }
    while rest != 0 {
        digit = rest % 10;
        rest = rest // 10;
        if value < 0 and digit != 0 {
            digit = 10 - digit;
            rest += 1;
        }
        pos -= 1;
        __mem_store_i8(buf + pos, i8(48 + digit));
    }
    if value < 0 {
        pos -= 1;
        __mem_store_i8(buf + pos, i8(45));
    }
    _sb_range(sb, buf + pos, 24 - pos);
}

impl __jac_rt_sb_len(sb: int) -> int {
    return __mem_load_i64(sb + SB_LEN);
}

impl __jac_rt_sb_data(sb: int) -> int {
    return __mem_load_i64(sb + SB_DATA);
}

impl __jac_rt_sb_truncate(sb: int, n: int) {
    if n < __mem_load_i64(sb + SB_LEN) {
        __mem_store_i64(sb + SB_LEN, n);
    }
}

impl __jac_rt_sb_drop(sb: int) {
    free(__mem_load_i64(sb + SB_DATA));
    free(sb);
}

impl __jac_rt_sb_finish(sb: int) -> ptr[u8] {
    made = __jac_rt_str_new(
        ptr[u8](__mem_load_i64(sb + SB_DATA)), __mem_load_i64(sb + SB_LEN)
    );
    __jac_rt_sb_drop(sb);
    return made;
}

impl _find(hay: int, lo: int, hi: int, needle: int, nn: int, reverse: bool) -> int {
    if nn == 0 {
        return hi if reverse else lo;
    }
    if hi - lo < nn {
        return -1;
    }
    first = _byte(needle);
    if not reverse {
        i = lo;
        last = hi - nn;
        while i <= last {
            if _byte(hay + i) == first and int(memcmp(hay + i, needle, nn)) == 0 {
                return i;
            }
            i += 1;
        }
        return -1;
    }
    j = hi - nn;
    while j >= lo {
        if _byte(hay + j) == first and int(memcmp(hay + j, needle, nn)) == 0 {
            return j;
        }
        j -= 1;
    }
    return -1;
}

impl __jac_rt_str_index(owner: ptr[u8], data: ptr[u8], n: int, i: int) -> ptr[u8] {
    r = int(owner);
    d = int(data);
    at = i;
    if at < 0 {
        at += _cp_total(r, d, n);
    }
    if at < 0 {
        raise IndexError("string index out of range");
    }
    off = _cp_offset(r, d, n, at);
    if off >= n {
        raise IndexError("string index out of range");
    }
    return __jac_rt_str_new(ptr[u8](d + off), _width_at(d, n, off));
}

impl __jac_rt_str_slice(
    owner: ptr[u8], data: ptr[u8], n: int, start: int, stop: int, step: int, given: int
) -> ptr[u8] {
    if step == 0 {
        raise ValueError("slice step cannot be zero");
    }
    r = int(owner);
    d = int(data);
    total = _cp_total(r, d, n);
    has_start = (given & 1) != 0;
    has_stop = (given & 2) != 0;
    if step > 0 {
        lo = 0;
        hi = total;
        if has_start {
            lo = start;
            if lo < 0 {
                lo += total;
                if lo < 0 {
                    lo = 0;
                }
            } elif lo > total {
                lo = total;
            }
        }
        if has_stop {
            hi = stop;
            if hi < 0 {
                hi += total;
                if hi < 0 {
                    hi = 0;
                }
            } elif hi > total {
                hi = total;
            }
        }
        if hi <= lo {
            return __jac_rt_str_new(data, 0);
        }
        a = _cp_offset(r, d, n, lo);
        if step == 1 {
            return __jac_rt_str_new(ptr[u8](d + a), _cp_offset(r, d, n, hi) - a);
        }
        sb = __jac_rt_sb_new(hi - lo);
        k = lo;
        off = a;
        while k < hi and off < n {
            _sb_range(sb, d + off, _width_at(d, n, off));
            j = 0;
            while j < step and off < n {
                off += _width_at(d, n, off);
                j += 1;
            }
            if hi - k <= step {
                break;
            }
            k += step;
        }
        return __jac_rt_sb_finish(sb);
    }
    lo = total - 1;
    hi = -1;
    if has_start {
        lo = start;
        if lo < 0 {
            lo += total;
            if lo < 0 {
                lo = -1;
            }
        } elif lo >= total {
            lo = total - 1;
        }
    }
    if has_stop {
        hi = stop;
        if hi < 0 {
            hi += total;
            if hi < 0 {
                hi = -1;
            }
        } elif hi >= total {
            hi = total - 1;
        }
    }
    if lo <= hi {
        return __jac_rt_str_new(data, 0);
    }
    sb = __jac_rt_sb_new(lo - hi);
    k = lo;
    while k > hi {
        off = _cp_offset(r, d, n, k);
        _sb_range(sb, d + off, _width_at(d, n, off));
        if k - hi <= 0 - step {
            break;
        }
        k += step;
    }
    return __jac_rt_sb_finish(sb);
}

impl __jac_rt_str_find(
    owner: ptr[u8],
    data: ptr[u8],
    n: int,
    sub: ptr[u8],
    sn: int,
    start: int,
    stop: int,
    reverse: bool
) -> int {
    r = int(owner);
    d = int(data);
    total = _cp_total(r, d, n);
    lo = start;
    hi = stop;
    if lo < 0 {
        lo += total;
        if lo < 0 {
            lo = 0;
        }
    }
    if hi < 0 {
        hi += total;
        if hi < 0 {
            hi = 0;
        }
    } elif hi > total {
        hi = total;
    }
    if lo > total or hi < lo {
        return -1;
    }
    a = _cp_offset(r, d, n, lo);
    at = _find(d, a, _cp_offset(r, d, n, hi), int(sub), sn, reverse);
    if at < 0 {
        return -1;
    }
    if _is_ascii(r, d, n) {
        return at;
    }
    return lo + _count_starts(d, a, at);
}

impl __jac_rt_str_count(
    owner: ptr[u8], data: ptr[u8], n: int, sub: ptr[u8], sn: int, start: int, stop: int
) -> int {
    r = int(owner);
    d = int(data);
    total = _cp_total(r, d, n);
    lo = start;
    hi = stop;
    if lo < 0 {
        lo += total;
        if lo < 0 {
            lo = 0;
        }
    }
    if hi < 0 {
        hi += total;
        if hi < 0 {
            hi = 0;
        }
    } elif hi > total {
        hi = total;
    }
    if lo > total or hi < lo {
        return 0;
    }
    if sn == 0 {
        return hi - lo + 1;
    }
    b = _cp_offset(r, d, n, hi);
    count = 0;
    i = _cp_offset(r, d, n, lo);
    while True {
        at = _find(d, i, b, int(sub), sn, False);
        if at < 0 {
            break;
        }
        count += 1;
        i = at + sn;
    }
    return count;
}

impl __jac_rt_str_contains(data: ptr[u8], n: int, sub: ptr[u8], sn: int) -> bool {
    return _find(int(data), 0, n, int(sub), sn, False) >= 0;
}

impl __jac_rt_str_affix(
    owner: ptr[u8],
    data: ptr[u8],
    n: int,
    x: ptr[u8],
    xn: int,
    start: int,
    stop: int,
    suffix: bool
) -> bool {
    r = int(owner);
    d = int(data);
    total = _cp_total(r, d, n);
    lo = start;
    hi = stop;
    if lo < 0 {
        lo += total;
        if lo < 0 {
            lo = 0;
        }
    }
    if hi < 0 {
        hi += total;
        if hi < 0 {
            hi = 0;
        }
    } elif hi > total {
        hi = total;
    }
    if lo > total or hi < lo {
        return False;
    }
    a = _cp_offset(r, d, n, lo);
    b = _cp_offset(r, d, n, hi);
    if b - a < xn {
        return False;
    }
    if xn == 0 {
        return True;
    }
    at = b - xn if suffix else a;
    return int(memcmp(d + at, int(x), xn)) == 0;
}

impl __jac_rt_str_repeat(data: ptr[u8], n: int, times: int) -> ptr[u8] {
    if times <= 0 or n == 0 {
        return __jac_rt_str_new(data, 0);
    }
    sb = __jac_rt_sb_new(n * times);
    _sb_repeat(sb, int(data), n, times);
    return __jac_rt_sb_finish(sb);
}

impl __jac_rt_str_replace(
    data: ptr[u8], n: int, old: ptr[u8], on: int, repl: ptr[u8], rn: int, count: int
) -> ptr[u8] {
    d = int(data);
    o = int(old);
    p = int(repl);
    sb = __jac_rt_sb_new(n);
    done = 0;
    if on == 0 {
        i = 0;
        while True {
            if count < 0 or done < count {
                _sb_range(sb, p, rn);
                done += 1;
            }
            if i >= n {
                break;
            }
            w = _width_at(d, n, i);
            _sb_range(sb, d + i, w);
            i += w;
        }
        return __jac_rt_sb_finish(sb);
    }
    i = 0;
    while count < 0 or done < count {
        at = _find(d, i, n, o, on, False);
        if at < 0 {
            break;
        }
        _sb_range(sb, d + i, at - i);
        _sb_range(sb, p, rn);
        done += 1;
        i = at + on;
    }
    _sb_range(sb, d + i, n - i);
    return __jac_rt_sb_finish(sb);
}

impl _is_upper(byte: int) -> bool {
    return byte >= 65 and byte <= 90;
}

impl _is_lower(byte: int) -> bool {
    return byte >= 97 and byte <= 122;
}

impl _is_digit(byte: int) -> bool {
    return byte >= 48 and byte <= 57;
}

impl __jac_rt_str_case(data: ptr[u8], n: int, mode: int) -> ptr[u8] {
    sb = __jac_rt_sb_new(n);
    _sb_range(sb, int(data), n);
    out = __mem_load_i64(sb + SB_DATA);
    cased = False;
    i = 0;
    while i < n {
        c = _byte(out + i);
        up = _is_upper(c);
        low = _is_lower(c);
        if mode == CASE_UPPER {
            if low {
                c -= 32;
            }
        } elif mode == CASE_LOWER {
            if up {
                c += 32;
            }
        } elif mode == CASE_SWAP {
            if low {
                c -= 32;
            } elif up {
                c += 32;
            }
        } elif mode == CASE_TITLE {
            if up or low {
                if cased {
                    if up {
                        c += 32;
                    }
                } elif low {
                    c -= 32;
                }
                cased = True;
            } else {
                cased = False;
            }
        } elif i == 0 {
            if low {
                c -= 32;
            }
        } elif up {
            c += 32;
        }
        __mem_store_i8(out + i, i8(c));
        i += 1;
    }
    return __jac_rt_sb_finish(sb);
}

impl __jac_rt_str_test(data: ptr[u8], n: int, mode: int) -> bool {
    d = int(data);
    if mode == TEST_ASCII or mode == TEST_PRINTABLE {
        i = 0;
        while i < n {
            c = _byte(d + i);
            if mode == TEST_ASCII and c >= 128 {
                return False;
            }
            if mode == TEST_PRINTABLE
                and (
                    c < 32
                    or c == 127
                    or (c == 194 and i + 1 < n and _byte(d + i + 1) <= 160)
                ) {
                return False;
            }
            i += 1;
        }
        return True;
    }
    if n == 0 {
        return False;
    }
    if mode == TEST_SPACE {
        i = 0;
        while i < n {
            w = _space_width(d, n, i);
            if w == 0 {
                return False;
            }
            i += w;
        }
        return True;
    }
    if mode == TEST_UPPER or mode == TEST_LOWER or mode == TEST_TITLE {
        seen = False;
        prev = False;
        i = 0;
        while i < n {
            c = _byte(d + i);
            if _is_upper(c) {
                if mode == TEST_LOWER or (mode == TEST_TITLE and prev) {
                    return False;
                }
                seen = True;
                prev = True;
            } elif _is_lower(c) {
                if mode == TEST_UPPER or (mode == TEST_TITLE and not prev) {
                    return False;
                }
                seen = True;
                prev = True;
            } else {
                prev = False;
            }
            i += 1;
        }
        return seen;
    }
    i = 0;
    while i < n {
        c = _byte(d + i);
        ok = _is_digit(c) or _is_upper(c) or _is_lower(c);
        if mode == TEST_DIGIT {
            ok = _is_digit(c);
        } elif mode == TEST_ALPHA {
            ok = _is_upper(c) or _is_lower(c);
        } elif mode == TEST_IDENTIFIER {
            ok = c >= 128
                or c == 95
                or _is_upper(c)
                or _is_lower(c)
                or (i > 0 and _is_digit(c));
        }
        if not ok {
            return False;
        }
        i += 1;
    }
    return True;
}

impl _space_width(data: int, n: int, off: int) -> int {
    c = _byte(data + off);
    if c == 32 or (c >= 9 and c <= 13) or (c >= 28 and c <= 31) {
        return 1;
    }
    if c < 128 {
        return 0;
    }
    if c == 194 and off + 1 < n {
        c2 = _byte(data + off + 1);
        return 2 if c2 == 133 or c2 == 160 else 0;
    }
    if (c == 225 or c == 226 or c == 227) and off + 2 < n {
        c2 = _byte(data + off + 1);
        c3 = _byte(data + off + 2);
        if c == 225 and c2 == 154 and c3 == 128 {
            return 3;
        }
        if c == 226
            and c2 == 128
            and ((c3 >= 128 and c3 <= 138) or c3 == 168 or c3 == 169 or c3 == 175) {
            return 3;
        }
        if c == 226 and c2 == 129 and c3 == 159 {
            return 3;
        }
        if c == 227 and c2 == 128 and c3 == 128 {
            return 3;
        }
    }
    return 0;
}

impl _line_break_width(data: int, n: int, off: int) -> int {
    c = _byte(data + off);
    if c == 13 {
        return 2 if off + 1 < n and _byte(data + off + 1) == 10 else 1;
    }
    if c == 10 or c == 11 or c == 12 or (c >= 28 and c <= 30) {
        return 1;
    }
    if c == 194 and off + 1 < n and _byte(data + off + 1) == 133 {
        return 2;
    }
    if c == 226
        and off + 2 < n
        and _byte(data + off + 1) == 128
        and (_byte(data + off + 2) == 168 or _byte(data + off + 2) == 169) {
        return 3;
    }
    return 0;
}

impl _in_chars(data: int, off: int, w: int, chars: int, cn: int) -> bool {
    j = 0;
    while j < cn {
        cw = _width_at(chars, cn, j);
        if cw == w and int(memcmp(chars + j, data + off, w)) == 0 {
            return True;
        }
        j += cw;
    }
    return False;
}

impl __jac_rt_str_strip(
    data: ptr[u8], n: int, chars: ptr[u8], cn: int, has_chars: bool, which: int
) -> ptr[u8] {
    d = int(data);
    c = int(chars);
    lo = 0;
    hi = n;
    if which != STRIP_RIGHT {
        while lo < hi {
            w = _width_at(d, n, lo);
            if has_chars {
                if not _in_chars(d, lo, w, c, cn) {
                    break;
                }
            } elif _space_width(d, n, lo) == 0 {
                break;
            }
            lo += w;
        }
    }
    if which != STRIP_LEFT {
        while hi > lo {
            at = _start_before(d, hi);
            if at < lo {
                at = lo;
            }
            w = hi - at;
            if has_chars {
                if not _in_chars(d, at, w, c, cn) {
                    break;
                }
            } elif _space_width(d, n, at) != w {
                break;
            }
            hi = at;
        }
    }
    return __jac_rt_str_new(ptr[u8](d + lo), hi - lo);
}

impl __jac_rt_str_pad(
    owner: ptr[u8], data: ptr[u8], n: int, width: int, fill: ptr[u8], fn_len: int, mode: int
) -> ptr[u8] {
    f = int(fill);
    if _count_starts(f, 0, fn_len) != 1 {
        raise TypeError("The fill character must be exactly one character long");
    }
    total = _cp_total(int(owner), int(data), n);
    if width <= total {
        return __jac_rt_str_new(data, n);
    }
    margin = width - total;
    left = 0;
    if mode == JUST_RIGHT {
        left = margin;
    } elif mode == JUST_CENTER {
        left = margin // 2 + (margin & width & 1);
    }
    sb = __jac_rt_sb_new(n + margin * fn_len);
    _sb_repeat(sb, f, fn_len, left);
    _sb_range(sb, int(data), n);
    _sb_repeat(sb, f, fn_len, margin - left);
    return __jac_rt_sb_finish(sb);
}

impl __jac_rt_str_zfill(data: ptr[u8], n: int, width: int) -> ptr[u8] {
    d = int(data);
    total = _count_starts(d, 0, n);
    if width <= total {
        return __jac_rt_str_new(data, n);
    }
    sb = __jac_rt_sb_new(n + width - total);
    start = 0;
    if n > 0 and (_byte(d) == 43 or _byte(d) == 45) {
        _sb_range(sb, d, 1);
        start = 1;
    }
    k = total;
    while k < width {
        __jac_rt_sb_byte(sb, 48);
        k += 1;
    }
    _sb_range(sb, d + start, n - start);
    return __jac_rt_sb_finish(sb);
}

impl _push_text(lst: int, data: int, n: int) {
    made = __jac_rt_str_new(ptr[u8](data), n);
    __jac_rt_list_push(lst, int(made), KIND_STR);
    __jac_rt_release_acyclic(int(made));
}

impl __jac_rt_str_split(
    data: ptr[u8], n: int, sep: ptr[u8], sn: int, has_sep: bool, maxsplit: int, reverse: bool
) -> int {
    if has_sep and sn == 0 {
        raise ValueError("empty separator");
    }
    d = int(data);
    s = int(sep);
    lst = __jac_rt_list_new(4, KIND_STR);
    parts = 0;
    if not has_sep and not reverse {
        i = 0;
        while True {
            while i < n and _space_width(d, n, i) > 0 {
                i += _space_width(d, n, i);
            }
            if i >= n {
                break;
            }
            if maxsplit >= 0 and parts >= maxsplit {
                _push_text(lst, d + i, n - i);
                break;
            }
            j = i;
            while j < n and _space_width(d, n, j) == 0 {
                j += _width_at(d, n, j);
            }
            _push_text(lst, d + i, j - i);
            parts += 1;
            i = j;
        }
        return lst;
    }
    if not has_sep {
        j = n;
        while True {
            while j > 0 {
                at = _start_before(d, j);
                if _space_width(d, n, at) == 0 {
                    break;
                }
                j = at;
            }
            if j <= 0 {
                break;
            }
            if maxsplit >= 0 and parts >= maxsplit {
                _push_text(lst, d, j);
                break;
            }
            i = j;
            while i > 0 {
                at = _start_before(d, i);
                if _space_width(d, n, at) != 0 {
                    break;
                }
                i = at;
            }
            _push_text(lst, d + i, j - i);
            parts += 1;
            j = i;
        }
        __jac_rt_list_reverse(lst);
        return lst;
    }
    if not reverse {
        i = 0;
        while maxsplit < 0 or parts < maxsplit {
            at = _find(d, i, n, s, sn, False);
            if at < 0 {
                break;
            }
            _push_text(lst, d + i, at - i);
            parts += 1;
            i = at + sn;
        }
        _push_text(lst, d + i, n - i);
        return lst;
    }
    j = n;
    while maxsplit < 0 or parts < maxsplit {
        at = _find(d, 0, j, s, sn, True);
        if at < 0 {
            break;
        }
        _push_text(lst, d + at + sn, j - at - sn);
        parts += 1;
        j = at;
    }
    _push_text(lst, d, j);
    __jac_rt_list_reverse(lst);
    return lst;
}

impl __jac_rt_str_splitlines(data: ptr[u8], n: int, keep: bool) -> int {
    d = int(data);
    lst = __jac_rt_list_new(4, KIND_STR);
    i = 0;
    while i < n {
        j = i;
        while j < n and _line_break_width(d, n, j) == 0 {
            j += _width_at(d, n, j);
        }
        w = _line_break_width(d, n, j) if j < n else 0;
        _push_text(lst, d + i, (j + w if keep else j) - i);
        i = j + w;
    }
    return lst;
}

impl __jac_rt_str_join(sep: ptr[u8], sn: int, parts: int) -> ptr[u8] {
    count = __mem_load_i64(parts);
    items = __mem_load_i64(parts + 16);
    total = 0;
    k = 0;
    while k < count {
        total += __jac_rt_str_size(ptr[u8](__mem_load_i64(items + k * 8)));
        k += 1;
    }
    if count > 1 {
        total += sn * (count - 1);
    }
    sb = __jac_rt_sb_new(total);
    k = 0;
    while k < count {
        if k > 0 {
            _sb_range(sb, int(sep), sn);
        }
        item = __mem_load_i64(items + k * 8);
        _sb_range(sb, item, __jac_rt_str_size(ptr[u8](item)));
        k += 1;
    }
    return __jac_rt_sb_finish(sb);
}

impl __jac_rt_str_partition(
    data: ptr[u8], n: int, sep: ptr[u8], sn: int, reverse: bool
) -> int {
    if sn == 0 {
        raise ValueError("empty separator");
    }
    return _find(int(data), 0, n, int(sep), sn, reverse);
}

impl __jac_rt_str_remove_affix(
    data: ptr[u8], n: int, x: ptr[u8], xn: int, suffix: bool
) -> ptr[u8] {
    d = int(data);
    if xn == 0 or n < xn {
        return __jac_rt_str_new(data, n);
    }
    at = n - xn if suffix else 0;
    if int(memcmp(d + at, int(x), xn)) != 0 {
        return __jac_rt_str_new(data, n);
    }
    if suffix {
        return __jac_rt_str_new(data, n - xn);
    }
    return __jac_rt_str_new(ptr[u8](d + xn), n - xn);
}

impl _type_error_length(prefix: ptr[u8], count: int, suffix: ptr[u8]) -> ptr[u8] {
    sb = __jac_rt_sb_new(64);
    _sb_range(sb, int(prefix), strlen(int(prefix)));
    __jac_rt_sb_int(sb, count);
    _sb_range(sb, int(suffix), strlen(int(suffix)));
    return __jac_rt_sb_finish(sb);
}

impl __jac_rt_str_ord(owner: ptr[u8], data: ptr[u8], n: int) -> int {
    d = int(data);
    total = _cp_total(int(owner), d, n);
    if total != 1 {
        raise TypeError(
            _type_error_length(
                ptr[u8]("ord() expected a character, but string of length "),
                total,
                ptr[u8](" found")
            )
        );
    }
    return _decode_at(d, n, 0);
}

impl __jac_rt_str_chr(cp: int) -> ptr[u8] {
    if cp < 0 or cp > 1114111 {
        raise ValueError("chr() arg not in range(0x110000)");
    }
    buf = __thread_local_block("jac_rt_chr", 8);
    w = 4;
    if cp < 128 {
        __mem_store_i8(buf, i8(cp));
        w = 1;
    } elif cp < 2048 {
        __mem_store_i8(buf, i8(192 | (cp >> 6)));
        __mem_store_i8(buf + 1, i8(128 | (cp & 63)));
        w = 2;
    } elif cp < 65536 {
        __mem_store_i8(buf, i8(224 | (cp >> 12)));
        __mem_store_i8(buf + 1, i8(128 | ((cp >> 6) & 63)));
        __mem_store_i8(buf + 2, i8(128 | (cp & 63)));
        w = 3;
    } else {
        __mem_store_i8(buf, i8(240 | (cp >> 18)));
        __mem_store_i8(buf + 1, i8(128 | ((cp >> 12) & 63)));
        __mem_store_i8(buf + 2, i8(128 | ((cp >> 6) & 63)));
        __mem_store_i8(buf + 3, i8(128 | (cp & 63)));
    }
    return __jac_rt_str_new(ptr[u8](buf), w);
}

impl _hex_digit(value: int) -> int {
    return 48 + value if value < 10 else 87 + value;
}

impl _sb_hex(sb: int, value: int, digits: int) {
    shift = (digits - 1) * 4;
    while shift >= 0 {
        __jac_rt_sb_byte(sb, _hex_digit((value >> shift) & 15));
        shift -= 4;
    }
}

impl _escape_cp(sb: int, cp: int, quote: int) {
    if cp == 92 or cp == quote {
        __jac_rt_sb_byte(sb, 92);
        __jac_rt_sb_byte(sb, cp);
    } elif cp == 9 {
        __jac_rt_sb_byte(sb, 92);
        __jac_rt_sb_byte(sb, 116);
    } elif cp == 10 {
        __jac_rt_sb_byte(sb, 92);
        __jac_rt_sb_byte(sb, 110);
    } elif cp == 13 {
        __jac_rt_sb_byte(sb, 92);
        __jac_rt_sb_byte(sb, 114);
    } elif cp < 32 or cp == 127 {
        __jac_rt_sb_byte(sb, 92);
        __jac_rt_sb_byte(sb, 120);
        _sb_hex(sb, cp, 2);
    } elif cp < 128 {
        __jac_rt_sb_byte(sb, cp);
    } elif cp < 256 {
        __jac_rt_sb_byte(sb, 92);
        __jac_rt_sb_byte(sb, 120);
        _sb_hex(sb, cp, 2);
    } elif cp < 65536 {
        __jac_rt_sb_byte(sb, 92);
        __jac_rt_sb_byte(sb, 117);
        _sb_hex(sb, cp, 4);
    } else {
        __jac_rt_sb_byte(sb, 92);
        __jac_rt_sb_byte(sb, 85);
        _sb_hex(sb, cp, 8);
    }
}

impl _shown_raw(cp: int) -> bool {
    if cp < 160 {
        return False;
    }
    return not (
        cp == 173
        or (cp >= 8203 and cp <= 8207)
        or cp == 8232
        or cp == 8233
        or (cp >= 8234 and cp <= 8238)
        or cp == 65279
    );
}

impl __jac_rt_str_repr(data: ptr[u8], n: int) -> ptr[u8] {
    d = int(data);
    single = False;
    double = False;
    i = 0;
    while i < n {
        c = _byte(d + i);
        if c == 39 {
            single = True;
        } elif c == 34 {
            double = True;
        }
        i += 1;
    }
    quote = 34 if single and not double else 39;
    sb = __jac_rt_sb_new(n + 2);
    __jac_rt_sb_byte(sb, quote);
    i = 0;
    while i < n {
        w = _width_at(d, n, i);
        if w == 1 {
            _escape_cp(sb, _byte(d + i), quote);
        } else {
            cp = _decode_at(d, n, i);
            if _shown_raw(cp) {
                _sb_range(sb, d + i, w);
            } else {
                _escape_cp(sb, cp, quote);
            }
        }
        i += w;
    }
    __jac_rt_sb_byte(sb, quote);
    return __jac_rt_sb_finish(sb);
}

impl __jac_rt_str_ascii(data: ptr[u8], n: int) -> ptr[u8] {
    d = int(data);
    sb = __jac_rt_sb_new(n);
    i = 0;
    while i < n {
        w = _width_at(d, n, i);
        if w == 1 {
            __jac_rt_sb_byte(sb, _byte(d + i));
        } else {
            _escape_cp(sb, _decode_at(d, n, i), -1);
        }
        i += w;
    }
    return __jac_rt_sb_finish(sb);
}

impl __jac_rt_hash_bytes(data: ptr[u8], n: int) -> int {
    d = int(data);
    hi = 0;
    lo = 5381;
    i = 0;
    while i < n {
        lo = lo * 33 + _byte(d + i);
        carry = lo >> 32;
        lo = lo & LOW32;
        hi = (hi * 33 + carry) & LOW32;
        i += 1;
    }
    top = hi;
    if top >= HIGH_BIT32 {
        top -= SPAN32;
    }
    h = (top << 32) | lo;
    return -2 if h == -1 else h;
}

impl __jac_rt_flush(fd: int) {
    fflush(__jac_stdio(i32(fd)));
}

impl __jac_rt_repr_enter(o: int) -> int {
    st = __thread_local_block("jac_rt_repr_stack", 24);
    depth = __mem_load_i64(st);
    room = __mem_load_i64(st + 8);
    items = __mem_load_i64(st + 16);
    i = 0;
    while i < depth {
        if __mem_load_i64(items + i * 8) == o {
            return -1;
        }
        i += 1;
    }
    if depth >= room {
        room = room * 2 + 16;
        items = realloc(items, room * 8);
        __mem_store_i64(st + 8, room);
        __mem_store_i64(st + 16, items);
    }
    __mem_store_i64(items + depth * 8, o);
    __mem_store_i64(st, depth + 1);
    return depth;
}

impl __jac_rt_repr_leave(depth: int) {
    if depth >= 0 {
        __mem_store_i64(__thread_local_block("jac_rt_repr_stack", 24), depth);
    }
}
