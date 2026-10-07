"""
runtime/dtoa.na.jac — Exact double-to-decimal conversion (Dragon4 / BigNat).

Shared engine for ECMAScript Number::toString (radix 10), ToString on Number
values, and Number.prototype formatting helpers. Uses Steele & White Dragon4
with arbitrary-precision base-10^9 limbs — no floating-point digit generation.
"""

import from engine.src.runtime.jsvalue { __float_bits }
import from engine.src.runtime.jsstring { str_substr, str_char_at }

glob BIGNAT_BASE: int = 1000000000,
     DTOA_P: int = 54,
     DTOA_MAX_SAFE: float = 9007199254740991.0,
     DTOA_MAX_FINITE: float = 1.7976931348623157e+308;

def _bn_from_int(n: int) -> list[int] {
    if n == 0 {
        return [0];
    }
    neg: bool = n < 0;
    v: int = n;
    if neg {
        v = -v;
    }
    out: list[int] = [];
    while v > 0 {
        out.append(v % BIGNAT_BASE);
        v = v // BIGNAT_BASE;
    }
    return out;
}

def _bn_is_zero(a: list[int]) -> bool {
    return len(a) == 1 and a[0] == 0;
}

"""Drop high zero limbs in place (the value is unchanged, so trimming a
list another bignum shares is harmless) and return it."""
def _bn_trim(a: list[int]) -> list[int] {
    while len(a) > 1 and a[len(a) - 1] == 0 {
        a.pop();
    }
    if len(a) == 0 {
        a.append(0);
    }
    return a;
}

"""Limb count of `a` without its high zero limbs (at least 1)."""
def _bn_len(a: list[int]) -> int {
    n: int = len(a);
    while n > 1 and a[n - 1] == 0 {
        n = n - 1;
    }
    if n == 0 {
        return 1;
    }
    return n;
}

def _bn_cmp(a: list[int], b: list[int]) -> int {
    na: int = _bn_len(a);
    nb: int = _bn_len(b);
    if na != nb {
        if na > nb {
            return 1;
        }
        return -1;
    }
    i: int = na - 1;
    while i >= 0 {
        ai: int = 0;
        if i < len(a) {
            ai = a[i];
        }
        bi: int = 0;
        if i < len(b) {
            bi = b[i];
        }
        if ai != bi {
            if ai > bi {
                return 1;
            }
            return -1;
        }
        i = i - 1;
    }
    return 0;
}

def _bn_add(a: list[int], b: list[int]) -> list[int] {
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
        out.append(s % BIGNAT_BASE);
        carry = s // BIGNAT_BASE;
        i = i + 1;
    }
    if carry > 0 {
        out.append(carry);
    }
    return _bn_trim(out);
}

def _bn_sub(a: list[int], b: list[int]) -> list[int] {
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
            d = d + BIGNAT_BASE;
            borrow = 1;
        } else {
            borrow = 0;
        }
        out.append(d);
        i = i + 1;
    }
    return _bn_trim(out);
}

def _bn_mul_small(a: list[int], m: int) -> list[int] {
    carry: int = 0;
    out: list[int] = [];
    i: int = 0;
    while i < len(a) {
        p: int = a[i] * m + carry;
        out.append(p % BIGNAT_BASE);
        carry = p // BIGNAT_BASE;
        i = i + 1;
    }
    if carry > 0 {
        out.append(carry);
    }
    return _bn_trim(out);
}

def _bn_mul_pow2(a: list[int], k: int) -> list[int] {
    # 29 bits per step: limb * 2^29 + carry stays below 2^63.
    out: list[int] = a;
    kk: int = k;
    while kk >= 29 {
        out = _bn_mul_small(out, 536870912);
        kk = kk - 29;
    }
    if kk > 0 {
        out = _bn_mul_small(out, 1 << kk);
    }
    return out;
}

def _bn_shl_small(a: list[int], bits: int) -> list[int] {
    if bits <= 0 {
        return a;
    }
    return _bn_mul_pow2(a, bits);
}

glob _DTOA_DIV_REM: list[int] = [0],
     _DTOA_W_R: list[int] = [0],
     _DTOA_W_S: list[int] = [1],
     _DTOA_W_MP: list[int] = [1],
     _DTOA_W_MM: list[int] = [1],
     _DTOA_W_K: int = 0;

def _bn_quorem10(a: list[int], b: list[int]) -> int {
    prod: list[int] = _bn_mul_small(a, 10);
    return _bn_divmod_small_quot(prod, b);
}

def _bn_divmod_small_quot(a: list[int], b: list[int]) -> int {
    if _bn_cmp(a, b) < 0 {
        _DTOA_DIV_REM = a;
        return 0;
    }
    # The quotient is a digit (0..9): subtract b until the rest is below it.
    q: int = 0;
    rem: list[int] = a;
    while q < 9 and _bn_cmp(rem, b) >= 0 {
        rem = _bn_sub(rem, b);
        q = q + 1;
    }
    _DTOA_DIV_REM = rem;
    return q;
}

def _bn_mul_round_half_up(a: list[int], b: list[int]) -> int {
    if _bn_is_zero(b) {
        return 0;
    }
    rem: list[int] = a;
    q: int = 0;
    while _bn_cmp(rem, b) >= 0 {
        lo: int = 1;
        hi: int = BIGNAT_BASE;
        best: int = 1;
        while lo <= hi {
            mid: int = (lo + hi) // 2;
            prod: list[int] = _bn_mul_small(b, mid);
            if _bn_cmp(prod, rem) <= 0 {
                best = mid;
                lo = mid + 1;
            } else {
                hi = mid - 1;
            }
        }
        rem = _bn_sub(rem, _bn_mul_small(b, best));
        q = q + best;
    }
    twice_r: list[int] = _bn_add(rem, rem);
    if _bn_cmp(twice_r, b) >= 0 {
        q = q + 1;
    }
    return q;
}

def _double_to_mantissa_exp(v: float) -> list[int] {
    bits: int = __float_bits(v);
    if bits < 0 {
        bits = bits & 0x7FFF_FFFF_FFFF_FFFF;
    }
    mant_raw: int = bits & 0x000F_FFFF_FFFF_FFFF;
    exp_field: int = (bits >> 52) & 0x7FF;
    if exp_field == 0 {
        if mant_raw == 0 {
            return [0, 0, 0];
        }
        # Subnormal: its real precision (ulp 2^-1074), not a normalized
        # mantissa (whose smaller ulp made the shortest search emit 16 digits).
        return [mant_raw, -1074, 0];
    }
    if exp_field == 0x7FF {
        return [mant_raw, 0, 0];
    }
    # A power of two has half the gap below it — except the smallest normal,
    # whose lower neighbour is the largest subnormal at the same spacing.
    is_bnd: int = 0;
    if mant_raw == 0 and exp_field > 1 {
        is_bnd = 1;
    }
    return [mant_raw | (1 << 52), exp_field - 1023 - 52, is_bnd];
}

def _dtoa_setup_rs(f: int, e: int, p: int) {
    ep: int = e - p;
    R: list[int] = _bn_from_int(f);
    S: list[int] = [1];
    if ep > 0 {
        R = _bn_shl_small(R, ep);
    } elif ep < 0 {
        S = _bn_shl_small(S, -ep);
    }
    Mp: list[int] = [1];
    Mm: list[int] = [1];
    if ep > 0 {
        Mp = _bn_shl_small(Mp, ep);
        Mm = Mp;
    }
    if f == (1 << (p - 1)) {
        Mp = _bn_shl_small(Mp, 1);
        R = _bn_shl_small(R, 1);
        S = _bn_shl_small(S, 1);
    }
    _DTOA_W_R = R;
    _DTOA_W_S = S;
    _DTOA_W_MP = Mp;
    _DTOA_W_MM = Mm;
}

def _dtoa_find_k_shortest {
    k: int = 0;
    B: int = 10;
    R: list[int] = _DTOA_W_R;
    S: list[int] = _DTOA_W_S;
    Mp: list[int] = _DTOA_W_MP;
    Mm: list[int] = _DTOA_W_MM;
    nine: list[int] = [9];
    tenR: list[int] = _bn_mul_small(R, B);
    spl: list[int] = _bn_add(S, nine);
    while _bn_cmp(tenR, spl) < 0 {
        k = k - 1;
        R = _bn_mul_small(R, B);
        Mp = _bn_mul_small(Mp, B);
        Mm = _bn_mul_small(Mm, B);
        tenR = _bn_mul_small(R, B);
        spl = _bn_add(S, nine);
    }
    twoR: list[int] = _bn_add(R, R);
    twoR = _bn_add(twoR, Mp);
    while True {
        twoS: list[int] = _bn_add(S, S);
        if _bn_cmp(twoR, twoS) < 0 {
            break;
        }
        k = k + 1;
        S = _bn_mul_small(S, B);
    }
    _DTOA_W_K = k;
    _DTOA_W_R = R;
    _DTOA_W_S = S;
    _DTOA_W_MP = Mp;
    _DTOA_W_MM = Mm;
}

def _dtoa_setup_fixed_rs(f: int, e: int, p: int) {
    ep: int = e - p;
    R: list[int] = _bn_from_int(f);
    S: list[int] = [1];
    if ep > 0 {
        R = _bn_shl_small(R, ep);
    } elif ep < 0 {
        S = _bn_shl_small(S, -ep);
    }
    _DTOA_W_R = R;
    _DTOA_W_S = S;
}

def _dtoa_find_k_fixed(exp_align: bool) {
    k: int = 0;
    B: int = 10;
    R: list[int] = _DTOA_W_R;
    S: list[int] = _DTOA_W_S;
    nine: list[int] = [9];
    tenR: list[int] = _bn_mul_small(R, B);
    spl: list[int] = _bn_add(S, nine);
    while _bn_cmp(tenR, spl) < 0 {
        k = k - 1;
        R = _bn_mul_small(R, B);
        tenR = _bn_mul_small(R, B);
        spl = _bn_add(S, nine);
    }
    twoR: list[int] = _bn_add(R, R);
    while True {
        if exp_align {
            twoS: list[int] = _bn_add(S, S);
            if _bn_cmp(twoR, twoS) < 0 {
                break;
            }
        } else {
            if _bn_cmp(twoR, S) < 0 {
                break;
            }
        }
        k = k + 1;
        S = _bn_mul_small(S, B);
    }
    _DTOA_W_K = k;
    _DTOA_W_R = R;
    _DTOA_W_S = S;
}

def _trim_trailing_zeros(digits: str) -> str {
    while len(digits) > 1 and str_char_at(digits, len(digits) - 1) == "0" {
        digits = str_substr(digits, 0, len(digits) - 1);
    }
    return digits;
}

def _format_digits_k(digits: str, k: int) -> str {
    if len(digits) == 0 {
        return "0";
    }
    # ES Number::toString radix-10 uses exponential form when the decimal expansion
    # would need more than six leading fractional zeros (|x| < 1e-6) or |x| >= 1e21.
    if k < -6 {
        if len(digits) == 1 {
            return digits + "e" + str(k);
        }
        return str_substr(digits, 0, 1)
            + "."
            + str_substr(digits, 1, len(digits))
            + "e"
            + str(k);
    }
    if k >= 21 {
        if len(digits) == 1 {
            return digits + "e+" + str(k);
        }
        return str_substr(digits, 0, 1)
            + "."
            + str_substr(digits, 1, len(digits))
            + "e+"
            + str(k);
    }
    if k >= 0 {
        if k + 1 >= len(digits) {
            pad: int = k + 1 - len(digits);
            i: int = 0;
            while i < pad {
                digits = digits + "0";
                i = i + 1;
            }
        }
        if k == len(digits) - 1 {
            return digits;
        }
        return str_substr(digits, 0, k + 1)
            + "."
            + str_substr(digits, k + 1, len(digits));
    }
    zeros: str = "";
    zc: int = -k - 1;
    zi: int = 0;
    while zi < zc {
        zeros = zeros + "0";
        zi = zi + 1;
    }
    return "0." + zeros + digits;
}

def _inc_digit_str(s: str) -> str {
    carry: int = 1;
    out: str = "";
    i: int = len(s) - 1;
    while i >= 0 {
        d: int = int(str_char_at(s, i)) - int(str_char_at("0", 0)) + carry;
        carry = 0;
        if d >= 10 {
            d = d - 10;
            carry = 1;
        }
        out = str(d) + out;
        i = i - 1;
    }
    if carry == 1 {
        out = "1" + out;
    }
    return out;
}

glob:pub _DTOA_OUT_DIGITS: str = "",
     _DTOA_OUT_K: int = 0;

# ── In-place limb arithmetic for the shortest-digit loop (V4.6b) ─────────────
# Base-1e9 little-endian limb lists owned by this module and only ever
# mutated (a glob rebound inside a function would become a local).
glob _DQ_R: list[int] = [],
     _DQ_S: list[int] = [],
     _DQ_MP: list[int] = [],
     _DQ_MM: list[int] = [],
     _DQ_2S: list[int] = [],
     _DQ_T1: list[int] = [],
     _DQ_T2: list[int] = [];

"""dst = the small non-negative int v."""
def _dq_set_int(dst: list[int], v: int) -> None {
    while len(dst) > 0 {
        dst.pop();
    }
    if v == 0 {
        dst.append(0);
        return;
    }
    x: int = v;
    while x > 0 {
        dst.append(x % BIGNAT_BASE);
        x = x // BIGNAT_BASE;
    }
}

"""dst = a copy of src's limbs."""
def _dq_copy(dst: list[int], src: list[int]) {
    while len(dst) > 0 {
        dst.pop();
    }
    i: int = 0;
    while i < len(src) {
        dst.append(src[i]);
        i = i + 1;
    }
}

"""a *= m in place (0 < m < 2^31)."""
def _dq_mul(a: list[int], m: int) {
    carry: int = 0;
    i: int = 0;
    n: int = len(a);
    while i < n {
        p: int = a[i] * m + carry;
        a[i] = p % BIGNAT_BASE;
        carry = p // BIGNAT_BASE;
        i = i + 1;
    }
    while carry > 0 {
        a.append(carry % BIGNAT_BASE);
        carry = carry // BIGNAT_BASE;
    }
}

"""a *= 2^k in place."""
def _dq_shl(a: list[int], k: int) {
    kk: int = k;
    while kk >= 29 {
        _dq_mul(a, 536870912);
        kk = kk - 29;
    }
    if kk > 0 {
        _dq_mul(a, 1 << kk);
    }
}

"""dst = a + b (dst is neither a nor b)."""
def _dq_add_into(dst: list[int], a: list[int], b: list[int]) {
    while len(dst) > 0 {
        dst.pop();
    }
    n: int = len(a);
    if len(b) > n {
        n = len(b);
    }
    carry: int = 0;
    i: int = 0;
    while i < n {
        s: int = carry;
        if i < len(a) {
            s = s + a[i];
        }
        if i < len(b) {
            s = s + b[i];
        }
        if s >= BIGNAT_BASE {
            dst.append(s - BIGNAT_BASE);
            carry = 1;
        } else {
            dst.append(s);
            carry = 0;
        }
        i = i + 1;
    }
    if carry > 0 {
        dst.append(carry);
    }
}

"""a -= b in place (a >= b)."""
def _dq_sub(a: list[int], b: list[int]) {
    borrow: int = 0;
    i: int = 0;
    n: int = len(a);
    while i < n {
        d: int = a[i] - borrow;
        if i < len(b) {
            d = d - b[i];
        }
        if d < 0 {
            d = d + BIGNAT_BASE;
            borrow = 1;
        } else {
            borrow = 0;
        }
        a[i] = d;
        i = i + 1;
    }
    while len(a) > 1 and a[len(a) - 1] == 0 {
        a.pop();
    }
}

"""Sign of a - b (high zero limbs ignored)."""
def _dq_cmp(a: list[int], b: list[int]) -> int {
    na: int = len(a);
    while na > 1 and a[na - 1] == 0 {
        na = na - 1;
    }
    nb: int = len(b);
    while nb > 1 and b[nb - 1] == 0 {
        nb = nb - 1;
    }
    if na != nb {
        if na > nb {
            return 1;
        }
        return -1;
    }
    i: int = na - 1;
    while i >= 0 {
        if a[i] != b[i] {
            if a[i] > b[i] {
                return 1;
            }
            return -1;
        }
        i = i - 1;
    }
    return 0;
}

def:pub _dtoa_run_shortest(pos: float) -> None {
    if pos == 0.0 {
        _DTOA_OUT_DIGITS = "0";
        _DTOA_OUT_K = 0;
        return;
    }
    if pos == int(pos) and pos <= DTOA_MAX_SAFE {
        s: str = str(int(pos));
        _DTOA_OUT_DIGITS = s;
        _DTOA_OUT_K = len(s) - 1;
        return;
    }
    parts: list[int] = _double_to_mantissa_exp(pos);
    f: int = parts[0];
    exp2: int = parts[1];
    if f == 0 {
        _DTOA_OUT_DIGITS = "0";
        _DTOA_OUT_K = 0;
        return;
    }
    # Steele & White / Burger & Dybvig free-format digits (exact bignums,
    # in place): R / S is the value, Mm / Mp the gaps to the neighbouring
    # doubles (the tests compare 2R, i.e. against the midpoints). An even
    # mantissa owns its midpoints (round-to-nearest-even reads them back as
    # this double), so its bounds are inclusive: the fewest digits that read
    # back (§6.1.6.1.20 step 5), the closest of them, an even digit on a tie.
    even: bool = (f % 2) == 0;
    _dq_set_int(_DQ_R, f);
    _dq_set_int(_DQ_S, 1);
    _dq_set_int(_DQ_MM, 1);
    if exp2 > 0 {
        _dq_shl(_DQ_R, exp2);
        _dq_shl(_DQ_MM, exp2);
    } elif exp2 < 0 {
        _dq_shl(_DQ_S, 0 - exp2);
    }
    _dq_copy(_DQ_MP, _DQ_MM);
    if parts[2] == 1 {
        _dq_shl(_DQ_MP, 1);
        _dq_shl(_DQ_R, 1);
        _dq_shl(_DQ_S, 1);
    }
    k: int = 0;
    # while 10R < S + 9 (R < ceil(S / 10)): scale R and the gaps up
    _dq_copy(_DQ_T1, _DQ_R);
    _dq_mul(_DQ_T1, 10);
    _dq_set_int(_DQ_T2, 9);
    _dq_add_into(_DQ_2S, _DQ_S, _DQ_T2);
    while _dq_cmp(_DQ_T1, _DQ_2S) < 0 {
        k = k - 1;
        _dq_mul(_DQ_R, 10);
        _dq_mul(_DQ_MP, 10);
        _dq_mul(_DQ_MM, 10);
        _dq_copy(_DQ_T1, _DQ_R);
        _dq_mul(_DQ_T1, 10);
    }
    # while 2R + M+ >= 2S (> for an odd mantissa): scale S up
    while True {
        _dq_add_into(_DQ_T1, _DQ_R, _DQ_R);
        _dq_add_into(_DQ_T2, _DQ_T1, _DQ_MP);
        _dq_add_into(_DQ_2S, _DQ_S, _DQ_S);
        hk: int = _dq_cmp(_DQ_T2, _DQ_2S);
        if hk < 0 or (hk == 0 and not even) {
            break;
        }
        k = k + 1;
        _dq_mul(_DQ_S, 10);
    }
    _dq_add_into(_DQ_2S, _DQ_S, _DQ_S);
    dmap: list[int] = [];
    k_hi: int = k - 1;
    done: bool = False;
    while not done {
        _dq_mul(_DQ_R, 10);
        U: int = 0;
        while U < 9 and _dq_cmp(_DQ_R, _DQ_S) >= 0 {
            _dq_sub(_DQ_R, _DQ_S);
            U = U + 1;
        }
        _dq_mul(_DQ_MM, 10);
        _dq_mul(_DQ_MP, 10);
        _dq_add_into(_DQ_T1, _DQ_R, _DQ_R);
        lw: int = _dq_cmp(_DQ_T1, _DQ_MM);
        low: bool = lw < 0 or (lw == 0 and even);
        # 2R > 2S - M+ without the subtraction (M+ may exceed 2S).
        _dq_add_into(_DQ_T2, _DQ_T1, _DQ_MP);
        hg: int = _dq_cmp(_DQ_T2, _DQ_2S);
        high: bool = hg > 0 or (hg == 0 and even);
        if low or high {
            if high and not low {
                U = U + 1;
            } elif low and high {
                tw: int = _dq_cmp(_DQ_T1, _DQ_S);
                if tw > 0 or (tw == 0 and (U % 2) == 1) {
                    U = U + 1;
                }
            }
            done = True;
        }
        dmap.append(U);
    }
    # A final 9 rounded up carries (not expected with exact bounds; safe).
    ci: int = len(dmap) - 1;
    while ci > 0 and dmap[ci] == 10 {
        dmap[ci] = 0;
        dmap[ci - 1] = dmap[ci - 1] + 1;
        ci = ci - 1;
    }
    if dmap[0] == 10 {
        dcarry: list[int] = [1, 0];
        di0: int = 1;
        while di0 < len(dmap) {
            dcarry.append(dmap[di0]);
            di0 = di0 + 1;
        }
        dmap = dcarry;
        k_hi = k_hi + 1;
    }
    digits: str = "";
    ti: int = 0;
    while ti < len(dmap) {
        digits = digits + str(dmap[ti]);
        ti = ti + 1;
    }
    _DTOA_OUT_DIGITS = _trim_trailing_zeros(digits);
    _DTOA_OUT_K = k_hi;
}

def:pub _dtoa_run_fixed(pos: float, sig_digits: int, exp_align: bool) -> None {
    if sig_digits < 1 {
        sig_digits = 1;
    }
    if pos == 0.0 {
        z: str = "0";
        i: int = 1;
        while i < sig_digits {
            z = z + "0";
            i = i + 1;
        }
        _DTOA_OUT_DIGITS = z;
        _DTOA_OUT_K = 0;
        return;
    }
    if pos == int(pos) and pos <= DTOA_MAX_SAFE and sig_digits >= len(str(int(pos))) {
        base: str = str(int(pos));
        bl: int = len(base);
        if bl >= sig_digits {
            head: str = str_substr(base, 0, sig_digits);
            if bl > sig_digits {
                next_d: int = int(str_char_at(base, sig_digits))
                    - int(str_char_at("0", 0));
                if next_d >= 5 {
                    head = _inc_digit_str(head);
                }
            }
            adj_k: int = sig_digits - 1;
            if len(head) > sig_digits {
                head = str_substr(head, 0, sig_digits);
                adj_k = adj_k + 1;
            }
            _DTOA_OUT_DIGITS = head;
            _DTOA_OUT_K = adj_k;
            return;
        }
        pad: str = "";
        pi: int = bl;
        while pi < sig_digits {
            pad = pad + "0";
            pi = pi + 1;
        }
        _DTOA_OUT_DIGITS = base + pad;
        _DTOA_OUT_K = len(base) - 1;
        return;
    }
    parts: list[int] = _double_to_mantissa_exp(pos);
    f: int = parts[0];
    exp2: int = parts[1];
    e: int = exp2 + DTOA_P;
    _dtoa_setup_fixed_rs(f, e, DTOA_P);
    _dtoa_find_k_fixed(exp_align);
    k: int = _DTOA_W_K;
    R: list[int] = _DTOA_W_R;
    S: list[int] = _DTOA_W_S;
    k_hi: int = k - 1;
    dmap: list[int] = [];
    di: int = 0;
    while di < sig_digits {
        k = k - 1;
        dmap.append(_bn_quorem10(R, S));
        R = _DTOA_DIV_REM;
        di = di + 1;
    }
    twoR: list[int] = _bn_add(R, R);
    if _bn_cmp(twoR, S) >= 0 {
        last: int = len(dmap) - 1;
        dmap[last] = dmap[last] + 1;
        carry: int = 0;
        j: int = last;
        while j >= 0 {
            dmap[j] = dmap[j] + carry;
            carry = 0;
            if dmap[j] >= 10 {
                dmap[j] = dmap[j] - 10;
                carry = 1;
            }
            j = j - 1;
        }
        if carry == 1 {
            # 9…9 rounded up to 10…0: still sig_digits digits (the dropped
            # last one is a 0), one decimal place higher.
            nd: list[int] = [1];
            ti2: int = 0;
            while ti2 < len(dmap) - 1 {
                nd.append(dmap[ti2]);
                ti2 = ti2 + 1;
            }
            dmap = nd;
            k_hi = k_hi + 1;
        }
    }
    digits: str = "";
    ti: int = 0;
    while ti < len(dmap) {
        digits = digits + str(dmap[ti]);
        ti = ti + 1;
    }
    _DTOA_OUT_DIGITS = digits;
    _DTOA_OUT_K = k_hi;
}

"""`a` // m for a small positive int m (m * BIGNAT_BASE fits an int)."""
def _bn_div_small(a: list[int], m: int) -> list[int] {
    q: list[int] = [];
    i: int = 0;
    while i < len(a) {
        q.append(0);
        i = i + 1;
    }
    rem: int = 0;
    j: int = len(a) - 1;
    while j >= 0 {
        cur: int = rem * BIGNAT_BASE + a[j];
        q[j] = cur // m;
        rem = cur % m;
        j = j - 1;
    }
    return _bn_trim(q);
}

"""Decimal digits of the bignum `a`."""
def _bn_to_dec(a: list[int]) -> str {
    t: list[int] = _bn_trim(a);
    out: str = str(t[len(t) - 1]);
    j: int = len(t) - 2;
    while j >= 0 {
        piece: str = str(t[j]);
        while len(piece) < 9 {
            piece = "0" + piece;
        }
        out = out + piece;
        j = j - 1;
    }
    return out;
}

"""Number.prototype.toFixed's n (§21.1.3.3 step 10.a) as decimal digits:
the integer nearest to pos * 10^frac_digits, the larger one on a tie,
computed exactly from the double's value (no int64, no double rounding)."""
def:pub dtoa_fixed_digits(pos: float, frac_digits: int) -> str {
    if pos == 0.0 {
        return "0";
    }
    fparts: list[int] = _double_to_mantissa_exp(pos);
    fN: list[int] = _bn_from_int(fparts[0]);
    fi: int = 0;
    while fi < frac_digits {
        fN = _bn_mul_small(fN, 10);
        fi = fi + 1;
    }
    fe: int = fparts[1];
    if fe >= 0 {
        fN = _bn_shl_small(fN, fe);
    } else {
        fs: int = 0 - fe;
        fN = _bn_add(fN, _bn_shl_small([1], fs - 1));
        while fs > 0 {
            fstep: int = fs;
            if fstep > 29 {
                fstep = 29;
            }
            fN = _bn_div_small(fN, 1 << fstep);
            fs = fs - fstep;
        }
    }
    return _bn_to_dec(fN);
}

def:pub dtoa_shortest(pos: float) -> list[any] {
    _dtoa_run_shortest(pos);
    return [_DTOA_OUT_DIGITS, str(_DTOA_OUT_K)];
}

def:pub dtoa_fixed(pos: float, sig_digits: int) -> list[any] {
    _dtoa_run_fixed(pos, sig_digits, False);
    return [_DTOA_OUT_DIGITS, str(_DTOA_OUT_K)];
}

def:pub dtoa_mul_round(pos: float, frac_digits: int) -> int {
    if pos == 0.0 {
        return 0;
    }
    if frac_digits <= 0 and pos == int(pos) and pos <= DTOA_MAX_SAFE {
        return int(pos);
    }
    _dtoa_run_shortest(pos);
    int_digits: int = _DTOA_OUT_K + 1;
    if _DTOA_OUT_K < 0 {
        int_digits = 0;
    }
    sig: int = int_digits + frac_digits + 1;
    if sig < 1 {
        sig = 1;
    }
    _dtoa_run_fixed(pos, sig, False);
    plain: str = _format_digits_k(_DTOA_OUT_DIGITS, _DTOA_OUT_K);
    if frac_digits == 0 {
        dot0: int = -1;
        pi: int = 0;
        while pi < len(plain) {
            if str_char_at(plain, pi) == "." {
                dot0 = pi;
                break;
            }
            pi = pi + 1;
        }
        if dot0 < 0 {
            return int(plain);
        }
        head0: str = str_substr(plain, 0, dot0);
        next0: int = int(str_char_at(plain, dot0 + 1)) - int(str_char_at("0", 0));
        if next0 >= 5 {
            return int(_inc_digit_str(head0));
        }
        return int(head0);
    }
    dot: int = -1;
    i: int = 0;
    while i < len(plain) {
        if str_char_at(plain, i) == "." {
            dot = i;
            break;
        }
        i = i + 1;
    }
    if dot < 0 {
        if frac_digits == 0 {
            return int(plain);
        }
        return int(plain + _repeat_zeros(frac_digits));
    }
    head: str = str_substr(plain, 0, dot);
    frac: str = str_substr(plain, dot + 1, len(plain));
    if len(frac) <= frac_digits {
        frac = frac + _repeat_zeros(frac_digits - len(frac));
    } else {
        round_d: int = int(str_char_at(frac, frac_digits)) - int(str_char_at("0", 0));
        frac = str_substr(frac, 0, frac_digits);
        if round_d >= 5 {
            frac = _inc_digit_str(frac);
            if len(frac) > frac_digits {
                frac = str_substr(frac, 1, len(frac));
                head = _inc_digit_str(head);
            }
        }
    }
    combined: str = head + frac;
    return int(combined);
}

def _repeat_zeros(count: int) -> str {
    out: str = "";
    i: int = 0;
    while i < count {
        out = out + "0";
        i = i + 1;
    }
    return out;
}

def _pow10_int(exp: int) -> int {
    r: int = 1;
    i: int = 0;
    while i < exp {
        r = r * 10;
        i = i + 1;
    }
    return r;
}

def:pub number_to_string_radix10(n: float) -> str {
    if not (n == n) {
        return "NaN";
    }
    if n > DTOA_MAX_FINITE {
        return "Infinity";
    }
    if n < -DTOA_MAX_FINITE {
        return "-Infinity";
    }
    if n == 0.0 {
        return "0";
    }
    sign: str = "";
    pos: float = n;
    if pos < 0.0 {
        sign = "-";
        pos = -pos;
    }
    if pos >= 1e21 {
        return sign + str(pos);
    }
    if pos == int(pos) and pos <= DTOA_MAX_SAFE {
        return sign + str(int(pos));
    }
    _dtoa_run_shortest(pos);
    return sign + _format_digits_k(_DTOA_OUT_DIGITS, _DTOA_OUT_K);
}
