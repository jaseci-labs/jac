glob MAG_SHIFT: int = 30,
     MAG_BASE: int = 1073741824,
     MAG_MASK: int = 1073741823,
     MAX_STR_DIGITS: int = 4300;

def mag_norm(m: list[int]) -> list[int] {
    while m and m[-1] == 0 {
        m.pop();
    }
    return m;
}

def mag_from_int(v: int) -> list[int] {
    out: list[int] = [];
    while v > 0 {
        out.append(v & MAG_MASK);
        v = v >> MAG_SHIFT;
    }
    return out;
}

def mag_to_int(m: list[int]) -> int {
    out = 0;
    i = len(m) - 1;
    while i >= 0 {
        out = (out << MAG_SHIFT) | m[i];
        i -= 1;
    }
    return out;
}

def mag_is_zero(m: list[int]) -> bool {
    return len(m) == 0;
}

def mag_cmp(a: list[int], b: list[int]) -> int {
    if len(a) != len(b) {
        return 1 if len(a) > len(b) else -1;
    }
    i = len(a) - 1;
    while i >= 0 {
        if a[i] != b[i] {
            return 1 if a[i] > b[i] else -1;
        }
        i -= 1;
    }
    return 0;
}

def mag_add(a: list[int], b: list[int]) -> list[int] {
    if len(a) < len(b) {
        (a, b) = (b, a);
    }
    out: list[int] = [];
    carry = 0;
    for i in range(len(a)) {
        t = a[i] + carry;
        if i < len(b) {
            t += b[i];
        }
        out.append(t & MAG_MASK);
        carry = t >> MAG_SHIFT;
    }
    if carry {
        out.append(carry);
    }
    return out;
}

def mag_sub(a: list[int], b: list[int]) -> list[int] {
    out: list[int] = [];
    borrow = 0;
    for i in range(len(a)) {
        t = a[i] - borrow;
        if i < len(b) {
            t -= b[i];
        }
        if t < 0 {
            t += MAG_BASE;
            borrow = 1;
        } else {
            borrow = 0;
        }
        out.append(t);
    }
    return mag_norm(out);
}

def mag_mul(a: list[int], b: list[int]) -> list[int] {
    if not a or not b {
        return [];
    }
    out: list[int] = [0] * (len(a) + len(b));
    for i in range(len(a)) {
        ai = a[i];
        if ai == 0 {
            continue;
        }
        carry = 0;
        for j in range(len(b)) {
            t = out[i + j] + ai * b[j] + carry;
            out[i + j] = t & MAG_MASK;
            carry = t >> MAG_SHIFT;
        }
        k = i + len(b);
        while carry {
            t = out[k] + carry;
            out[k] = t & MAG_MASK;
            carry = t >> MAG_SHIFT;
            k += 1;
        }
    }
    return mag_norm(out);
}

def mag_mul_small(a: list[int], s: int) -> list[int] {
    out: list[int] = [];
    carry = 0;
    for limb in a {
        t = limb * s + carry;
        out.append(t & MAG_MASK);
        carry = t >> MAG_SHIFT;
    }
    while carry {
        out.append(carry & MAG_MASK);
        carry = carry >> MAG_SHIFT;
    }
    return mag_norm(out);
}

def mag_add_small(a: list[int], s: int) -> list[int] {
    out: list[int] = a.copy();
    carry = s;
    i = 0;
    while carry {
        if i == len(out) {
            out.append(0);
        }
        t = out[i] + carry;
        out[i] = t & MAG_MASK;
        carry = t >> MAG_SHIFT;
        i += 1;
    }
    return out;
}

def mag_divmod_small(a: list[int], d: int) -> tuple[list[int], int] {
    q: list[int] = [0] * len(a);
    rem = 0;
    i = len(a) - 1;
    while i >= 0 {
        cur = (rem << MAG_SHIFT) | a[i];
        q[i] = cur // d;
        rem = cur % d;
        i -= 1;
    }
    return (mag_norm(q), rem);
}

def mag_bit_length(a: list[int]) -> int {
    if not a {
        return 0;
    }
    top = a[-1];
    bits = 0;
    while top {
        bits += 1;
        top = top >> 1;
    }
    return (len(a) - 1) * MAG_SHIFT + bits;
}

def mag_shl(a: list[int], bits: int) -> list[int] {
    if not a {
        return [];
    }
    limbs = bits // MAG_SHIFT;
    rem = bits % MAG_SHIFT;
    out: list[int] = [0] * limbs;
    if rem == 0 {
        out.extend(a);
        return out;
    }
    carry = 0;
    for limb in a {
        t = (limb << rem) | carry;
        out.append(t & MAG_MASK);
        carry = t >> MAG_SHIFT;
    }
    if carry {
        out.append(carry);
    }
    return out;
}

def mag_shr(a: list[int], bits: int) -> list[int] {
    limbs = bits // MAG_SHIFT;
    rem = bits % MAG_SHIFT;
    if limbs >= len(a) {
        return [];
    }
    src = a[limbs:];
    if rem == 0 {
        return src;
    }
    out: list[int] = [];
    for i in range(len(src)) {
        hi = src[i + 1] if i + 1 < len(src) else 0;
        out.append(((src[i] >> rem) | (hi << (MAG_SHIFT - rem))) & MAG_MASK);
    }
    return mag_norm(out);
}

def mag_low_bits_nonzero(a: list[int], bits: int) -> bool {
    limbs = bits // MAG_SHIFT;
    rem = bits % MAG_SHIFT;
    for i in range(min(limbs, len(a))) {
        if a[i] != 0 {
            return True;
        }
    }
    if rem and limbs < len(a) {
        return (a[limbs] & ((1 << rem) - 1)) != 0;
    }
    return False;
}

def mag_divmod(a: list[int], b: list[int]) -> tuple[list[int], list[int]] {
    if mag_cmp(a, b) < 0 {
        return ([], a.copy());
    }
    if len(b) == 1 {
        (q, r) = mag_divmod_small(a, b[0]);
        return (q, mag_from_int(r));
    }
    s = MAG_SHIFT - (mag_bit_length(b) - (len(b) - 1) * MAG_SHIFT);
    v = mag_shl(b, s);
    u = mag_shl(a, s);
    if len(u) == len(a) {
        u.append(0);
    }
    n = len(v);
    m = len(u) - n;
    q: list[int] = [0] * m;
    vtop = v[n - 1];
    vnext = v[n - 2];
    j = m - 1;
    while j >= 0 {
        num = (u[j + n] << MAG_SHIFT) | u[j + n - 1];
        qhat = num // vtop;
        rhat = num % vtop;
        while qhat >= MAG_BASE or qhat * vnext > ((rhat << MAG_SHIFT) | u[j + n - 2]) {
            qhat -= 1;
            rhat += vtop;
            if rhat >= MAG_BASE {
                break;
            }
        }
        borrow = 0;
        carry = 0;
        for i in range(n) {
            p = qhat * v[i] + carry;
            carry = p >> MAG_SHIFT;
            t = u[i + j] - (p & MAG_MASK) - borrow;
            if t < 0 {
                t += MAG_BASE;
                borrow = 1;
            } else {
                borrow = 0;
            }
            u[i + j] = t;
        }
        t = u[j + n] - carry - borrow;
        if t < 0 {
            u[j + n] = t + MAG_BASE;
            qhat -= 1;
            c = 0;
            for i in range(n) {
                t2 = u[i + j] + v[i] + c;
                u[i + j] = t2 & MAG_MASK;
                c = t2 >> MAG_SHIFT;
            }
            u[j + n] = (u[j + n] + c) & MAG_MASK;
        } else {
            u[j + n] = t;
        }
        q[j] = qhat;
        j -= 1;
    }
    rem = mag_shr(mag_norm(u[:n]), s);
    return (mag_norm(q), rem);
}

def mag_decimal_digits(a: list[int]) -> str {
    if not a {
        return "0";
    }
    chunks: list[int] = [];
    cur = a.copy();
    while cur {
        (cur, r) = mag_divmod_small(cur, 1000000000);
        chunks.append(r);
    }
    out = str(chunks[-1]);
    i = len(chunks) - 2;
    while i >= 0 {
        out += str(chunks[i]).rjust(9, "0");
        i -= 1;
    }
    return out;
}

def mag_to_pow2_str(a: list[int], bits_per_digit: int) -> str {
    if not a {
        return "0";
    }
    digits = "0123456789abcdef";
    mask = (1 << bits_per_digit) - 1;
    total = mag_bit_length(a);
    out: list[str] = [];
    pos = 0;
    while pos < total {
        limb = pos // MAG_SHIFT;
        off = pos % MAG_SHIFT;
        chunk = a[limb] >> off;
        if off + bits_per_digit > MAG_SHIFT and limb + 1 < len(a) {
            chunk = chunk | (a[limb + 1] << (MAG_SHIFT - off));
        }
        out.append(digits[chunk & mask]);
        pos += bits_per_digit;
    }
    out.reverse();
    return "".join(out);
}

def mag_parse_digits(text: str, base: int) -> (list[int] | None) {
    out: list[int] = [];
    for ch in text {
        d = digit_value(ch);
        if d < 0 or d >= base {
            return None;
        }
        out = mag_add_small(mag_mul_small(out, base), d);
    }
    return mag_norm(out);
}

def digit_value(ch: str) -> int {
    o = ord(ch);
    if 48 <= o <= 57 {
        return o - 48;
    }
    if 97 <= o <= 122 {
        return o - 87;
    }
    if 65 <= o <= 90 {
        return o - 55;
    }
    return -1;
}

def mag_pow2(bits: int) -> list[int] {
    return mag_shl([1], bits);
}

def mag_isqrt(n: list[int]) -> list[int] {
    if not n {
        return [];
    }
    x = mag_shl([1], (mag_bit_length(n) + 1) // 2 + 1);
    while True {
        (q, _) = mag_divmod(n, x);
        y = mag_shr(mag_add(x, q), 1);
        if mag_cmp(y, x) >= 0 {
            return x;
        }
        x = y;
    }
    return x;
}

def mag_gcd(a: list[int], b: list[int]) -> list[int] {
    x = a.copy();
    y = b.copy();
    while y {
        (_, r) = mag_divmod(x, y);
        x = y;
        y = r;
    }
    return x;
}

def twos_limbs(neg: bool, mag: list[int], width: int) -> list[int] {
    out: list[int] = mag.copy();
    while len(out) < width {
        out.append(0);
    }
    if not neg {
        return out;
    }
    carry = 1;
    for i in range(width) {
        t = (out[i] ^ MAG_MASK) + carry;
        out[i] = t & MAG_MASK;
        carry = t >> MAG_SHIFT;
    }
    return out;
}

def twos_to_signed(limbs: list[int], neg: bool) -> tuple[bool, list[int]] {
    if not neg {
        return (False, mag_norm(limbs.copy()));
    }
    out: list[int] = [];
    carry = 1;
    for limb in limbs {
        t = (limb ^ MAG_MASK) + carry;
        out.append(t & MAG_MASK);
        carry = t >> MAG_SHIFT;
    }
    return (True, mag_norm(out));
}
