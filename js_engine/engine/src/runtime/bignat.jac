"""Shared BigNat — base-10^9 limb arbitrary precision (Temporal Instant epoch ns)."""

glob BN_SIGN_IDX: int = 0,
     BN_LIMB_START: int = 1,
     BN_BASE: int = 1000000000;

def:pub bn_zero -> list[int] {
    return [0, 0];
}

def:priv _bn_limbs(a: list[int]) -> list[int] {
    out: list[int] = [];
    i: int = BN_LIMB_START;
    while i < len(a) {
        out.append(a[i]);
        i = i + 1;
    }
    if len(out) == 0 {
        out.append(0);
    }
    return out;
}

def:priv _bn_pack(sign: int, limbs: list[int]) -> list[int] {
    out: list[int] = [sign];
    i: int = 0;
    while i < len(limbs) {
        out.append(limbs[i]);
        i = i + 1;
    }
    return out;
}

def:priv _bn_trim_limbs(limbs: list[int]) -> list[int] {
    out: list[int] = [];
    i: int = 0;
    while i < len(limbs) {
        out.append(limbs[i]);
        i = i + 1;
    }
    while len(out) > 1 and out[len(out) - 1] == 0 {
        out.pop();
    }
    if len(out) == 0 {
        out.append(0);
    }
    return out;
}

def:priv _bn_pad9(n: int) -> str {
    s: str = str(n);
    while len(s) < 9 {
        s = "0" + s;
    }
    return s;
}

def:priv _bn_from_digit_str(digits: str) -> list[int] {
    if len(digits) == 0 {
        return [0];
    }
    while len(digits) > 1 and digits[0:1] == "0" {
        digits = digits[1:len(digits)];
    }
    limbs: list[int] = [];
    pos: int = len(digits);
    while pos > 0 {
        start: int = pos - 9;
        if start < 0 {
            start = 0;
        }
        limbs.append(int(digits[start:pos]));
        pos = start;
    }
    return _bn_trim_limbs(limbs);
}

def:priv _bn_add_limbs(a: list[int], b: list[int]) -> list[int] {
    n: int = len(a);
    if len(b) > n {
        n = len(b);
    }
    carry: int = 0;
    out: list[int] = [];
    i: int = 0;
    while i < n {
        s: int = carry;
        if i < len(a) {
            s = s + a[i];
        }
        if i < len(b) {
            s = s + b[i];
        }
        out.append(s % BN_BASE);
        carry = s // BN_BASE;
        i = i + 1;
    }
    if carry > 0 {
        out.append(carry);
    }
    return _bn_trim_limbs(out);
}

def:priv _bn_sub_limbs(a: list[int], b: list[int]) -> list[int] {
    borrow: int = 0;
    out: list[int] = [];
    i: int = 0;
    while i < len(a) {
        bi: int = 0;
        if i < len(b) {
            bi = b[i];
        }
        d: int = a[i] - borrow - bi;
        if d < 0 {
            d = d + BN_BASE;
            borrow = 1;
        } else {
            borrow = 0;
        }
        out.append(d);
        i = i + 1;
    }
    return _bn_trim_limbs(out);
}

def:priv _bn_cmp_limbs(a: list[int], b: list[int]) -> int {
    aa: list[int] = _bn_trim_limbs(a);
    bb: list[int] = _bn_trim_limbs(b);
    if len(aa) != len(bb) {
        if len(aa) > len(bb) {
            return 1;
        }
        return -1;
    }
    i: int = len(aa) - 1;
    while i >= 0 {
        if aa[i] != bb[i] {
            if aa[i] > bb[i] {
                return 1;
            }
            return -1;
        }
        i = i - 1;
    }
    return 0;
}

def:pub bn_from_int(n: int) -> list[int] {
    if n == 0 {
        return bn_zero();
    }
    neg: int = 0;
    v: int = n;
    if n < 0 {
        neg = 1;
        v = -n;
    }
    return _bn_pack(neg, _bn_from_digit_str(str(v)));
}

def:pub bn_parse_decimal(s: str) -> list[int] {
    if len(s) == 0 {
        return bn_zero();
    }
    i: int = 0;
    sign: int = 0;
    if s[0:1] == "-" {
        sign = 1;
        i = 1;
    } elif s[0:1] == "+" {
        i = 1;
    }
    digits: str = "";
    while i < len(s) {
        ch: str = s[i:i + 1];
        if ch >= "0" and ch <= "9" {
            digits = digits + ch;
        } else {
            break;
        }
        i = i + 1;
    }
    return _bn_pack(sign, _bn_from_digit_str(digits));
}

def:priv _bn_digit_char(d: int) -> str {
    if d < 10 {
        return str(d);
    }
    # 10 → 'a', 11 → 'b', …
    return chr(ord("a") + (d - 10));
}

def:pub bn_to_string(a: list[int], radix: int) -> str {
    if radix < 2 or radix > 36 {
        return "0";
    }
    limbs: list[int] = _bn_trim_limbs(_bn_limbs(a));
    if len(limbs) == 1 and limbs[0] == 0 {
        return "0";
    }
    sign: str = "";
    if a[BN_SIGN_IDX] != 0 {
        sign = "-";
    }
    if radix == 10 {
        s10: str = str(limbs[len(limbs) - 1]);
        li10: int = len(limbs) - 2;
        while li10 >= 0 {
            s10 = s10 + _bn_pad9(limbs[li10]);
            li10 = li10 - 1;
        }
        return sign + s10;
    }
    # General radix 2–36: repeated division by radix.
    # Work on a positive magnitude copy packed as BigNat limbs.
    mag: list[int] = _bn_pack(0, limbs);
    digits: str = "";
    guard: int = 0;
    while (not bn_is_zero(mag)) and guard < 1000000 {
        q: list[int] = bn_divmod(mag, bn_from_int(radix));
        rem: list[int] = _BN_DIV_REM;
        rd: int = 0;
        rem_limbs: list[int] = _bn_trim_limbs(_bn_limbs(rem));
        if len(rem_limbs) > 0 {
            rd = rem_limbs[0];
        }
        digits = _bn_digit_char(rd) + digits;
        mag = q;
        guard = guard + 1;
    }
    if len(digits) == 0 {
        digits = "0";
    }
    return sign + digits;
}

def:pub bn_add(a: list[int], b: list[int]) -> list[int] {
    aa: list[int] = _bn_limbs(a);
    bb: list[int] = _bn_limbs(b);
    sa: int = a[BN_SIGN_IDX];
    sb: int = b[BN_SIGN_IDX];
    if sa == sb {
        return _bn_pack(sa, _bn_add_limbs(aa, bb));
    }
    if _bn_cmp_limbs(aa, bb) >= 0 {
        return _bn_pack(sa, _bn_sub_limbs(aa, bb));
    }
    return _bn_pack(sb, _bn_sub_limbs(bb, aa));
}

def:pub bn_sub(a: list[int], b: list[int]) -> list[int] {
    nb: list[int] = _bn_pack(1 - b[BN_SIGN_IDX], _bn_limbs(b));
    return bn_add(a, nb);
}

def:pub bn_cmp(a: list[int], b: list[int]) -> int {
    if a[BN_SIGN_IDX] != b[BN_SIGN_IDX] {
        if a[BN_SIGN_IDX] != 0 {
            return -1;
        }
        return 1;
    }
    c: int = _bn_cmp_limbs(_bn_limbs(a), _bn_limbs(b));
    if a[BN_SIGN_IDX] != 0 {
        return -c;
    }
    return c;
}

def:pub bn_sign(a: list[int]) -> int {
    if bn_is_zero(a) {
        return 0;
    }
    if a[BN_SIGN_IDX] != 0 {
        return -1;
    }
    return 1;
}

def:pub bn_is_zero(a: list[int]) -> bool {
    limbs: list[int] = _bn_limbs(a);
    return len(limbs) == 1 and limbs[0] == 0;
}

def:pub bn_mul(a: list[int], b: list[int]) -> list[int] {
    if bn_is_zero(a) or bn_is_zero(b) {
        return bn_zero();
    }
    aa: list[int] = _bn_limbs(a);
    bb: list[int] = _bn_limbs(b);
    out_len: int = len(aa) + len(bb);
    out: list[int] = [];
    i: int = 0;
    while i < out_len {
        out.append(0);
        i = i + 1;
    }
    i = 0;
    while i < len(aa) {
        carry: int = 0;
        j: int = 0;
        while j < len(bb) {
            idx: int = i + j;
            prod: int = aa[i] * bb[j] + out[idx] + carry;
            out[idx] = prod % BN_BASE;
            carry = prod // BN_BASE;
            j = j + 1;
        }
        k: int = i + len(bb);
        while carry > 0 {
            if k >= len(out) {
                out.append(0);
            }
            nxt: int = out[k] + carry;
            out[k] = nxt % BN_BASE;
            carry = nxt // BN_BASE;
            k = k + 1;
        }
        i = i + 1;
    }
    sign: int = a[BN_SIGN_IDX];
    if b[BN_SIGN_IDX] != 0 {
        if sign == 0 {
            sign = 1;
        } else {
            sign = 0;
        }
    }
    return _bn_pack(sign, _bn_trim_limbs(out));
}

def:pub bn_mul_small(a: list[int], m: int) -> list[int] {
    if m == 0 or bn_is_zero(a) {
        return bn_zero();
    }
    ms: int = m;
    sign: int = a[BN_SIGN_IDX];
    if ms < 0 {
        if sign == 0 {
            sign = 1;
        } else {
            sign = 0;
        }
        ms = -ms;
    }
    limbs: list[int] = _bn_limbs(a);
    carry: int = 0;
    out: list[int] = [];
    i: int = 0;
    while i < len(limbs) {
        p: int = limbs[i] * ms + carry;
        out.append(p % BN_BASE);
        carry = p // BN_BASE;
        i = i + 1;
    }
    if carry > 0 {
        out.append(carry);
    }
    return _bn_pack(sign, _bn_trim_limbs(out));
}

glob:pub _BN_DIV_REM: list[int] = [0, 0];

def:priv _bn_divisor_as_int(b: list[int]) -> int {
    if len(b) <= BN_LIMB_START {
        return 0;
    }
    limbs: list[int] = _bn_limbs(b);
    if len(limbs) == 0 {
        return 0;
    }
    if len(limbs) == 1 {
        return limbs[0];
    }
    if len(limbs) == 2 {
        return limbs[0] + limbs[1] * BN_BASE;
    }
    bs: str = bn_to_string(b, 10);
    if len(bs) > 0 and bs[0:1] == "-" {
        bs = bs[1:len(bs)];
    }
    if len(bs) == 0 {
        return 0;
    }
    return int(bs);
}

def:pub bn_divmod(a: list[int], b: list[int]) -> list[int] {
    vb: int = _bn_divisor_as_int(b);
    if vb > 0 {
        sa: str = bn_to_string(a, 10);
        neg: bool = False;
        pos: int = 0;
        if len(sa) > 0 and sa[0:1] == "-" {
            neg = True;
            pos = 1;
        }
        rem: int = 0;
        qdigits: str = "";
        while pos < len(sa) {
            rem = rem * 10 + int(sa[pos:pos + 1]);
            qdigits = qdigits + str(rem // vb);
            rem = rem % vb;
            pos = pos + 1;
        }
        while len(qdigits) > 1 and qdigits[0:1] == "0" {
            qdigits = qdigits[1:len(qdigits)];
        }
        if neg and qdigits != "0" {
            qdigits = "-" + qdigits;
        }
        _BN_DIV_REM = bn_from_int(rem);
        return bn_parse_decimal(qdigits);
    }
    return bn_zero();
}

def:pub bn_neg(a: list[int]) -> list[int] {
    if bn_is_zero(a) {
        return bn_zero();
    }
    ns: int = 1;
    if a[BN_SIGN_IDX] != 0 {
        ns = 0;
    }
    return _bn_pack(ns, _bn_limbs(a));
}
