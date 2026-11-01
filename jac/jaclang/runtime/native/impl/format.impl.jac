impl _byte(at: int) -> int {
    return int(__mem_load_i8(at)) & 255;
}

impl _big_set(a: int, value: int) {
    rest = value;
    i = 0;
    while i < BIG_LIMBS {
        __mem_store_i64(a + i * 8, rest & LIMB_MASK);
        rest = rest >> LIMB_BITS;
        i += 1;
    }
}

impl _big_copy(dst: int, src: int) {
    memcpy(dst, src, BIG_BYTES);
}

impl _big_mul_small(a: int, m: int) {
    carry = 0;
    i = 0;
    while i < BIG_LIMBS {
        v = __mem_load_i64(a + i * 8) * m + carry;
        __mem_store_i64(a + i * 8, v & LIMB_MASK);
        carry = v >> LIMB_BITS;
        i += 1;
    }
}

impl _big_shl(a: int, bits: int) {
    rest = bits;
    while rest >= 27 {
        _big_mul_small(a, 134217728);
        rest -= 27;
    }
    if rest > 0 {
        _big_mul_small(a, 1 << rest);
    }
}

impl _big_pow10(a: int, k: int) {
    rest = k;
    while rest >= 8 {
        _big_mul_small(a, 100000000);
        rest -= 8;
    }
    m = 1;
    while rest > 0 {
        m = m * 10;
        rest -= 1;
    }
    if m > 1 {
        _big_mul_small(a, m);
    }
}

impl _big_cmp(a: int, b: int) -> int {
    i = BIG_LIMBS - 1;
    while i >= 0 {
        x = __mem_load_i64(a + i * 8);
        y = __mem_load_i64(b + i * 8);
        if x != y {
            return 1 if x > y else -1;
        }
        i -= 1;
    }
    return 0;
}

impl _big_add(dst: int, a: int, b: int) {
    carry = 0;
    i = 0;
    while i < BIG_LIMBS {
        v = __mem_load_i64(a + i * 8) + __mem_load_i64(b + i * 8) + carry;
        __mem_store_i64(dst + i * 8, v & LIMB_MASK);
        carry = v >> LIMB_BITS;
        i += 1;
    }
}

impl _big_sub(a: int, b: int) {
    borrow = 0;
    i = 0;
    while i < BIG_LIMBS {
        v = __mem_load_i64(a + i * 8) - __mem_load_i64(b + i * 8) - borrow;
        borrow = 0;
        if v < 0 {
            v += LIMB_BASE;
            borrow = 1;
        }
        __mem_store_i64(a + i * 8, v);
        i += 1;
    }
}

impl _big_is_zero(a: int) -> bool {
    i = 0;
    while i < BIG_LIMBS {
        if __mem_load_i64(a + i * 8) != 0 {
            return False;
        }
        i += 1;
    }
    return True;
}

impl _big_digit(r: int, s: int) -> int {
    q = 0;
    while _big_cmp(r, s) >= 0 {
        _big_sub(r, s);
        q += 1;
    }
    return q;
}

impl _round_half(r: int, s: int, t: int, last: int) -> bool {
    _big_copy(t, r);
    _big_mul_small(t, 2);
    c = _big_cmp(t, s);
    return c > 0 or (c == 0 and (last & 1) == 1);
}

impl _round_up(sb: int) -> bool {
    data = __jac_rt_sb_data(sb);
    size = __jac_rt_sb_len(sb);
    i = size - 1;
    while i >= 0 {
        c = _byte(data + i);
        if c != 57 {
            __mem_store_i8(data + i, i8(c + 1));
            return False;
        }
        __mem_store_i8(data + i, i8(48));
        i -= 1;
    }
    if size > 0 {
        __mem_store_i8(data, i8(49));
    } else {
        __jac_rt_sb_byte(sb, 49);
    }
    return True;
}

impl _dtoa(v: float, mode: int, ndigits: int, sb: int) -> int {
    work = __thread_local_block("jac_rt_dtoa", 2304);
    r = work;
    s = work + BIG_BYTES;
    mp = work + 2 * BIG_BYTES;
    mm = work + 3 * BIG_BYTES;
    t = work + 4 * BIG_BYTES;
    bits = __float_bits(v);
    be = (bits >> 52) & 2047;
    f = bits & MANT_MASK;
    e = -1074;
    if be != 0 {
        f += HIDDEN_BIT;
        e = be - 1075;
    }
    unequal = be > 1 and f == HIDDEN_BIT;
    even = (f & 1) == 0;
    _big_set(r, f);
    _big_set(s, 1);
    _big_set(mp, 1);
    _big_set(mm, 1);
    if e >= 0 {
        _big_shl(r, e);
        _big_shl(mp, e);
        _big_shl(mm, e);
        if unequal {
            _big_shl(r, 2);
            _big_shl(mp, 1);
            _big_set(s, 4);
        } else {
            _big_shl(r, 1);
            _big_set(s, 2);
        }
    } elif unequal {
        _big_shl(r, 2);
        _big_shl(s, 2 - e);
        _big_set(mp, 2);
    } else {
        _big_shl(r, 1);
        _big_shl(s, 1 - e);
    }
    width = 0;
    probe = f;
    while probe > 0 {
        width += 1;
        probe = probe >> 1;
    }
    k = int(float(e + width - 1) * LOG10_2) - 1;
    if k >= 0 {
        _big_pow10(s, k);
    } else {
        _big_pow10(r, 0 - k);
        _big_pow10(mp, 0 - k);
        _big_pow10(mm, 0 - k);
    }
    if mode == DTOA_SHORTEST {
        while True {
            _big_add(t, r, mp);
            c = _big_cmp(t, s);
            if c > 0 or (even and c == 0) {
                _big_mul_small(s, 10);
                k += 1;
            } else {
                break;
            }
        }
        while True {
            _big_mul_small(r, 10);
            _big_mul_small(mp, 10);
            _big_mul_small(mm, 10);
            d = _big_digit(r, s);
            lc = _big_cmp(r, mm);
            low = lc < 0 or (even and lc == 0);
            _big_add(t, r, mp);
            hc = _big_cmp(t, s);
            high = hc > 0 or (even and hc == 0);
            if not low and not high {
                __jac_rt_sb_byte(sb, 48 + d);
                continue;
            }
            up = high;
            if low and high {
                up = _round_half(r, s, t, d);
            }
            if up and d == 9 {
                __jac_rt_sb_byte(sb, 57);
                if _round_up(sb) {
                    k += 1;
                }
            } else {
                __jac_rt_sb_byte(sb, 48 + d + (1 if up else 0));
            }
            break;
        }
        data = __jac_rt_sb_data(sb);
        size = __jac_rt_sb_len(sb);
        while size > 1 and _byte(data + size - 1) == 48 {
            size -= 1;
        }
        __jac_rt_sb_truncate(sb, size);
        return k;
    }
    while _big_cmp(r, s) >= 0 {
        _big_mul_small(s, 10);
        k += 1;
    }
    count = ndigits if mode == DTOA_DIGITS else k + ndigits;
    if count < 0 {
        return k;
    }
    if count == 0 {
        if _round_half(r, s, t, 0) {
            __jac_rt_sb_byte(sb, 49);
            return k + 1;
        }
        return k;
    }
    last = 0;
    i = 0;
    while i < count {
        if _big_is_zero(r) {
            __jac_rt_sb_byte(sb, 48);
            last = 0;
        } else {
            _big_mul_small(r, 10);
            last = _big_digit(r, s);
            __jac_rt_sb_byte(sb, 48 + last);
        }
        i += 1;
    }
    if _round_half(r, s, t, last) and _round_up(sb) {
        k += 1;
    }
    return k;
}

impl _sb_text(sb: int, text: ptr[u8]) {
    __jac_rt_sb_add(sb, text, strlen(int(text)));
}

impl _sb_zeros(sb: int, count: int) {
    i = 0;
    while i < count {
        __jac_rt_sb_byte(sb, 48);
        i += 1;
    }
}

impl _sb_exp(sb: int, exp: int, upper: bool) {
    __jac_rt_sb_byte(sb, 69 if upper else 101);
    __jac_rt_sb_byte(sb, 45 if exp < 0 else 43);
    mag = 0 - exp if exp < 0 else exp;
    if mag < 10 {
        __jac_rt_sb_byte(sb, 48);
    }
    __jac_rt_sb_int(sb, mag);
}

impl _special(sb: int, bits: int, upper: bool) -> bool {
    if ((bits >> 52) & 2047) != 2047 {
        return False;
    }
    if (bits & MANT_MASK) != 0 {
        _sb_text(sb, ptr[u8]("NAN") if upper else ptr[u8]("nan"));
    } else {
        _sb_text(sb, ptr[u8]("INF") if upper else ptr[u8]("inf"));
    }
    return True;
}

impl _repr_into(sb: int, v: float) {
    bits = __float_bits(v);
    nan = ((bits >> 52) & 2047) == 2047 and (bits & MANT_MASK) != 0;
    if bits < 0 and not nan {
        __jac_rt_sb_byte(sb, 45);
    }
    if _special(sb, bits, False) {
        return;
    }
    mag = __bits_float(bits & ABS_MASK);
    if mag == 0.0 {
        _sb_text(sb, ptr[u8]("0.0"));
        return;
    }
    digits = __jac_rt_sb_new(24);
    decpt = _dtoa(mag, DTOA_SHORTEST, 0, digits);
    dd = __jac_rt_sb_data(digits);
    nd = __jac_rt_sb_len(digits);
    if decpt <= -4 or decpt > 16 {
        __jac_rt_sb_byte(sb, _byte(dd));
        if nd > 1 {
            __jac_rt_sb_byte(sb, 46);
            __jac_rt_sb_add(sb, ptr[u8](dd + 1), nd - 1);
        }
        _sb_exp(sb, decpt - 1, False);
    } elif decpt <= 0 {
        _sb_text(sb, ptr[u8]("0."));
        _sb_zeros(sb, 0 - decpt);
        __jac_rt_sb_add(sb, ptr[u8](dd), nd);
    } elif decpt >= nd {
        __jac_rt_sb_add(sb, ptr[u8](dd), nd);
        _sb_zeros(sb, decpt - nd);
        _sb_text(sb, ptr[u8](".0"));
    } else {
        __jac_rt_sb_add(sb, ptr[u8](dd), decpt);
        __jac_rt_sb_byte(sb, 46);
        __jac_rt_sb_add(sb, ptr[u8](dd + decpt), nd - decpt);
    }
    __jac_rt_sb_drop(digits);
}

impl __jac_rt_float_repr(v: float) -> ptr[u8] {
    sb = __jac_rt_sb_new(32);
    _repr_into(sb, v);
    return __jac_rt_sb_finish(sb);
}

impl _fixed_into(sb: int, mag: float, prec: int, alt: bool) {
    digits = __jac_rt_sb_new(prec + 24);
    decpt = 0;
    if mag != 0.0 {
        decpt = _dtoa(mag, DTOA_PLACES, prec, digits);
    }
    dd = __jac_rt_sb_data(digits);
    nd = __jac_rt_sb_len(digits);
    if decpt <= 0 {
        __jac_rt_sb_byte(sb, 48);
    } else {
        i = 0;
        while i < decpt {
            __jac_rt_sb_byte(sb, _byte(dd + i) if i < nd else 48);
            i += 1;
        }
    }
    if prec > 0 or alt {
        __jac_rt_sb_byte(sb, 46);
    }
    j = 0;
    while j < prec {
        at = decpt + j;
        __jac_rt_sb_byte(sb, _byte(dd + at) if at >= 0 and at < nd else 48);
        j += 1;
    }
    __jac_rt_sb_drop(digits);
}

impl _exp_into(sb: int, mag: float, prec: int, alt: bool, upper: bool) {
    digits = __jac_rt_sb_new(prec + 24);
    exp = 0;
    if mag == 0.0 {
        _sb_zeros(digits, prec + 1);
    } else {
        exp = _dtoa(mag, DTOA_DIGITS, prec + 1, digits) - 1;
    }
    dd = __jac_rt_sb_data(digits);
    __jac_rt_sb_byte(sb, _byte(dd));
    if prec > 0 or alt {
        __jac_rt_sb_byte(sb, 46);
    }
    __jac_rt_sb_add(sb, ptr[u8](dd + 1), prec);
    _sb_exp(sb, exp, upper);
    __jac_rt_sb_drop(digits);
}

impl _general_into(sb: int, mag: float, prec: int, alt: bool, upper: bool, add_dot: bool) {
    p = prec if prec > 0 else 1;
    digits = __jac_rt_sb_new(p + 24);
    decpt = 1;
    if mag == 0.0 {
        _sb_zeros(digits, p);
    } else {
        decpt = _dtoa(mag, DTOA_DIGITS, p, digits);
    }
    dd = __jac_rt_sb_data(digits);
    nd = __jac_rt_sb_len(digits);
    if not alt {
        while nd > 1 and _byte(dd + nd - 1) == 48 {
            nd -= 1;
        }
    }
    limit = p - 1 if add_dot else p;
    if decpt <= -4 or decpt > limit {
        __jac_rt_sb_byte(sb, _byte(dd));
        if nd > 1 or alt {
            __jac_rt_sb_byte(sb, 46);
        }
        __jac_rt_sb_add(sb, ptr[u8](dd + 1), nd - 1);
        _sb_exp(sb, decpt - 1, upper);
    } elif decpt <= 0 {
        _sb_text(sb, ptr[u8]("0."));
        _sb_zeros(sb, 0 - decpt);
        __jac_rt_sb_add(sb, ptr[u8](dd), nd);
    } elif decpt >= nd {
        __jac_rt_sb_add(sb, ptr[u8](dd), nd);
        _sb_zeros(sb, decpt - nd);
        if alt or add_dot {
            __jac_rt_sb_byte(sb, 46);
        }
        if add_dot and not alt {
            __jac_rt_sb_byte(sb, 48);
        }
    } else {
        __jac_rt_sb_add(sb, ptr[u8](dd), decpt);
        __jac_rt_sb_byte(sb, 46);
        __jac_rt_sb_add(sb, ptr[u8](dd + decpt), nd - decpt);
    }
    __jac_rt_sb_drop(digits);
}

impl _is_align(c: int) -> bool {
    return c == 60 or c == 62 or c == 94 or c == 61;
}

impl _is_digit(c: int) -> bool {
    return c >= 48 and c <= 57;
}

impl _message(head: ptr[u8], text: int, tn: int, kind: ptr[u8]) -> ptr[u8] {
    sb = __jac_rt_sb_new(64);
    _sb_text(sb, head);
    __jac_rt_sb_add(sb, ptr[u8](text), tn);
    _sb_text(sb, ptr[u8]("' for object of type '"));
    _sb_text(sb, kind);
    __jac_rt_sb_byte(sb, 39);
    return __jac_rt_sb_finish(sb);
}

impl _message_with(head: ptr[u8], c: int, tail: ptr[u8]) -> ptr[u8] {
    sb = __jac_rt_sb_new(48);
    _sb_text(sb, head);
    __jac_rt_sb_byte(sb, c);
    _sb_text(sb, tail);
    return __jac_rt_sb_finish(sb);
}

impl _spec_parse(spec: int, sn: int, kind: ptr[u8]) -> int {
    rec = __thread_local_block("jac_rt_fmt_spec", 96);
    __mem_store_i64(rec + SP_FILL_AT, 0);
    __mem_store_i64(rec + SP_FILL_LEN, 0);
    __mem_store_i64(rec + SP_ALIGN, 0);
    __mem_store_i64(rec + SP_SIGN, 0);
    __mem_store_i64(rec + SP_ALT, 0);
    __mem_store_i64(rec + SP_ZERO, 0);
    __mem_store_i64(rec + SP_ZC, 0);
    __mem_store_i64(rec + SP_WIDTH, -1);
    __mem_store_i64(rec + SP_GROUP, 0);
    __mem_store_i64(rec + SP_PREC, -1);
    __mem_store_i64(rec + SP_TYPE, 0);
    i = 0;
    if sn > 0 {
        w = __jac_rt_utf8_width(ptr[u8](spec), sn, 0);
        if w < sn and _is_align(_byte(spec + w)) {
            __mem_store_i64(rec + SP_FILL_AT, spec);
            __mem_store_i64(rec + SP_FILL_LEN, w);
            __mem_store_i64(rec + SP_ALIGN, _byte(spec + w));
            i = w + 1;
        } elif _is_align(_byte(spec)) {
            __mem_store_i64(rec + SP_ALIGN, _byte(spec));
            i = 1;
        }
    }
    if i < sn and (_byte(spec + i) == 43 or _byte(spec + i) == 45 or _byte(spec + i) == 32) {
        __mem_store_i64(rec + SP_SIGN, _byte(spec + i));
        i += 1;
    }
    if i < sn and _byte(spec + i) == 122 {
        __mem_store_i64(rec + SP_ZC, 1);
        i += 1;
    }
    if i < sn and _byte(spec + i) == 35 {
        __mem_store_i64(rec + SP_ALT, 1);
        i += 1;
    }
    if i < sn and _byte(spec + i) == 48 {
        __mem_store_i64(rec + SP_ZERO, 1);
        i += 1;
    }
    width = -1;
    while i < sn and _is_digit(_byte(spec + i)) {
        if width < 0 {
            width = 0;
        }
        width = width * 10 + _byte(spec + i) - 48;
        i += 1;
    }
    __mem_store_i64(rec + SP_WIDTH, width);
    if i < sn and (_byte(spec + i) == 44 or _byte(spec + i) == 95) {
        __mem_store_i64(rec + SP_GROUP, _byte(spec + i));
        i += 1;
        if i < sn and (_byte(spec + i) == 44 or _byte(spec + i) == 95) {
            raise ValueError("Cannot specify both ',' and '_'.");
        }
    }
    if i < sn and _byte(spec + i) == 46 {
        i += 1;
        if i >= sn or not _is_digit(_byte(spec + i)) {
            raise ValueError("Format specifier missing precision");
        }
        prec = 0;
        while i < sn and _is_digit(_byte(spec + i)) {
            prec = prec * 10 + _byte(spec + i) - 48;
            i += 1;
        }
        __mem_store_i64(rec + SP_PREC, prec);
    }
    if i < sn {
        __mem_store_i64(rec + SP_TYPE, _byte(spec + i));
        i += 1;
    }
    if i < sn {
        raise ValueError(_message(ptr[u8]("Invalid format specifier '"), spec, sn, kind));
    }
    return rec;
}

impl _unknown_code(rec: int, kind: ptr[u8]) {
    sb = __jac_rt_sb_new(8);
    __jac_rt_sb_byte(sb, __mem_load_i64(rec + SP_TYPE));
    code = __jac_rt_sb_finish(sb);
    raise ValueError(_message(ptr[u8]("Unknown format code '"), int(code), 1, kind));
}

impl _grouped_len(m: int, group: int, gsize: int) -> int {
    if group == 0 or m <= 0 {
        return m;
    }
    return m + (m - 1) // gsize;
}

impl _emit_grouped(sb: int, zeros: int, digits: int, ip: int, group: int, gsize: int) {
    m = zeros + ip;
    p = 0;
    while p < m {
        if group != 0 and p > 0 and (m - p) % gsize == 0 {
            __jac_rt_sb_byte(sb, group);
        }
        __jac_rt_sb_byte(sb, 48 if p < zeros else _byte(digits + p - zeros));
        p += 1;
    }
}

impl _emit_fill(sb: int, fill_at: int, fill_len: int, count: int) {
    i = 0;
    while i < count {
        __jac_rt_sb_add(sb, ptr[u8](fill_at), fill_len);
        i += 1;
    }
}

impl _finish(
    rec: int, body: int, ip: int, bn: int, neg: bool, prefix: int, gsize: int
) -> ptr[u8] {
    out = __jac_rt_sb_new(bn + 16);
    sign = __mem_load_i64(rec + SP_SIGN);
    sign_byte = 45 if neg else (sign if sign == 43 or sign == 32 else 0);
    fill_at = __mem_load_i64(rec + SP_FILL_AT);
    fill_len = __mem_load_i64(rec + SP_FILL_LEN);
    align = __mem_load_i64(rec + SP_ALIGN);
    width = __mem_load_i64(rec + SP_WIDTH);
    group = __mem_load_i64(rec + SP_GROUP);
    if __mem_load_i64(rec + SP_ZERO) == 1 {
        if fill_len == 0 {
            fill_at = int(ptr[u8]("0"));
            fill_len = 1;
        }
        if align == 0 {
            align = 61;
        }
    }
    if fill_len == 0 {
        fill_at = int(ptr[u8](" "));
        fill_len = 1;
    }
    if align == 0 {
        align = 62;
    }
    head = (1 if sign_byte != 0 else 0) + (2 if prefix != 0 else 0);
    rest = bn - ip;
    glen = _grouped_len(ip, group, gsize);
    if align == 61 {
        if sign_byte != 0 {
            __jac_rt_sb_byte(out, sign_byte);
        }
        if prefix != 0 {
            __jac_rt_sb_byte(out, 48);
            __jac_rt_sb_byte(out, prefix);
        }
        if fill_len == 1 and _byte(fill_at) == 48 and group != 0 {
            zeros = 0;
            while head + _grouped_len(ip + zeros, group, gsize) + rest < width {
                zeros += 1;
            }
            _emit_grouped(out, zeros, body, ip, group, gsize);
        } else {
            room = width - head - glen - rest;
            _emit_fill(out, fill_at, fill_len, room);
            _emit_grouped(out, 0, body, ip, group, gsize);
        }
        __jac_rt_sb_add(out, ptr[u8](body + ip), rest);
        return __jac_rt_sb_finish(out);
    }
    total = head + glen + rest;
    margin = width - total if width > total else 0;
    left = margin;
    if align == 60 {
        left = 0;
    } elif align == 94 {
        left = margin // 2;
    }
    _emit_fill(out, fill_at, fill_len, left);
    if sign_byte != 0 {
        __jac_rt_sb_byte(out, sign_byte);
    }
    if prefix != 0 {
        __jac_rt_sb_byte(out, 48);
        __jac_rt_sb_byte(out, prefix);
    }
    _emit_grouped(out, 0, body, ip, group, gsize);
    __jac_rt_sb_add(out, ptr[u8](body + ip), rest);
    _emit_fill(out, fill_at, fill_len, margin - left);
    return __jac_rt_sb_finish(out);
}

impl _digits_into(sb: int, value: int, base: int, upper: bool) {
    buf = __thread_local_block("jac_rt_fmt_digits", 72);
    pos = 64;
    rest = value;
    if rest == 0 {
        pos -= 1;
        __mem_store_i8(buf + pos, i8(48));
    }
    while rest != 0 {
        digit = rest % base;
        rest = rest // base;
        if value < 0 and digit != 0 {
            digit = base - digit;
            rest += 1;
        }
        pos -= 1;
        c = 48 + digit;
        if digit >= 10 {
            c = (55 if upper else 87) + digit;
        }
        __mem_store_i8(buf + pos, i8(c));
    }
    __jac_rt_sb_add(sb, ptr[u8](buf + pos), 64 - pos);
}

impl __jac_rt_format_int(v: int, spec: ptr[u8], sn: int) -> ptr[u8] {
    rec = _spec_parse(int(spec), sn, ptr[u8]("int"));
    typ = __mem_load_i64(rec + SP_TYPE);
    if typ == 102
        or typ == 70
        or typ == 101
        or typ == 69
        or typ == 103
        or typ == 71
        or typ == 37 {
        return __jac_rt_format_float(float(v), spec, sn);
    }
    if __mem_load_i64(rec + SP_ZC) == 1 {
        raise ValueError(
            "Negative zero coercion (z) not allowed in integer format specifier"
        );
    }
    if __mem_load_i64(rec + SP_PREC) >= 0 {
        raise ValueError("Precision not allowed in integer format specifier");
    }
    group = __mem_load_i64(rec + SP_GROUP);
    body = __jac_rt_sb_new(72);
    if typ == 99 {
        if __mem_load_i64(rec + SP_SIGN) != 0 {
            raise ValueError("Sign not allowed with integer format specifier 'c'");
        }
        if __mem_load_i64(rec + SP_ALT) == 1 {
            raise ValueError(
                "Alternate form (#) not allowed with integer format specifier 'c'"
            );
        }
        if group != 0 {
            raise ValueError(
                _message_with(ptr[u8]("Cannot specify '"), group, ptr[u8]("' with 'c'."))
            );
        }
        if v < 0 or v > 1114111 {
            raise OverflowError("%c arg not in range(0x110000)");
        }
        ch = __jac_rt_str_chr(v);
        cn = __jac_rt_str_size(ch);
        __jac_rt_sb_add(body, ch, cn);
        __jac_rt_release_acyclic(int(ch));
        __mem_store_i64(rec + SP_GROUP, 0);
        made = _finish(rec, __jac_rt_sb_data(body), 0, cn, False, 0, 3);
        __jac_rt_sb_drop(body);
        return made;
    }
    if typ != 0
        and typ != 100
        and typ != 110
        and typ != 98
        and typ != 111
        and typ != 120
        and typ != 88 {
        _unknown_code(rec, ptr[u8]("int"));
    }
    gsize = 3;
    base = 10;
    prefix = 0;
    if typ == 98 or typ == 111 or typ == 120 or typ == 88 {
        gsize = 4;
        if group == 44 {
            raise ValueError(
                _message_with(ptr[u8]("Cannot specify ',' with '"), typ, ptr[u8]("'."))
            );
        }
        base = 2 if typ == 98 else (8 if typ == 111 else 16);
        if __mem_load_i64(rec + SP_ALT) == 1 {
            prefix = typ;
        }
    }
    if typ == 110 and group != 0 {
        raise ValueError(
            _message_with(ptr[u8]("Cannot specify '"), group, ptr[u8]("' with 'n'."))
        );
    }
    _digits_into(body, v, base, typ == 88);
    bn = __jac_rt_sb_len(body);
    made = _finish(rec, __jac_rt_sb_data(body), bn, bn, v < 0, prefix, gsize);
    __jac_rt_sb_drop(body);
    return made;
}

impl __jac_rt_format_bool(v: bool, spec: ptr[u8], sn: int) -> ptr[u8] {
    if sn == 0 {
        if v {
            return __jac_rt_str_new(ptr[u8]("True"), 4);
        }
        return __jac_rt_str_new(ptr[u8]("False"), 5);
    }
    return __jac_rt_format_int(1 if v else 0, spec, sn);
}

impl __jac_rt_format_float(v: float, spec: ptr[u8], sn: int) -> ptr[u8] {
    rec = _spec_parse(int(spec), sn, ptr[u8]("float"));
    typ = __mem_load_i64(rec + SP_TYPE);
    if typ != 0
        and typ != 102
        and typ != 70
        and typ != 101
        and typ != 69
        and typ != 103
        and typ != 71
        and typ != 37
        and typ != 110 {
        _unknown_code(rec, ptr[u8]("float"));
    }
    group = __mem_load_i64(rec + SP_GROUP);
    if typ == 110 and group != 0 {
        raise ValueError(
            _message_with(ptr[u8]("Cannot specify '"), group, ptr[u8]("' with 'n'."))
        );
    }
    alt = __mem_load_i64(rec + SP_ALT) == 1;
    prec = __mem_load_i64(rec + SP_PREC);
    p = prec if prec >= 0 else 6;
    upper = typ == 70 or typ == 69 or typ == 71;
    bits = __float_bits(v);
    nan = ((bits >> 52) & 2047) == 2047 and (bits & MANT_MASK) != 0;
    neg = bits < 0 and not nan;
    mag = __bits_float(bits & ABS_MASK);
    body = __jac_rt_sb_new(32);
    if _special(body, bits, upper) {
        if typ == 37 {
            __jac_rt_sb_byte(body, 37);
        }
        if __mem_load_i64(rec + SP_ZERO) == 1 and __mem_load_i64(rec + SP_FILL_LEN) == 0 {
            __mem_store_i64(rec + SP_FILL_AT, int(ptr[u8](" ")));
            __mem_store_i64(rec + SP_FILL_LEN, 1);
        }
        __mem_store_i64(rec + SP_GROUP, 0);
        bn = __jac_rt_sb_len(body);
        made = _finish(rec, __jac_rt_sb_data(body), 0, bn, neg, 0, 3);
        __jac_rt_sb_drop(body);
        return made;
    }
    if typ == 102 or typ == 70 {
        _fixed_into(body, mag, p, alt);
    } elif typ == 101 or typ == 69 {
        _exp_into(body, mag, p, alt, upper);
    } elif typ == 103 or typ == 71 or typ == 110 {
        _general_into(body, mag, p, alt, upper, False);
    } elif typ == 37 {
        _fixed_into(body, mag * 100.0, p, alt);
        __jac_rt_sb_byte(body, 37);
    } elif prec >= 0 {
        _general_into(body, mag, prec, alt, False, True);
    } else {
        _repr_into(body, mag);
    }
    data = __jac_rt_sb_data(body);
    bn = __jac_rt_sb_len(body);
    if neg and __mem_load_i64(rec + SP_ZC) == 1 {
        zero = True;
        i = 0;
        while i < bn {
            c = _byte(data + i);
            if c >= 49 and c <= 57 {
                zero = False;
            }
            i += 1;
        }
        if zero {
            neg = False;
        }
    }
    ip = 0;
    while ip < bn and _is_digit(_byte(data + ip)) {
        ip += 1;
    }
    made = _finish(rec, data, ip, bn, neg, 0, 3);
    __jac_rt_sb_drop(body);
    return made;
}

impl __jac_rt_format_str(data: ptr[u8], n: int, spec: ptr[u8], sn: int) -> ptr[u8] {
    rec = _spec_parse(int(spec), sn, ptr[u8]("str"));
    typ = __mem_load_i64(rec + SP_TYPE);
    if typ != 0 and typ != 115 {
        _unknown_code(rec, ptr[u8]("str"));
    }
    if __mem_load_i64(rec + SP_SIGN) != 0 {
        raise ValueError("Sign not allowed in string format specifier");
    }
    if __mem_load_i64(rec + SP_ALIGN) == 61 {
        raise ValueError("'=' alignment not allowed in string format specifier");
    }
    if __mem_load_i64(rec + SP_ALT) == 1 {
        raise ValueError("Alternate form (#) not allowed in string format specifier");
    }
    group = __mem_load_i64(rec + SP_GROUP);
    if group != 0 {
        raise ValueError(
            _message_with(ptr[u8]("Cannot specify '"), group, ptr[u8]("' with 's'."))
        );
    }
    if __mem_load_i64(rec + SP_ZC) == 1 {
        raise ValueError(
            "Negative zero coercion (z) not allowed in string format specifier"
        );
    }
    prec = __mem_load_i64(rec + SP_PREC);
    count = 0;
    at = 0;
    while at < n and (prec < 0 or count < prec) {
        at += __jac_rt_utf8_width(data, n, at);
        count += 1;
    }
    bn = at;
    fill_at = __mem_load_i64(rec + SP_FILL_AT);
    fill_len = __mem_load_i64(rec + SP_FILL_LEN);
    if fill_len == 0 {
        fill_at = int(ptr[u8](" "));
        if __mem_load_i64(rec + SP_ZERO) == 1 {
            fill_at = int(ptr[u8]("0"));
        }
        fill_len = 1;
    }
    align = __mem_load_i64(rec + SP_ALIGN);
    width = __mem_load_i64(rec + SP_WIDTH);
    margin = width - count if width > count else 0;
    left = 0;
    if align == 62 {
        left = margin;
    } elif align == 94 {
        left = margin // 2;
    }
    out = __jac_rt_sb_new(bn + margin * fill_len);
    _emit_fill(out, fill_at, fill_len, left);
    __jac_rt_sb_add(out, data, bn);
    _emit_fill(out, fill_at, fill_len, margin - left);
    return __jac_rt_sb_finish(out);
}

impl __jac_rt_int_text(v: int, base: int) -> ptr[u8] {
    sb = __jac_rt_sb_new(72);
    if v < 0 {
        __jac_rt_sb_byte(sb, 45);
    }
    __jac_rt_sb_byte(sb, 48);
    __jac_rt_sb_byte(sb, 120 if base == 16 else (111 if base == 8 else 98));
    _digits_into(sb, v, base, False);
    return __jac_rt_sb_finish(sb);
}

impl __jac_rt_obj_text(name: ptr[u8], address: int) -> ptr[u8] {
    sb = __jac_rt_sb_new(48);
    __jac_rt_sb_byte(sb, 60);
    _sb_text(sb, name);
    _sb_text(sb, ptr[u8](" object at 0x"));
    _digits_into(sb, address, 16, False);
    __jac_rt_sb_byte(sb, 62);
    return __jac_rt_sb_finish(sb);
}

impl _is_space(c: int) -> bool {
    return c == 32 or (c >= 9 and c <= 13);
}

impl _digit_value(c: int) -> int {
    if c >= 48 and c <= 57 {
        return c - 48;
    }
    if c >= 97 and c <= 122 {
        return c - 87;
    }
    if c >= 65 and c <= 90 {
        return c - 55;
    }
    return 99;
}

impl _bad_literal(text: int, n: int, head: ptr[u8], base: int) -> ptr[u8] {
    sb = __jac_rt_sb_new(n + 48);
    _sb_text(sb, head);
    if base >= 0 {
        __jac_rt_sb_int(sb, base);
        _sb_text(sb, ptr[u8](": "));
    }
    quoted = __jac_rt_str_repr(ptr[u8](text), n);
    __jac_rt_sb_add(sb, quoted, __jac_rt_str_size(quoted));
    __jac_rt_release_acyclic(int(quoted));
    return __jac_rt_sb_finish(sb);
}

impl __jac_rt_int_parse(data: ptr[u8], n: int, base: int) -> int {
    if base != 0 and (base < 2 or base > 36) {
        raise ValueError("int() base must be >= 2 and <= 36, or 0");
    }
    d = int(data);
    i = 0;
    j = n;
    while i < j and _is_space(_byte(d + i)) {
        i += 1;
    }
    while j > i and _is_space(_byte(d + j - 1)) {
        j -= 1;
    }
    neg = False;
    if i < j and (_byte(d + i) == 43 or _byte(d + i) == 45) {
        neg = _byte(d + i) == 45;
        i += 1;
    }
    radix = base;
    prefixed = False;
    if i + 1 < j and _byte(d + i) == 48 {
        mark = _byte(d + i + 1) | 32;
        found = 16 if mark == 120 else (8 if mark == 111 else (2 if mark == 98 else 0));
        if found != 0 and (base == 0 or base == found) {
            radix = found;
            prefixed = True;
            i += 2;
        }
    }
    zero_rule = radix == 0;
    if radix == 0 {
        radix = 10;
    }
    first_digit = i;
    value = 0;
    digits = 0;
    nonzero = False;
    under_ok = prefixed;
    last_under = False;
    while i < j {
        c = _byte(d + i);
        if c == 95 {
            if not under_ok {
                raise ValueError(
                    _bad_literal(d, n, ptr[u8]("invalid literal for int() with base "), base)
                );
            }
            under_ok = False;
            last_under = True;
            i += 1;
            continue;
        }
        digit = _digit_value(c);
        if digit >= radix {
            raise ValueError(
                _bad_literal(d, n, ptr[u8]("invalid literal for int() with base "), base)
            );
        }
        if digit != 0 {
            nonzero = True;
        }
        value = value * radix - digit;
        digits += 1;
        under_ok = True;
        last_under = False;
        i += 1;
    }
    if digits == 0
        or last_under
        or (zero_rule and nonzero and digits > 1 and _byte(d + first_digit) == 48) {
        raise ValueError(
            _bad_literal(d, n, ptr[u8]("invalid literal for int() with base "), base)
        );
    }
    return value if neg else 0 - value;
}

impl _word_at(d: int, i: int, j: int, word: ptr[u8]) -> bool {
    wn = strlen(int(word));
    if j - i != wn {
        return False;
    }
    k = 0;
    while k < wn {
        if (_byte(d + i + k) | 32) != _byte(int(word) + k) {
            return False;
        }
        k += 1;
    }
    return True;
}

impl __jac_rt_float_parse(data: ptr[u8], n: int) -> float {
    d = int(data);
    i = 0;
    j = n;
    while i < j and _is_space(_byte(d + i)) {
        i += 1;
    }
    while j > i and _is_space(_byte(d + j - 1)) {
        j -= 1;
    }
    neg = False;
    k = i;
    if k < j and (_byte(d + k) == 43 or _byte(d + k) == 45) {
        neg = _byte(d + k) == 45;
        k += 1;
    }
    sign = SIGN_BIT if neg else 0;
    if _word_at(d, k, j, ptr[u8]("inf")) or _word_at(d, k, j, ptr[u8]("infinity")) {
        return __bits_float(INF_BITS | sign);
    }
    if _word_at(d, k, j, ptr[u8]("nan")) {
        return __bits_float(NAN_BITS | sign);
    }
    out = malloc(j - i + 2);
    pos = 0;
    if neg {
        __mem_store_i8(out, i8(45));
        pos = 1;
    }
    start = k;
    part = SCAN_INT;
    mantissa = 0;
    exponent = 0;
    ok = k < j;
    while ok and k < j {
        c = _byte(d + k);
        if _is_digit(c) {
            __mem_store_i8(out + pos, i8(c));
            pos += 1;
            if part == SCAN_EXP {
                exponent += 1;
            } else {
                mantissa += 1;
            }
        } elif c == 95 {
            ok = k > start
                and _is_digit(_byte(d + k - 1))
                and k + 1 < j
                and _is_digit(_byte(d + k + 1));
        } elif c == 46 and part == SCAN_INT {
            __mem_store_i8(out + pos, i8(46));
            pos += 1;
            part = SCAN_FRAC;
        } elif (c | 32) == 101 and part != SCAN_EXP and mantissa > 0 {
            __mem_store_i8(out + pos, i8(101));
            pos += 1;
            part = SCAN_EXP;
        } elif (c == 43 or c == 45) and part == SCAN_EXP and (_byte(d + k - 1) | 32) == 101 {
            __mem_store_i8(out + pos, i8(c));
            pos += 1;
        } else {
            ok = False;
        }
        k += 1;
    }
    if not ok or mantissa == 0 or (part == SCAN_EXP and exponent == 0) {
        free(out);
        raise ValueError(
            _bad_literal(d, n, ptr[u8]("could not convert string to float: "), -1)
        );
    }
    __mem_store_i8(out + pos, i8(0));
    value = strtod(out, 0);
    free(out);
    return value;
}

impl __jac_rt_float_round(v: float, ndigits: int) -> float {
    bits = __float_bits(v);
    if ((bits >> 52) & 2047) == 2047 or (bits & ABS_MASK) == 0 or ndigits > 323 {
        return v;
    }
    sign = bits & SIGN_BIT;
    if ndigits < -308 {
        return __bits_float(sign);
    }
    digits = __jac_rt_sb_new(48);
    decpt = _dtoa(__bits_float(bits & ABS_MASK), DTOA_PLACES, ndigits, digits);
    nd = __jac_rt_sb_len(digits);
    if nd == 0 {
        __jac_rt_sb_drop(digits);
        return __bits_float(sign);
    }
    text = __jac_rt_sb_new(nd + 32);
    __jac_rt_sb_byte(text, 48);
    __jac_rt_sb_byte(text, 46);
    __jac_rt_sb_add(text, ptr[u8](__jac_rt_sb_data(digits)), nd);
    __jac_rt_sb_byte(text, 101);
    __jac_rt_sb_int(text, decpt);
    __jac_rt_sb_byte(text, 0);
    rounded = strtod(__jac_rt_sb_data(text), 0);
    __jac_rt_sb_drop(text);
    __jac_rt_sb_drop(digits);
    return __bits_float(__float_bits(rounded) | sign);
}

impl __jac_rt_float_round_int(v: float) -> int {
    bits = __float_bits(v);
    if ((bits >> 52) & 2047) == 2047 {
        if (bits & MANT_MASK) != 0 {
            raise ValueError("cannot convert float NaN to integer");
        }
        raise OverflowError("cannot convert float infinity to integer");
    }
    if v >= 9.223372036854775807e18 or v < -9.223372036854775808e18 {
        raise OverflowError("integer overflow");
    }
    whole = int(v);
    diff = v - float(whole);
    if diff > 0.5 or (diff == 0.5 and (whole & 1) == 1) {
        return whole + 1;
    }
    if diff < -0.5 or (diff == -0.5 and (whole & 1) == 1) {
        return whole - 1;
    }
    return whole;
}

impl __jac_rt_int_round(v: int, ndigits: int) -> int {
    if ndigits >= 0 {
        return v;
    }
    if ndigits <= -19 {
        return 0;
    }
    p = 1;
    k = 0;
    while k < 0 - ndigits {
        p = p * 10;
        k += 1;
    }
    q = v // p;
    twice = (v - q * p) * 2;
    if twice > p or (twice == p and (q & 1) == 1) {
        q += 1;
    }
    return q * p;
}

impl __jac_rt_int_pow(base: int, exp: int) -> int {
    if exp < 0 {
        raise ValueError("negative exponent in integer power");
    }
    result = 1;
    factor = base;
    rest = exp;
    while rest > 0 {
        if (rest & 1) == 1 {
            result = result * factor;
        }
        rest = rest >> 1;
        if rest > 0 {
            factor = factor * factor;
        }
    }
    return result;
}

impl __jac_rt_float_pow(base: float, exp: float) -> float {
    if base == 0.0 and exp < 0.0 {
        raise ZeroDivisionError("0.0 cannot be raised to a negative power");
    }
    return pow(base, exp);
}

impl __jac_rt_int_pow_float(base: int, exp: int) -> float {
    if exp >= 0 {
        return float(__jac_rt_int_pow(base, exp));
    }
    return __jac_rt_float_pow(float(base), float(exp));
}

impl _rotl61(x: int, s: int) -> int {
    if s == 0 {
        return x;
    }
    keep = (1 << (61 - s)) - 1;
    return ((x & keep) << s) | (x >> (61 - s));
}

impl __jac_rt_hash_int(v: int) -> int {
    h = v % HASH_MODULUS if v >= 0 else 0 - ((0 - (v + HASH_MODULUS)) % HASH_MODULUS);
    return -2 if h == -1 else h;
}

impl __jac_rt_hash_float(v: float) -> int {
    bits = __float_bits(v);
    be = (bits >> 52) & 2047;
    if be == 2047 {
        if (bits & MANT_MASK) != 0 {
            return 0;
        }
        return -314159 if bits < 0 else 314159;
    }
    f = bits & MANT_MASK;
    e = -1074;
    if be != 0 {
        f += HIDDEN_BIT;
        e = be - 1075;
    }
    h = _rotl61(f % HASH_MODULUS, e % 61);
    if h >= HASH_MODULUS {
        h -= HASH_MODULUS;
    }
    if bits < 0 {
        h = 0 - h;
    }
    return -2 if h == -1 else h;
}

impl __jac_rt_hash_pointer(address: int) -> int {
    low = address & 15;
    h = ((address >> 4) & LOW60) | (low << 60);
    if low >= 8 {
        h = ((address >> 4) & LOW60) | ((low - 16) << 60);
    }
    return -2 if h == -1 else h;
}

impl _ushr(x: int, n: int) -> int {
    return (x >> n) & (WORD_MAX >> (n - 1));
}

impl _wshl(x: int, n: int) -> int {
    made = (x & ((1 << (63 - n)) - 1)) << n;
    if ((x >> (63 - n)) & 1) == 1 {
        made = made | SIGN_BIT;
    }
    return made;
}

impl _wadd(a: int, b: int) -> int {
    lo = (a & LOW32) + (b & LOW32);
    hi = (_ushr(a, 32) + _ushr(b, 32) + (lo >> 32)) & LOW32;
    if hi >= 2147483648 {
        hi -= 4294967296;
    }
    return (hi << 32) | (lo & LOW32);
}

impl _wmul(a: int, b: int) -> int {
    a0 = a & LOW16;
    a1 = _ushr(a, 16) & LOW16;
    a2 = _ushr(a, 32) & LOW16;
    a3 = _ushr(a, 48) & LOW16;
    b0 = b & LOW16;
    b1 = _ushr(b, 16) & LOW16;
    b2 = _ushr(b, 32) & LOW16;
    b3 = _ushr(b, 48) & LOW16;
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
    return (r3 << 48) | (r2 << 32) | (r1 << 16) | r0;
}

impl __jac_rt_hash_tuple_start -> int {
    return XXPRIME_5;
}

impl __jac_rt_hash_tuple_add(acc: int, lane: int) -> int {
    mixed = _wadd(acc, _wmul(lane, XXPRIME_2));
    rotated = _wshl(mixed, 31) | _ushr(mixed, 33);
    return _wmul(rotated, XXPRIME_1);
}

impl __jac_rt_hash_tuple_end(acc: int, count: int) -> int {
    h = _wadd(acc, count ^ XXPRIME_5_LEN);
    return 1546275796 if h == -1 else h;
}
