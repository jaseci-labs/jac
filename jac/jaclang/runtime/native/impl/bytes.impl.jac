impl _byte(at: int) -> int {
    return int(__mem_load_i8(at)) & 255;
}

impl _is_space(c: int) -> bool {
    return c == 32 or (c >= 9 and c <= 13);
}

impl _hex_value(c: int) -> int {
    if c >= 48 and c <= 57 {
        return c - 48;
    }
    if c >= 97 and c <= 102 {
        return c - 87;
    }
    if c >= 65 and c <= 70 {
        return c - 55;
    }
    return -1;
}

impl _hex_digit(value: int) -> int {
    return 48 + value if value < 10 else 87 + value;
}

impl _sb_text(sb: int, text: ptr[u8]) {
    __jac_rt_sb_add(sb, text, strlen(int(text)));
}

impl _from_sb(sb: int) -> int {
    made = __jac_rt_bytes_new(ptr[u8](__jac_rt_sb_data(sb)), __jac_rt_sb_len(sb));
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
    if not reverse {
        i = lo;
        while i <= hi - nn {
            if int(memcmp(hay + i, needle, nn)) == 0 {
                return i;
            }
            i += 1;
        }
        return -1;
    }
    j = hi - nn;
    while j >= lo {
        if int(memcmp(hay + j, needle, nn)) == 0 {
            return j;
        }
        j -= 1;
    }
    return -1;
}

impl __jac_rt_bytes_new(data: ptr[u8], n: int) -> int {
    made = __jac_rt_alloc(n + BYTES_DATA);
    __jac_rt_set_type(made, int(ptr[u8]("bytes")));
    __mem_store_i64(made + BYTES_LEN, n);
    if n > 0 {
        memcpy(made + BYTES_DATA, int(data), n);
    }
    return made;
}

impl __jac_rt_bytes_zero(n: int) -> int {
    if n < 0 {
        raise ValueError("negative count");
    }
    made = __jac_rt_alloc(n + BYTES_DATA);
    __jac_rt_set_type(made, int(ptr[u8]("bytes")));
    __mem_store_i64(made + BYTES_LEN, n);
    if n > 0 {
        memset(made + BYTES_DATA, i32(0), n);
    }
    return made;
}

impl __jac_rt_bytes_from_list(lst: int) -> int {
    n = __mem_load_i64(lst + LIST_LEN);
    items = __mem_load_i64(lst + LIST_DATA);
    made = __jac_rt_alloc(n + BYTES_DATA);
    __jac_rt_set_type(made, int(ptr[u8]("bytes")));
    __mem_store_i64(made + BYTES_LEN, n);
    i = 0;
    while i < n {
        value = __mem_load_i64(items + i * 8);
        if value < 0 or value > 255 {
            __jac_rt_release_acyclic(made);
            raise ValueError("bytes must be in range(0, 256)");
        }
        __mem_store_i8(made + BYTES_DATA + i, i8(value));
        i += 1;
    }
    return made;
}

impl __jac_rt_bytes_slice(
    data: ptr[u8], n: int, start: int, stop: int, step: int, given: int
) -> int {
    if step == 0 {
        raise ValueError("slice step cannot be zero");
    }
    d = int(data);
    has_start = (given & 1) != 0;
    has_stop = (given & 2) != 0;
    if step > 0 {
        lo = 0;
        hi = n;
        if has_start {
            lo = start;
            if lo < 0 {
                lo += n;
                if lo < 0 {
                    lo = 0;
                }
            } elif lo > n {
                lo = n;
            }
        }
        if has_stop {
            hi = stop;
            if hi < 0 {
                hi += n;
                if hi < 0 {
                    hi = 0;
                }
            } elif hi > n {
                hi = n;
            }
        }
        if hi <= lo {
            return __jac_rt_bytes_new(data, 0);
        }
        if step == 1 {
            return __jac_rt_bytes_new(ptr[u8](d + lo), hi - lo);
        }
        sb = __jac_rt_sb_new(hi - lo);
        k = lo;
        while k < hi {
            __jac_rt_sb_byte(sb, _byte(d + k));
            if hi - k <= step {
                break;
            }
            k += step;
        }
        return _from_sb(sb);
    }
    lo = n - 1;
    hi = -1;
    if has_start {
        lo = start;
        if lo < 0 {
            lo += n;
            if lo < 0 {
                lo = -1;
            }
        } elif lo >= n {
            lo = n - 1;
        }
    }
    if has_stop {
        hi = stop;
        if hi < 0 {
            hi += n;
            if hi < 0 {
                hi = -1;
            }
        } elif hi >= n {
            hi = n - 1;
        }
    }
    if lo <= hi {
        return __jac_rt_bytes_new(data, 0);
    }
    sb = __jac_rt_sb_new(lo - hi);
    k = lo;
    while k > hi {
        __jac_rt_sb_byte(sb, _byte(d + k));
        if k - hi <= 0 - step {
            break;
        }
        k += step;
    }
    return _from_sb(sb);
}

impl __jac_rt_bytes_concat(a: ptr[u8], an: int, b: ptr[u8], bn: int) -> int {
    made = __jac_rt_alloc(an + bn + BYTES_DATA);
    __jac_rt_set_type(made, int(ptr[u8]("bytes")));
    __mem_store_i64(made + BYTES_LEN, an + bn);
    if an > 0 {
        memcpy(made + BYTES_DATA, int(a), an);
    }
    if bn > 0 {
        memcpy(made + BYTES_DATA + an, int(b), bn);
    }
    return made;
}

impl __jac_rt_bytes_repeat(data: ptr[u8], n: int, times: int) -> int {
    if times <= 0 or n == 0 {
        return __jac_rt_bytes_new(data, 0);
    }
    made = __jac_rt_alloc(n * times + BYTES_DATA);
    __jac_rt_set_type(made, int(ptr[u8]("bytes")));
    __mem_store_i64(made + BYTES_LEN, n * times);
    k = 0;
    while k < times {
        memcpy(made + BYTES_DATA + k * n, int(data), n);
        k += 1;
    }
    return made;
}

impl __jac_rt_bytes_find(
    data: ptr[u8], n: int, sub: ptr[u8], sn: int, start: int, stop: int, reverse: bool
) -> int {
    lo = start;
    hi = stop;
    if lo < 0 {
        lo += n;
        if lo < 0 {
            lo = 0;
        }
    }
    if hi < 0 {
        hi += n;
        if hi < 0 {
            hi = 0;
        }
    } elif hi > n {
        hi = n;
    }
    if lo > n or hi < lo {
        return -1;
    }
    return _find(int(data), lo, hi, int(sub), sn, reverse);
}

impl __jac_rt_bytes_count(
    data: ptr[u8], n: int, sub: ptr[u8], sn: int, start: int, stop: int
) -> int {
    lo = start;
    hi = stop;
    if lo < 0 {
        lo += n;
        if lo < 0 {
            lo = 0;
        }
    }
    if hi < 0 {
        hi += n;
        if hi < 0 {
            hi = 0;
        }
    } elif hi > n {
        hi = n;
    }
    if lo > n or hi < lo {
        return 0;
    }
    if sn == 0 {
        return hi - lo + 1;
    }
    count = 0;
    i = lo;
    while True {
        at = _find(int(data), i, hi, int(sub), sn, False);
        if at < 0 {
            break;
        }
        count += 1;
        i = at + sn;
    }
    return count;
}

impl __jac_rt_bytes_has(data: ptr[u8], n: int, value: int) -> bool {
    if value < 0 or value > 255 {
        raise ValueError("byte must be in range(0, 256)");
    }
    d = int(data);
    i = 0;
    while i < n {
        if _byte(d + i) == value {
            return True;
        }
        i += 1;
    }
    return False;
}

impl __jac_rt_bytes_affix(
    data: ptr[u8], n: int, x: ptr[u8], xn: int, start: int, stop: int, suffix: bool
) -> bool {
    lo = start;
    hi = stop;
    if lo < 0 {
        lo += n;
        if lo < 0 {
            lo = 0;
        }
    }
    if hi < 0 {
        hi += n;
        if hi < 0 {
            hi = 0;
        }
    } elif hi > n {
        hi = n;
    }
    if lo > n or hi < lo or hi - lo < xn {
        return False;
    }
    if xn == 0 {
        return True;
    }
    at = hi - xn if suffix else lo;
    return int(memcmp(int(data) + at, int(x), xn)) == 0;
}

impl _utf8_valid(d: int, n: int, i: int) -> int {
    c = _byte(d + i);
    if c < 128 {
        return 1;
    }
    need = 0;
    low = 128;
    high = 191;
    if c >= 194 and c <= 223 {
        need = 1;
    } elif c >= 224 and c <= 239 {
        need = 2;
        if c == 224 {
            low = 160;
        } elif c == 237 {
            high = 159;
        }
    } elif c >= 240 and c <= 244 {
        need = 3;
        if c == 240 {
            low = 144;
        } elif c == 244 {
            high = 143;
        }
    } else {
        return 0;
    }
    k = 1;
    while k <= need {
        if i + k >= n {
            return 0 - k;
        }
        b = _byte(d + i + k);
        if b < low or b > high {
            return 0 - k;
        }
        low = 128;
        high = 191;
        k += 1;
    }
    return need + 1;
}

impl _decode_error(codec: ptr[u8], byte: int, position: int, reason: ptr[u8]) -> ptr[u8] {
    sb = __jac_rt_sb_new(96);
    __jac_rt_sb_byte(sb, 39);
    _sb_text(sb, codec);
    _sb_text(sb, ptr[u8]("' codec can't decode byte 0x"));
    __jac_rt_sb_byte(sb, _hex_digit(byte >> 4));
    __jac_rt_sb_byte(sb, _hex_digit(byte & 15));
    _sb_text(sb, ptr[u8](" in position "));
    __jac_rt_sb_int(sb, position);
    _sb_text(sb, ptr[u8](": "));
    _sb_text(sb, reason);
    return __jac_rt_sb_finish(sb);
}

impl __jac_rt_bytes_decode(
    data: ptr[u8], n: int, codec: int, errors: int, failure: i32
) -> ptr[u8] {
    d = int(data);
    sb = __jac_rt_sb_new(n);
    i = 0;
    while i < n {
        c = _byte(d + i);
        if codec == CODEC_LATIN1 {
            if c < 128 {
                __jac_rt_sb_byte(sb, c);
            } else {
                __jac_rt_sb_byte(sb, 192 | (c >> 6));
                __jac_rt_sb_byte(sb, 128 | (c & 63));
            }
            i += 1;
            continue;
        }
        w = 1 if c < 128 else (0 if codec == CODEC_ASCII else _utf8_valid(d, n, i));
        if w > 0 {
            __jac_rt_sb_add(sb, ptr[u8](d + i), w);
            i += w;
            continue;
        }
        if errors == ERRORS_STRICT {
            __jac_rt_sb_drop(sb);
            if codec == CODEC_ASCII {
                __jac_rt_raise_builtin(
                    failure, _decode_error(ptr[u8]("ascii"), c, i, ptr[u8]("ordinal not in range(128)"))
                );
            }
            if w == 0 {
                __jac_rt_raise_builtin(
                    failure, _decode_error(ptr[u8]("utf-8"), c, i, ptr[u8]("invalid start byte"))
                );
            }
            if i - w >= n {
                __jac_rt_raise_builtin(
                    failure, _decode_error(ptr[u8]("utf-8"), c, i, ptr[u8]("unexpected end of data"))
                );
            }
            __jac_rt_raise_builtin(
                failure, _decode_error(ptr[u8]("utf-8"), c, i, ptr[u8]("invalid continuation byte"))
            );
        }
        if errors == ERRORS_REPLACE {
            __jac_rt_sb_byte(sb, 239);
            __jac_rt_sb_byte(sb, 191);
            __jac_rt_sb_byte(sb, 189);
        }
        i += 1 if w == 0 else 0 - w;
    }
    return __jac_rt_sb_finish(sb);
}

impl _encode_error(codec: ptr[u8], cp: int, position: int, limit: ptr[u8]) -> ptr[u8] {
    sb = __jac_rt_sb_new(96);
    __jac_rt_sb_byte(sb, 39);
    _sb_text(sb, codec);
    _sb_text(sb, ptr[u8]("' codec can't encode character '\\"));
    digits = 2;
    if cp < 256 {
        __jac_rt_sb_byte(sb, 120);
    } elif cp < 65536 {
        __jac_rt_sb_byte(sb, 117);
        digits = 4;
    } else {
        __jac_rt_sb_byte(sb, 85);
        digits = 8;
    }
    shift = (digits - 1) * 4;
    while shift >= 0 {
        __jac_rt_sb_byte(sb, _hex_digit((cp >> shift) & 15));
        shift -= 4;
    }
    _sb_text(sb, ptr[u8]("' in position "));
    __jac_rt_sb_int(sb, position);
    _sb_text(sb, ptr[u8](": ordinal not in range("));
    _sb_text(sb, limit);
    __jac_rt_sb_byte(sb, 41);
    return __jac_rt_sb_finish(sb);
}

impl __jac_rt_str_encode(
    data: ptr[u8], n: int, codec: int, errors: int, failure: i32
) -> int {
    if codec == CODEC_UTF8 {
        return __jac_rt_bytes_new(data, n);
    }
    d = int(data);
    sb = __jac_rt_sb_new(n);
    i = 0;
    position = 0;
    while i < n {
        w = __jac_rt_utf8_width(data, n, i);
        c = _byte(d + i);
        cp = c;
        if w == 2 {
            cp = ((c & 31) << 6) | (_byte(d + i + 1) & 63);
        } elif w > 2 {
            cp = 65536;
        }
        fits = cp < 128 if codec == CODEC_ASCII else cp < 256;
        if fits {
            __jac_rt_sb_byte(sb, cp);
        } elif errors == ERRORS_STRICT {
            __jac_rt_sb_drop(sb);
            if w > 2 {
                cp = c & (15 if w == 3 else 7);
                k = 1;
                while k < w {
                    cp = (cp << 6) | (_byte(d + i + k) & 63);
                    k += 1;
                }
            }
            if codec == CODEC_ASCII {
                __jac_rt_raise_builtin(
                    failure, _encode_error(ptr[u8]("ascii"), cp, position, ptr[u8]("128"))
                );
            }
            __jac_rt_raise_builtin(
                failure, _encode_error(ptr[u8]("latin-1"), cp, position, ptr[u8]("256"))
            );
        } elif errors == ERRORS_REPLACE {
            __jac_rt_sb_byte(sb, 63);
        }
        i += w;
        position += 1;
    }
    return _from_sb(sb);
}

impl __jac_rt_bytes_hex(data: ptr[u8], n: int) -> ptr[u8] {
    d = int(data);
    sb = __jac_rt_sb_new(n * 2);
    i = 0;
    while i < n {
        c = _byte(d + i);
        __jac_rt_sb_byte(sb, _hex_digit(c >> 4));
        __jac_rt_sb_byte(sb, _hex_digit(c & 15));
        i += 1;
    }
    return __jac_rt_sb_finish(sb);
}

impl _fromhex_error(position: int) -> ptr[u8] {
    sb = __jac_rt_sb_new(80);
    _sb_text(sb, ptr[u8]("non-hexadecimal number found in fromhex() arg at position "));
    __jac_rt_sb_int(sb, position);
    return __jac_rt_sb_finish(sb);
}

impl __jac_rt_bytes_fromhex(data: ptr[u8], n: int) -> int {
    d = int(data);
    sb = __jac_rt_sb_new(n // 2);
    i = 0;
    while i < n {
        if _is_space(_byte(d + i)) {
            i += 1;
            continue;
        }
        high = _hex_value(_byte(d + i));
        if high < 0 {
            __jac_rt_sb_drop(sb);
            raise ValueError(_fromhex_error(i));
        }
        if i + 1 == n {
            __jac_rt_sb_drop(sb);
            raise ValueError(
                "fromhex() arg must contain an even number of hexadecimal digits"
            );
        }
        low = _hex_value(_byte(d + i + 1));
        if low < 0 {
            __jac_rt_sb_drop(sb);
            raise ValueError(_fromhex_error(i + 1));
        }
        __jac_rt_sb_byte(sb, high * 16 + low);
        i += 2;
    }
    return _from_sb(sb);
}

impl __jac_rt_bytes_case(data: ptr[u8], n: int, mode: int) -> int {
    d = int(data);
    sb = __jac_rt_sb_new(n);
    i = 0;
    while i < n {
        c = _byte(d + i);
        if mode == CASE_UPPER and c >= 97 and c <= 122 {
            c -= 32;
        } elif mode == CASE_LOWER and c >= 65 and c <= 90 {
            c += 32;
        }
        __jac_rt_sb_byte(sb, c);
        i += 1;
    }
    return _from_sb(sb);
}

impl _in_set(c: int, chars: int, cn: int) -> bool {
    k = 0;
    while k < cn {
        if _byte(chars + k) == c {
            return True;
        }
        k += 1;
    }
    return False;
}

impl __jac_rt_bytes_strip(
    data: ptr[u8], n: int, chars: ptr[u8], cn: int, has_chars: bool, which: int
) -> int {
    d = int(data);
    lo = 0;
    hi = n;
    if which != STRIP_RIGHT {
        while lo < hi
            and (
                _in_set(_byte(d + lo), int(chars), cn)
                    if has_chars
                    else _is_space(_byte(d + lo))
            ) {
            lo += 1;
        }
    }
    if which != STRIP_LEFT {
        while hi > lo
            and (
                _in_set(_byte(d + hi - 1), int(chars), cn)
                    if has_chars
                    else _is_space(_byte(d + hi - 1))
            ) {
            hi -= 1;
        }
    }
    return __jac_rt_bytes_new(ptr[u8](d + lo), hi - lo);
}

impl _push_bytes(lst: int, at: int, n: int) {
    made = __jac_rt_bytes_new(ptr[u8](at), n);
    __jac_rt_list_push(lst, made, KIND_REF);
    __jac_rt_release_acyclic(made);
}

impl __jac_rt_bytes_split(
    data: ptr[u8], n: int, sep: ptr[u8], sn: int, has_sep: bool, maxsplit: int
) -> int {
    if has_sep and sn == 0 {
        raise ValueError("empty separator");
    }
    d = int(data);
    lst = __jac_rt_list_new(4, KIND_REF);
    parts = 0;
    if not has_sep {
        i = 0;
        while True {
            while i < n and _is_space(_byte(d + i)) {
                i += 1;
            }
            if i >= n {
                break;
            }
            if maxsplit >= 0 and parts >= maxsplit {
                _push_bytes(lst, d + i, n - i);
                break;
            }
            j = i;
            while j < n and not _is_space(_byte(d + j)) {
                j += 1;
            }
            _push_bytes(lst, d + i, j - i);
            parts += 1;
            i = j;
        }
        return lst;
    }
    i = 0;
    while maxsplit < 0 or parts < maxsplit {
        at = _find(d, i, n, int(sep), sn, False);
        if at < 0 {
            break;
        }
        _push_bytes(lst, d + i, at - i);
        parts += 1;
        i = at + sn;
    }
    _push_bytes(lst, d + i, n - i);
    return lst;
}

impl __jac_rt_bytes_replace(
    data: ptr[u8], n: int, old: ptr[u8], on: int, repl: ptr[u8], rn: int, count: int
) -> int {
    d = int(data);
    sb = __jac_rt_sb_new(n);
    done = 0;
    if on == 0 {
        i = 0;
        while True {
            if count < 0 or done < count {
                __jac_rt_sb_add(sb, repl, rn);
                done += 1;
            }
            if i >= n {
                break;
            }
            __jac_rt_sb_byte(sb, _byte(d + i));
            i += 1;
        }
        return _from_sb(sb);
    }
    i = 0;
    while count < 0 or done < count {
        at = _find(d, i, n, int(old), on, False);
        if at < 0 {
            break;
        }
        __jac_rt_sb_add(sb, ptr[u8](d + i), at - i);
        __jac_rt_sb_add(sb, repl, rn);
        done += 1;
        i = at + on;
    }
    __jac_rt_sb_add(sb, ptr[u8](d + i), n - i);
    return _from_sb(sb);
}

impl __jac_rt_bytes_join(sep: ptr[u8], sn: int, parts: int) -> int {
    count = __mem_load_i64(parts + LIST_LEN);
    items = __mem_load_i64(parts + LIST_DATA);
    sb = __jac_rt_sb_new(sn * count);
    k = 0;
    while k < count {
        if k > 0 {
            __jac_rt_sb_add(sb, sep, sn);
        }
        item = __mem_load_i64(items + k * 8);
        __jac_rt_sb_add(sb, ptr[u8](item + BYTES_DATA), __mem_load_i64(item + BYTES_LEN));
        k += 1;
    }
    return _from_sb(sb);
}

impl __jac_rt_bytes_repr(data: ptr[u8], n: int) -> ptr[u8] {
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
    sb = __jac_rt_sb_new(n + 3);
    __jac_rt_sb_byte(sb, 98);
    __jac_rt_sb_byte(sb, quote);
    i = 0;
    while i < n {
        c = _byte(d + i);
        if c == 92 or c == quote {
            __jac_rt_sb_byte(sb, 92);
            __jac_rt_sb_byte(sb, c);
        } elif c == 9 {
            _sb_text(sb, ptr[u8]("\\t"));
        } elif c == 10 {
            _sb_text(sb, ptr[u8]("\\n"));
        } elif c == 13 {
            _sb_text(sb, ptr[u8]("\\r"));
        } elif c < 32 or c >= 127 {
            __jac_rt_sb_byte(sb, 92);
            __jac_rt_sb_byte(sb, 120);
            __jac_rt_sb_byte(sb, _hex_digit(c >> 4));
            __jac_rt_sb_byte(sb, _hex_digit(c & 15));
        } else {
            __jac_rt_sb_byte(sb, c);
        }
        i += 1;
    }
    __jac_rt_sb_byte(sb, quote);
    return __jac_rt_sb_finish(sb);
}

impl _bytearray_drop(o: int) {
    free(__mem_load_i64(o + LIST_DATA));
    __jac_rt_free_block(o - HDR_TOTAL);
}

impl _bytearray_reserve(ba: int, need: int) {
    cap = __mem_load_i64(ba + LIST_CAP);
    if need <= cap {
        return;
    }
    grown = cap * 2 if cap > 0 else BYTEARRAY_MIN_CAP;
    while grown < need {
        grown = grown * 2;
    }
    __mem_store_i64(ba + LIST_DATA, realloc(__mem_load_i64(ba + LIST_DATA), grown));
    __mem_store_i64(ba + LIST_CAP, grown);
}

impl __jac_rt_bytearray_new(data: ptr[u8], n: int) -> int {
    ba = __jac_rt_alloc(LIST_SIZE);
    __jac_rt_set_type(ba, int(ptr[u8]("bytearray")));
    __mem_store_i64(ba + LIST_LEN, 0);
    __mem_store_i64(ba + LIST_CAP, 0);
    __mem_store_i64(ba + LIST_DATA, 0);
    __mem_store_i64(ba - HDR_DTOR_BACK, int(_bytearray_drop));
    __jac_rt_bytearray_extend(ba, data, n);
    return ba;
}

impl __jac_rt_bytearray_push(ba: int, value: int) {
    if value < 0 or value > 255 {
        raise ValueError("byte must be in range(0, 256)");
    }
    n = __mem_load_i64(ba + LIST_LEN);
    _bytearray_reserve(ba, n + 1);
    __mem_store_i8(__mem_load_i64(ba + LIST_DATA) + n, i8(value));
    __mem_store_i64(ba + LIST_LEN, n + 1);
}

impl __jac_rt_bytearray_set(ba: int, i: int, value: int) {
    if value < 0 or value > 255 {
        raise ValueError("byte must be in range(0, 256)");
    }
    __mem_store_i8(__mem_load_i64(ba + LIST_DATA) + i, i8(value));
}

impl __jac_rt_bytearray_extend(ba: int, data: ptr[u8], n: int) {
    if n <= 0 {
        return;
    }
    size = __mem_load_i64(ba + LIST_LEN);
    _bytearray_reserve(ba, size + n);
    memmove(__mem_load_i64(ba + LIST_DATA) + size, int(data), n);
    __mem_store_i64(ba + LIST_LEN, size + n);
}

impl __jac_rt_bytearray_pop(ba: int, i: int) -> int {
    n = __mem_load_i64(ba + LIST_LEN);
    items = __mem_load_i64(ba + LIST_DATA);
    value = _byte(items + i);
    if i < n - 1 {
        memmove(items + i, items + i + 1, n - 1 - i);
    }
    __mem_store_i64(ba + LIST_LEN, n - 1);
    return value;
}

impl __jac_rt_bytearray_clear(ba: int) {
    __mem_store_i64(ba + LIST_LEN, 0);
}
