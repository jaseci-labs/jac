# Constant evaluation for the flowgraph optimizer: the binary and unary
# operations flowgraph.c folds (eval_const_binop, eval_const_unaryop and the
# const_folding_safe_* guards), evaluated with CPython's semantics over the
# compiler's constant objects. None means CPython's evaluation raised and the
# instruction is left unfolded.

glob MAX_INT_SIZE: int = 128,
     MAX_COLLECTION_SIZE: int = 256,
     MAX_STR_SIZE: int = 4096,
     MAX_TOTAL_ITEMS: int = 1024,
     DIGIT_BITS: int = 15,
     DIGIT_BASE: int = 32768,
     DIGIT_MASK: int = 32767,
     SSIZE_MAX: int = 9223372036854775807,
     DBL_MANT_DIG: int = 53,
     DBL_MAX_EXP: int = 1024,
     DBL_MIN_EXP: int = -1021;

obj cint {
    has neg: bool,
        mag: list[int];
}

obj cfloat_result {
    has ok: bool,
        val: float;
}

obj ccomplex {
    has ok: bool,
        real: float,
        imag: float;
}

def is_int_const(c: PyObj) -> bool {
    return isinstance(c, PyInt) or isinstance(c, PyBigInt) or isinstance(c, PyBool);
}

def int_of(c: PyObj) -> cint {
    if isinstance(c, PyBool) {
        if c.val {
            return cint(neg=False, mag=[1]);
        }
        return cint(neg=False, mag=[]);
    }
    if isinstance(c, PyBigInt) {
        return cint(neg=c.negative, mag=mag_norm(c.digits));
    }
    return cint(neg=integer_negative(c), mag=mag_norm(integer_digits(c)));
}

def int_obj(v: cint) -> PyObj {
    return integer_from_digits(v.mag, v.neg and len(v.mag) > 0);
}

def small_int_value(c: PyObj) -> int {
    if isinstance(c, PyInt) {
        if c.val >= 0 and c.val <= 255 {
            return c.val;
        }
        return -1;
    }
    if isinstance(c, PyBigInt) and not c.negative {
        mag = mag_norm(c.digits);
        if len(mag) == 0 {
            return 0;
        }
        if len(mag) == 1 and mag[0] <= 255 {
            return mag[0];
        }
    }
    return -1;
}

def mag_norm(a: list[int]) -> list[int] {
    n = len(a);
    while n > 0 and a[n - 1] == 0 {
        n -= 1;
    }
    out: list[int] = [];
    for k in range(n) {
        out.append(a[k]);
    }
    return out;
}

def mag_cmp(a: list[int], b: list[int]) -> int {
    if len(a) != len(b) {
        return 1 if len(a) > len(b) else -1;
    }
    k = len(a) - 1;
    while k >= 0 {
        if a[k] != b[k] {
            return 1 if a[k] > b[k] else -1;
        }
        k -= 1;
    }
    return 0;
}

def mag_add(a: list[int], b: list[int]) -> list[int] {
    out: list[int] = [];
    carry = 0;
    n = len(a) if len(a) > len(b) else len(b);
    for k in range(n) {
        d = carry;
        if k < len(a) {
            d += a[k];
        }
        if k < len(b) {
            d += b[k];
        }
        out.append(d & DIGIT_MASK);
        carry = d >> DIGIT_BITS;
    }
    if carry {
        out.append(carry);
    }
    return mag_norm(out);
}

def mag_sub(a: list[int], b: list[int]) -> list[int] {
    out: list[int] = [];
    borrow = 0;
    for k in range(len(a)) {
        d = a[k] - borrow;
        if k < len(b) {
            d -= b[k];
        }
        if d < 0 {
            d += DIGIT_BASE;
            borrow = 1;
        } else {
            borrow = 0;
        }
        out.append(d);
    }
    return mag_norm(out);
}

def mag_mul(a: list[int], b: list[int]) -> list[int] {
    if len(a) == 0 or len(b) == 0 {
        return [];
    }
    out: list[int] = [];
    for k in range(len(a) + len(b)) {
        out.append(0);
    }
    for i in range(len(a)) {
        carry = 0;
        ai = a[i];
        for j in range(len(b)) {
            cur = out[i + j] + ai * b[j] + carry;
            out[i + j] = cur & DIGIT_MASK;
            carry = cur >> DIGIT_BITS;
        }
        k = i + len(b);
        while carry {
            cur = out[k] + carry;
            out[k] = cur & DIGIT_MASK;
            carry = cur >> DIGIT_BITS;
            k += 1;
        }
    }
    return mag_norm(out);
}

def mag_numbits(a: list[int]) -> int {
    n = len(a);
    if n == 0 {
        return 0;
    }
    bits = (n - 1) * DIGIT_BITS;
    top = a[n - 1];
    while top {
        bits += 1;
        top = top >> 1;
    }
    return bits;
}

def mag_shl(a: list[int], nbits: int) -> list[int] {
    if len(a) == 0 {
        return [];
    }
    whole = nbits // DIGIT_BITS;
    part = nbits % DIGIT_BITS;
    out: list[int] = [];
    for k in range(whole) {
        out.append(0);
    }
    carry = 0;
    for d in a {
        cur = (d << part) | carry;
        out.append(cur & DIGIT_MASK);
        carry = cur >> DIGIT_BITS;
    }
    if carry {
        out.append(carry);
    }
    return mag_norm(out);
}

def mag_shr(a: list[int], nbits: int) -> list[int] {
    whole = nbits // DIGIT_BITS;
    part = nbits % DIGIT_BITS;
    if whole >= len(a) {
        return [];
    }
    out: list[int] = [];
    for k in range(whole, len(a)) {
        lo = a[k] >> part;
        hi = 0;
        if k + 1 < len(a) {
            hi = (a[k + 1] << (DIGIT_BITS - part)) & DIGIT_MASK;
        }
        out.append(lo | hi);
    }
    return mag_norm(out);
}

def mag_bit(a: list[int], index: int) -> int {
    return (a[index // DIGIT_BITS] >> (index % DIGIT_BITS)) & 1;
}

def mag_divmod(a: list[int], b: list[int]) -> tuple[list[int], list[int]] {
    if mag_cmp(a, b) < 0 {
        return ([], mag_norm(a));
    }
    if len(b) == 1 {
        divisor = b[0];
        q: list[int] = [];
        for k in range(len(a)) {
            q.append(0);
        }
        rem = 0;
        k = len(a) - 1;
        while k >= 0 {
            cur = (rem << DIGIT_BITS) | a[k];
            q[k] = cur // divisor;
            rem = cur % divisor;
            k -= 1;
        }
        return (mag_norm(q), mag_norm([rem]));
    }
    nbits = mag_numbits(a);
    quotient: list[int] = [];
    for k in range(len(a)) {
        quotient.append(0);
    }
    r: list[int] = [];
    k = nbits - 1;
    while k >= 0 {
        r = mag_shl(r, 1);
        if mag_bit(a, k) {
            r = mag_add(r, [1]);
        }
        if mag_cmp(r, b) >= 0 {
            r = mag_sub(r, b);
            quotient[k // DIGIT_BITS] = quotient[k // DIGIT_BITS]
                | (1 << (k % DIGIT_BITS));
        }
        k -= 1;
    }
    return (mag_norm(quotient), r);
}

def mag_small(v: int) -> list[int] {
    out: list[int] = [];
    rest = v;
    while rest > 0 {
        out.append(rest & DIGIT_MASK);
        rest = rest >> DIGIT_BITS;
    }
    return out;
}

def mag_to_small(a: list[int]) -> int {
    value = 0;
    k = len(a) - 1;
    while k >= 0 {
        value = (value << DIGIT_BITS) | a[k];
        k -= 1;
    }
    return value;
}

def mag_fits(a: list[int], maxbits: int) -> bool {
    return mag_numbits(a) <= maxbits;
}

def cint_add(a: cint, b: cint) -> cint {
    if a.neg == b.neg {
        return cint(neg=a.neg, mag=mag_add(a.mag, b.mag));
    }
    c = mag_cmp(a.mag, b.mag);
    if c == 0 {
        return cint(neg=False, mag=[]);
    }
    if c > 0 {
        return cint(neg=a.neg, mag=mag_sub(a.mag, b.mag));
    }
    return cint(neg=b.neg, mag=mag_sub(b.mag, a.mag));
}

def cint_neg(a: cint) -> cint {
    return cint(neg=not a.neg and len(a.mag) > 0, mag=a.mag);
}

def cint_sub(a: cint, b: cint) -> cint {
    return cint_add(a, cint_neg(b));
}

def cint_mul(a: cint, b: cint) -> cint {
    m = mag_mul(a.mag, b.mag);
    return cint(neg=(a.neg != b.neg) and len(m) > 0, mag=m);
}

def cint_floordivmod(a: cint, b: cint) -> tuple[cint, cint] {
    (qm, rm) = mag_divmod(a.mag, b.mag);
    if a.neg != b.neg {
        if len(rm) == 0 {
            return (cint(neg=len(qm) > 0, mag=qm), cint(neg=False, mag=[]));
        }
        q2 = mag_add(qm, [1]);
        return (cint(neg=True, mag=q2), cint(neg=b.neg, mag=mag_sub(b.mag, rm)));
    }
    return (cint(neg=False, mag=qm), cint(neg=b.neg and len(rm) > 0, mag=rm));
}

def twos_digits(a: cint, ndig: int) -> list[int] {
    src = a.mag;
    if a.neg {
        src = mag_sub(a.mag, [1]);
    }
    out: list[int] = [];
    for k in range(ndig) {
        d = src[k] if k < len(src) else 0;
        if a.neg {
            d = d ^ DIGIT_MASK;
        }
        out.append(d);
    }
    return out;
}

def from_twos(digits: list[int], neg: bool) -> cint {
    if not neg {
        return cint(neg=False, mag=mag_norm(digits));
    }
    inv: list[int] = [];
    for d in digits {
        inv.append(d ^ DIGIT_MASK);
    }
    return cint(neg=True, mag=mag_add(mag_norm(inv), [1]));
}

def cint_bitwise(a: cint, b: cint, op: int) -> cint {
    ndig = (len(a.mag) if len(a.mag) > len(b.mag) else len(b.mag)) + 1;
    da = twos_digits(a, ndig);
    db = twos_digits(b, ndig);
    out: list[int] = [];
    for k in range(ndig) {
        if op == NB_AND {
            out.append(da[k] & db[k]);
        } elif op == NB_OR {
            out.append(da[k] | db[k]);
        } else {
            out.append(da[k] ^ db[k]);
        }
    }
    neg = False;
    if op == NB_AND {
        neg = a.neg and b.neg;
    } elif op == NB_OR {
        neg = a.neg or b.neg;
    } else {
        neg = a.neg != b.neg;
    }
    return from_twos(out, neg);
}

def cint_to_float(a: cint) -> cfloat_result {
    if len(a.mag) == 0 {
        return cfloat_result(ok=True, val=0.0);
    }
    bits = mag_numbits(a.mag);
    if bits > DBL_MAX_EXP {
        return cfloat_result(ok=False, val=0.0);
    }
    shift = bits - DBL_MANT_DIG;
    if shift < 0 {
        shift = 0;
    }
    mantissa = mag_shr(a.mag, shift);
    if shift > 0 {
        guard = mag_bit(a.mag, shift - 1);
        sticky = False;
        for k in range(shift - 1) {
            if mag_bit(a.mag, k) {
                sticky = True;
                break;
            }
        }
        if guard and (sticky or (len(mantissa) > 0 and (mantissa[0] & 1))) {
            mantissa = mag_add(mantissa, [1]);
        }
    }
    result = float(mag_to_small(mantissa));
    result = scale_by_two(result, shift);
    if is_inf(result) {
        return cfloat_result(ok=False, val=0.0);
    }
    return cfloat_result(ok=True, val=-result if a.neg else result);
}

def scale_by_two(value: float, exp: int) -> float {
    result = value;
    k = exp;
    while k > 0 {
        result = result * 2.0;
        k -= 1;
    }
    while k < 0 {
        result = result * 0.5;
        k += 1;
    }
    return result;
}

def float_inf -> float {
    return float("inf");
}

def is_inf(v: float) -> bool {
    return v == float_inf() or v == -float_inf();
}

def is_nan(v: float) -> bool {
    return v != v;
}

def is_finite(v: float) -> bool {
    return not is_inf(v) and not is_nan(v);
}

def sign_negative(v: float) -> bool {
    if v < 0.0 {
        return True;
    }
    if v == 0.0 {
        return repr(v).startswith("-");
    }
    return False;
}

def copysign(v: float, s: float) -> float {
    mag = -v if sign_negative(v) else v;
    return -mag if sign_negative(s) else mag;
}

def int_true_divide_const(a: cint, b: cint) -> PyObj | None {
    if len(b.mag) == 0 {
        return None;
    }
    negate = a.neg != b.neg;
    if len(a.mag) == 0 {
        return PyFloat(t="float", val=-0.0 if negate else 0.0);
    }
    diff = mag_numbits(a.mag) - mag_numbits(b.mag);
    e = diff;
    if diff >= 0 {
        if mag_cmp(a.mag, mag_shl(b.mag, diff)) >= 0 {
            e = diff + 1;
        }
    } elif mag_cmp(mag_shl(a.mag, -diff), b.mag) >= 0 {
        e = diff + 1;
    }
    if e > DBL_MAX_EXP {
        return None;
    }
    s = e;
    if s < DBL_MIN_EXP {
        s = DBL_MIN_EXP;
    }
    s = s - DBL_MANT_DIG;
    num = a.mag;
    den = b.mag;
    if s < 0 {
        num = mag_shl(num, -s);
    } else {
        den = mag_shl(den, s);
    }
    (q, r) = mag_divmod(num, den);
    r2 = mag_shl(r, 1);
    c = mag_cmp(r2, den);
    if c > 0 or (c == 0 and len(q) > 0 and (q[0] & 1)) {
        q = mag_add(q, [1]);
    }
    result = scale_by_two(float(mag_to_small(q)), s);
    if is_inf(result) {
        return None;
    }
    return PyFloat(t="float", val=-result if negate else result);
}

def ssize_of(c: cint) -> tuple[bool, int] {
    if mag_numbits(c.mag) > 63 {
        if c.neg
            and mag_numbits(c.mag) == 64
            and mag_cmp(mag_shr(c.mag, 63), [1]) == 0
            and mag_numbits(mag_sub(c.mag, mag_shl([1], 63))) == 0 {
            return (True, -SSIZE_MAX - 1);
        }
        return (False, 0);
    }
    value = mag_to_small(c.mag);
    return (True, -value if c.neg else value);
}

def eval_int_binop(a: cint, op: int, b: cint) -> PyObj | None {
    if op == NB_ADD {
        return int_obj(cint_add(a, b));
    }
    if op == NB_SUBTRACT {
        return int_obj(cint_sub(a, b));
    }
    if op == NB_MULTIPLY {
        if len(a.mag) > 0 and len(b.mag) > 0 {
            if mag_numbits(a.mag) + mag_numbits(b.mag) > MAX_INT_SIZE {
                return None;
            }
        }
        return int_obj(cint_mul(a, b));
    }
    if op == NB_TRUE_DIVIDE {
        return int_true_divide_const(a, b);
    }
    if op == NB_FLOOR_DIVIDE or op == NB_REMAINDER {
        if len(b.mag) == 0 {
            return None;
        }
        (q, r) = cint_floordivmod(a, b);
        return int_obj(q if op == NB_FLOOR_DIVIDE else r);
    }
    if op == NB_POWER {
        if b.neg {
            fa = cint_to_float(a);
            fb = cint_to_float(b);
            if not fa.ok or not fb.ok {
                return None;
            }
            return float_pow_const(fa.val, fb.val);
        }
        if len(b.mag) == 0 {
            return PyInt(t="int", val=1);
        }
        if len(a.mag) == 0 {
            return PyInt(t="int", val=0);
        }
        if mag_numbits(b.mag) > 63 {
            return None;
        }
        exponent = mag_to_small(b.mag);
        if mag_numbits(a.mag) > MAX_INT_SIZE // exponent {
            return None;
        }
        result = cint(neg=False, mag=[1]);
        base = a;
        e = exponent;
        while e > 0 {
            if e & 1 {
                result = cint_mul(result, base);
            }
            e = e >> 1;
            if e > 0 {
                base = cint_mul(base, base);
            }
        }
        return int_obj(result);
    }
    if op == NB_LSHIFT {
        if b.neg {
            return None;
        }
        if len(a.mag) == 0 {
            return PyInt(t="int", val=0);
        }
        if len(b.mag) == 0 {
            return int_obj(a);
        }
        if mag_numbits(b.mag) > 63 {
            return None;
        }
        shift = mag_to_small(b.mag);
        if shift > MAX_INT_SIZE or mag_numbits(a.mag) > MAX_INT_SIZE - shift {
            return None;
        }
        return int_obj(cint(neg=a.neg, mag=mag_shl(a.mag, shift)));
    }
    if op == NB_RSHIFT {
        if b.neg {
            return None;
        }
        nbits = mag_numbits(a.mag);
        if mag_numbits(b.mag) > 63 or mag_to_small(b.mag) >= nbits {
            if a.neg {
                return PyInt(t="int", val=-1);
            }
            return PyInt(t="int", val=0);
        }
        shift = mag_to_small(b.mag);
        if a.neg {
            m = mag_shr(mag_sub(a.mag, [1]), shift);
            return int_obj(cint(neg=True, mag=mag_add(m, [1])));
        }
        return int_obj(cint(neg=False, mag=mag_shr(a.mag, shift)));
    }
    if op == NB_AND or op == NB_OR or op == NB_XOR {
        return int_obj(cint_bitwise(a, b, op));
    }
    return None;
}

def float_pow_const(x: float, y: float) -> PyObj | None {
    if y == 0.0 {
        return PyFloat(t="float", val=1.0);
    }
    if x < 0.0 and is_finite(y) and y != y // 1.0 {
        return None;
    }
    if x == 0.0 and y < 0.0 {
        return None;
    }
    try {
        r = x ** y;
    } except Exception {
        return None;
    }
    if is_inf(r) and is_finite(x) and is_finite(y) {
        return None;
    }
    return PyFloat(t="float", val=r);
}

def eval_float_binop(x: float, op: int, y: float) -> PyObj | None {
    if op == NB_ADD {
        return PyFloat(t="float", val=x + y);
    }
    if op == NB_SUBTRACT {
        return PyFloat(t="float", val=x - y);
    }
    if op == NB_MULTIPLY {
        return PyFloat(t="float", val=x * y);
    }
    if op == NB_TRUE_DIVIDE {
        if y == 0.0 {
            return None;
        }
        return PyFloat(t="float", val=x / y);
    }
    if op == NB_FLOOR_DIVIDE {
        if y == 0.0 {
            return None;
        }
        return PyFloat(t="float", val=x // y);
    }
    if op == NB_REMAINDER {
        if y == 0.0 {
            return None;
        }
        return PyFloat(t="float", val=x % y);
    }
    if op == NB_POWER {
        return float_pow_const(x, y);
    }
    return None;
}

def c_prod(ar: float, ai: float, br: float, bi: float) -> ccomplex {
    a = ar;
    b = ai;
    c = br;
    d = bi;
    ac = a * c;
    bd = b * d;
    ad = a * d;
    bc = b * c;
    rr = ac - bd;
    ri = ad + bc;
    if is_nan(rr) and is_nan(ri) {
        recalc = False;
        if is_inf(a) or is_inf(b) {
            a = copysign(1.0 if is_inf(a) else 0.0, a);
            b = copysign(1.0 if is_inf(b) else 0.0, b);
            if is_nan(c) {
                c = copysign(0.0, c);
            }
            if is_nan(d) {
                d = copysign(0.0, d);
            }
            recalc = True;
        }
        if is_inf(c) or is_inf(d) {
            c = copysign(1.0 if is_inf(c) else 0.0, c);
            d = copysign(1.0 if is_inf(d) else 0.0, d);
            if is_nan(a) {
                a = copysign(0.0, a);
            }
            if is_nan(b) {
                b = copysign(0.0, b);
            }
            recalc = True;
        }
        if not recalc and (is_inf(ac) or is_inf(bd) or is_inf(ad) or is_inf(bc)) {
            if is_nan(a) {
                a = copysign(0.0, a);
            }
            if is_nan(b) {
                b = copysign(0.0, b);
            }
            if is_nan(c) {
                c = copysign(0.0, c);
            }
            if is_nan(d) {
                d = copysign(0.0, d);
            }
            recalc = True;
        }
        if recalc {
            rr = float_inf() * (a * c - b * d);
            ri = float_inf() * (a * d + b * c);
        }
    }
    return ccomplex(ok=True, real=rr, imag=ri);
}

def c_quot(ar: float, ai: float, br: float, bi: float) -> ccomplex {
    abs_breal = -br if br < 0 else br;
    abs_bimag = -bi if bi < 0 else bi;
    rr = 0.0;
    ri = 0.0;
    if abs_breal >= abs_bimag {
        if abs_breal == 0.0 {
            return ccomplex(ok=False, real=0.0, imag=0.0);
        }
        ratio = bi / br;
        denom = br + bi * ratio;
        rr = (ar + ai * ratio) / denom;
        ri = (ai - ar * ratio) / denom;
    } elif abs_bimag >= abs_breal {
        ratio = br / bi;
        denom = br * ratio + bi;
        rr = (ar * ratio + ai) / denom;
        ri = (ai * ratio - ar) / denom;
    } else {
        rr = float("nan");
        ri = float("nan");
    }
    if is_nan(rr) and is_nan(ri) {
        if (is_inf(ar) or is_inf(ai)) and is_finite(br) and is_finite(bi) {
            x = copysign(1.0 if is_inf(ar) else 0.0, ar);
            y = copysign(1.0 if is_inf(ai) else 0.0, ai);
            rr = float_inf() * (x * br + y * bi);
            ri = float_inf() * (y * br - x * bi);
        } elif (is_inf(abs_breal) or is_inf(abs_bimag))
            and is_finite(ar)
            and is_finite(ai) {
            x = copysign(1.0 if is_inf(br) else 0.0, br);
            y = copysign(1.0 if is_inf(bi) else 0.0, bi);
            rr = 0.0 * (ar * x + ai * y);
            ri = 0.0 * (ai * x - ar * y);
        }
    }
    return ccomplex(ok=True, real=rr, imag=ri);
}

def rc_quot(a: float, br: float, bi: float) -> ccomplex {
    abs_breal = -br if br < 0 else br;
    abs_bimag = -bi if bi < 0 else bi;
    rr = 0.0;
    ri = 0.0;
    if abs_breal >= abs_bimag {
        if abs_breal == 0.0 {
            return ccomplex(ok=False, real=0.0, imag=0.0);
        }
        ratio = bi / br;
        denom = br + bi * ratio;
        rr = a / denom;
        ri = (-a * ratio) / denom;
    } elif abs_bimag >= abs_breal {
        ratio = br / bi;
        denom = br * ratio + bi;
        rr = (a * ratio) / denom;
        ri = (-a) / denom;
    } else {
        rr = float("nan");
        ri = float("nan");
    }
    if is_nan(rr)
        and is_nan(ri)
        and is_finite(a)
        and (is_inf(abs_breal) or is_inf(abs_bimag)) {
        x = copysign(1.0 if is_inf(br) else 0.0, br);
        y = copysign(1.0 if is_inf(bi) else 0.0, bi);
        rr = 0.0 * (a * x);
        ri = 0.0 * (-a * y);
    }
    return ccomplex(ok=True, real=rr, imag=ri);
}

def c_powi(xr: float, xi: float, n: int) -> ccomplex {
    count = n if n > 0 else -n;
    rr = 1.0;
    ri = 0.0;
    pr = xr;
    pi = xi;
    mask = 1;
    while mask > 0 and count >= mask {
        if count & mask {
            r = c_prod(rr, ri, pr, pi);
            rr = r.real;
            ri = r.imag;
        }
        mask = mask << 1;
        p = c_prod(pr, pi, pr, pi);
        pr = p.real;
        pi = p.imag;
    }
    if n > 0 {
        return ccomplex(ok=True, real=rr, imag=ri);
    }
    return c_quot(1.0, 0.0, rr, ri);
}

def real_value(c: PyObj) -> cfloat_result {
    if isinstance(c, PyFloat) {
        return cfloat_result(ok=True, val=c.val);
    }
    if is_int_const(c) {
        return cint_to_float(int_of(c));
    }
    return cfloat_result(ok=False, val=0.0);
}

def complex_result(r: ccomplex) -> PyObj | None {
    if not r.ok {
        return None;
    }
    return PyComplex(t="complex", real=r.real, imag=r.imag);
}

def eval_complex_binop(left: PyObj, op: int, right: PyObj) -> PyObj | None {
    lc = isinstance(left, PyComplex);
    rc = isinstance(right, PyComplex);
    ar = 0.0;
    ai = 0.0;
    br = 0.0;
    bi = 0.0;
    if lc {
        ar = (left as PyComplex).real;
        ai = (left as PyComplex).imag;
    } else {
        lv = real_value(left);
        if not lv.ok {
            return None;
        }
        ar = lv.val;
    }
    if rc {
        br = (right as PyComplex).real;
        bi = (right as PyComplex).imag;
    } else {
        rv = real_value(right);
        if not rv.ok {
            return None;
        }
        br = rv.val;
    }
    if op == NB_POWER {
        if bi == 0.0
            and is_finite(br)
            and br == br // 1.0
            and br <= 100.0
            and br >= -100.0 {
            p = c_powi(ar, ai, int(br));
            if not p.ok {
                return None;
            }
            if is_inf(p.real) or is_inf(p.imag) {
                return None;
            }
            return complex_result(p);
        }
        if br == 0.0 and bi == 0.0 {
            return PyComplex(t="complex", real=1.0, imag=0.0);
        }
        return None;
    }
    if op == NB_ADD {
        if lc and rc {
            return PyComplex(t="complex", real=ar + br, imag=ai + bi);
        }
        if rc {
            return PyComplex(t="complex", real=br + ar, imag=bi);
        }
        return PyComplex(t="complex", real=ar + br, imag=ai);
    }
    if op == NB_SUBTRACT {
        if lc and rc {
            return PyComplex(t="complex", real=ar - br, imag=ai - bi);
        }
        if rc {
            return PyComplex(t="complex", real=ar - br, imag=-bi);
        }
        return PyComplex(t="complex", real=ar - br, imag=ai);
    }
    if op == NB_MULTIPLY {
        if lc and rc {
            return complex_result(c_prod(ar, ai, br, bi));
        }
        if rc {
            return PyComplex(t="complex", real=br * ar, imag=bi * ar);
        }
        return PyComplex(t="complex", real=ar * br, imag=ai * br);
    }
    if op == NB_TRUE_DIVIDE {
        if lc and rc {
            return complex_result(c_quot(ar, ai, br, bi));
        }
        if rc {
            return complex_result(rc_quot(ar, br, bi));
        }
        if br == 0.0 {
            return None;
        }
        return PyComplex(t="complex", real=ar / br, imag=ai / br);
    }
    return None;
}

def is_seq_const(c: PyObj) -> bool {
    return isinstance(c, PyStr) or isinstance(c, PyBytes) or isinstance(c, PyTuple);
}

def seq_len(c: PyObj) -> int {
    if isinstance(c, PyStr) {
        return len(c.val);
    }
    if isinstance(c, PyBytes) {
        return len(c.val);
    }
    if isinstance(c, PyTuple) {
        return len(c.items);
    }
    return 0;
}

def seq_concat(a: PyObj, b: PyObj) -> PyObj | None {
    if isinstance(a, PyStr) and isinstance(b, PyStr) {
        return PyStr(t="str", val=a.val + b.val);
    }
    if isinstance(a, PyBytes) and isinstance(b, PyBytes) {
        vals: list[int] = [];
        for v in a.val {
            vals.append(v);
        }
        for v in b.val {
            vals.append(v);
        }
        return PyBytes(t="bytes", val=vals);
    }
    if isinstance(a, PyTuple) and isinstance(b, PyTuple) {
        items: list[PyObj] = [];
        for v in a.items {
            items.append(v);
        }
        for v in b.items {
            items.append(v);
        }
        return PyTuple(t="tuple", items=items);
    }
    return None;
}

def seq_repeat(s: PyObj, count: PyObj) -> PyObj | None {
    (ok, n) = ssize_of(int_of(count));
    if not ok {
        return None;
    }
    if n < 0 or seq_len(s) == 0 {
        n = 0;
    }
    if isinstance(s, PyStr) {
        out = "";
        for k in range(n) {
            out = out + s.val;
        }
        return PyStr(t="str", val=out);
    }
    if isinstance(s, PyBytes) {
        vals: list[int] = [];
        for k in range(n) {
            for v in s.val {
                vals.append(v);
            }
        }
        return PyBytes(t="bytes", val=vals);
    }
    if isinstance(s, PyTuple) {
        items: list[PyObj] = [];
        for k in range(n) {
            for v in s.items {
                items.append(v);
            }
        }
        return PyTuple(t="tuple", items=items);
    }
    return None;
}

def const_folding_check_complexity(c: PyObj, limit: int) -> int {
    rest = limit;
    if isinstance(c, PyTuple) {
        rest -= len(c.items);
        k = 0;
        while rest >= 0 and k < len(c.items) {
            rest = const_folding_check_complexity(c.items[k], rest);
            if rest < 0 {
                return rest;
            }
            k += 1;
        }
    }
    return rest;
}

def as_long(c: PyObj) -> int {
    (ok, n) = ssize_of(int_of(c));
    if not ok {
        return -1;
    }
    return n;
}

def const_folding_safe_multiply(v: PyObj, w: PyObj) -> PyObj | None {
    if is_int_const(v) and isinstance(w, PyTuple) {
        size = len(w.items);
        if size {
            n = as_long(v);
            if n < 0 or n > MAX_COLLECTION_SIZE // size {
                return None;
            }
            if n and const_folding_check_complexity(w, MAX_TOTAL_ITEMS // n) < 0 {
                return None;
            }
        }
    } elif is_int_const(v) and (isinstance(w, PyStr) or isinstance(w, PyBytes)) {
        size = seq_len(w);
        if size {
            n = as_long(v);
            if n < 0 or n > MAX_STR_SIZE // size {
                return None;
            }
        }
    } elif is_int_const(w) and is_seq_const(v) {
        return const_folding_safe_multiply(w, v);
    }
    return number_multiply(v, w);
}

def number_multiply(v: PyObj, w: PyObj) -> PyObj | None {
    if is_seq_const(v) {
        if is_int_const(w) {
            return seq_repeat(v, w);
        }
        return None;
    }
    if is_seq_const(w) {
        if is_int_const(v) {
            return seq_repeat(w, v);
        }
        return None;
    }
    return eval_numeric_binop(v, NB_MULTIPLY, w);
}

def eval_numeric_binop(left: PyObj, op: int, right: PyObj) -> PyObj | None {
    if is_int_const(left) and is_int_const(right) {
        return eval_int_binop(int_of(left), op, int_of(right));
    }
    if isinstance(left, PyComplex) or isinstance(right, PyComplex) {
        if (
            isinstance(left, PyComplex)
            or isinstance(left, PyFloat)
            or is_int_const(left)
        )
            and (
                isinstance(right, PyComplex)
                or isinstance(right, PyFloat)
                or is_int_const(right)
            ) {
            return eval_complex_binop(left, op, right);
        }
        return None;
    }
    if (isinstance(left, PyFloat) or is_int_const(left))
        and (isinstance(right, PyFloat) or is_int_const(right)) {
        lv = real_value(left);
        rv = real_value(right);
        if not lv.ok or not rv.ok {
            return None;
        }
        return eval_float_binop(lv.val, op, rv.val);
    }
    return None;
}

def slice_index(c: PyObj) -> tuple[bool, int] {
    if not is_int_const(c) {
        return (False, 0);
    }
    v = int_of(c);
    (ok, n) = ssize_of(v);
    if ok {
        return (True, n);
    }
    if v.neg {
        return (True, -SSIZE_MAX - 1);
    }
    return (True, SSIZE_MAX);
}

def seq_item(s: PyObj, index: int) -> PyObj {
    if isinstance(s, PyStr) {
        return PyStr(t="str", val=s.val[index]);
    }
    if isinstance(s, PyBytes) {
        return PyInt(t="int", val=s.val[index]);
    }
    return (s as PyTuple).items[index];
}

def seq_slice(s: PyObj, start: int, step: int, count: int) -> PyObj {
    if isinstance(s, PyStr) {
        out = "";
        for k in range(count) {
            out = out + s.val[start + k * step];
        }
        return PyStr(t="str", val=out);
    }
    if isinstance(s, PyBytes) {
        vals: list[int] = [];
        for k in range(count) {
            vals.append(s.val[start + k * step]);
        }
        return PyBytes(t="bytes", val=vals);
    }
    items: list[PyObj] = [];
    tup = s as PyTuple;
    for k in range(count) {
        items.append(tup.items[start + k * step]);
    }
    return PyTuple(t="tuple", items=items);
}

def eval_subscript(container: PyObj, key: PyObj) -> PyObj | None {
    if not is_seq_const(container) {
        return None;
    }
    length = seq_len(container);
    if is_int_const(key) {
        (ok, index) = ssize_of(int_of(key));
        if not ok {
            return None;
        }
        if index < 0 {
            index += length;
        }
        if index < 0 or index >= length {
            return None;
        }
        return seq_item(container, index);
    }
    if not isinstance(key, PySlice) {
        return None;
    }
    step = 1;
    if not isinstance(key.step, PyNoneType) {
        (ok, step) = slice_index(key.step);
        if not ok {
            return None;
        }
        if step == 0 {
            return None;
        }
        if step < -SSIZE_MAX {
            step = -SSIZE_MAX;
        }
    }
    start = 0;
    if isinstance(key.start, PyNoneType) {
        start = SSIZE_MAX if step < 0 else 0;
    } else {
        (ok, start) = slice_index(key.start);
        if not ok {
            return None;
        }
    }
    stop = 0;
    if isinstance(key.stop, PyNoneType) {
        stop = -SSIZE_MAX - 1 if step < 0 else SSIZE_MAX;
    } else {
        (ok, stop) = slice_index(key.stop);
        if not ok {
            return None;
        }
    }
    if start < 0 {
        start += length;
        if start < 0 {
            start = -1 if step < 0 else 0;
        }
    } elif start >= length {
        start = length - 1 if step < 0 else length;
    }
    if stop < 0 {
        stop += length;
        if stop < 0 {
            stop = -1 if step < 0 else 0;
        }
    } elif stop >= length {
        stop = length - 1 if step < 0 else length;
    }
    count = 0;
    if step < 0 {
        if stop < start {
            count = (start - stop - 1) // (-step) + 1;
        }
    } elif start < stop {
        count = (stop - start - 1) // step + 1;
    }
    return seq_slice(container, start, step, count);
}

def eval_const_binop(left: PyObj, op: int, right: PyObj) -> PyObj | None {
    if op == NB_ADD {
        if is_seq_const(left) or is_seq_const(right) {
            return seq_concat(left, right);
        }
        return eval_numeric_binop(left, op, right);
    }
    if op == NB_MULTIPLY {
        if is_int_const(left) and is_int_const(right) {
            return eval_numeric_binop(left, op, right);
        }
        return const_folding_safe_multiply(left, right);
    }
    if op == NB_REMAINDER {
        if isinstance(left, PyStr) or isinstance(left, PyBytes) {
            return None;
        }
        return eval_numeric_binop(left, op, right);
    }
    if op == NB_SUBTRACT
        or op == NB_TRUE_DIVIDE
        or op == NB_FLOOR_DIVIDE
        or op == NB_POWER {
        return eval_numeric_binop(left, op, right);
    }
    if op == NB_LSHIFT
        or op == NB_RSHIFT
        or op == NB_OR
        or op == NB_XOR
        or op == NB_AND {
        if is_int_const(left) and is_int_const(right) {
            if isinstance(left, PyBool)
                and isinstance(right, PyBool)
                and (op == NB_OR or op == NB_XOR or op == NB_AND) {
                lb = left.val;
                rb = right.val;
                if op == NB_AND {
                    return PyBool(t="bool", val=lb and rb);
                }
                if op == NB_OR {
                    return PyBool(t="bool", val=lb or rb);
                }
                return PyBool(t="bool", val=lb != rb);
            }
            return eval_int_binop(int_of(left), op, int_of(right));
        }
        return None;
    }
    if op == NB_SUBSCR {
        return eval_subscript(left, right);
    }
    return None;
}

def eval_const_unaryop(operand: PyObj, opcode: int, oparg: int) -> PyObj | None {
    if opcode == OP_UNARY_NEGATIVE {
        if is_int_const(operand) {
            return int_obj(cint_neg(int_of(operand)));
        }
        if isinstance(operand, PyFloat) {
            return PyFloat(t="float", val=-operand.val);
        }
        if isinstance(operand, PyComplex) {
            return PyComplex(t="complex", real=-operand.real, imag=-operand.imag);
        }
        return None;
    }
    if opcode == OP_UNARY_INVERT {
        if isinstance(operand, PyBool) {
            return None;
        }
        if is_int_const(operand) {
            return int_obj(
                cint_neg(cint_add(int_of(operand), cint(neg=False, mag=[1])))
            );
        }
        return None;
    }
    if opcode == OP_UNARY_NOT {
        return PyBool(t="bool", val=const_is_true(operand) == 0);
    }
    if opcode == OP_CALL_INTRINSIC_1 {
        if is_int_const(operand) {
            return int_obj(int_of(operand));
        }
        if isinstance(operand, PyFloat) or isinstance(operand, PyComplex) {
            return operand;
        }
        return None;
    }
    return None;
}

def const_is_true(c: PyObj) -> int {
    if isinstance(c, PyBool) {
        return 1 if c.val else 0;
    }
    if isinstance(c, PyNoneType) {
        return 0;
    }
    if isinstance(c, PyInt) {
        return 1 if c.val != 0 else 0;
    }
    if isinstance(c, PyBigInt) {
        return 1 if len(mag_norm(c.digits)) > 0 else 0;
    }
    if isinstance(c, PyFloat) {
        return 1 if c.val != 0.0 else 0;
    }
    if isinstance(c, PyComplex) {
        return 1 if c.real != 0.0 or c.imag != 0.0 else 0;
    }
    if isinstance(c, PyStr) {
        return 1 if len(c.val) > 0 else 0;
    }
    if isinstance(c, PyBytes) {
        return 1 if len(c.val) > 0 else 0;
    }
    if isinstance(c, PyTuple) {
        return 1 if len(c.items) > 0 else 0;
    }
    if isinstance(c, PySet) {
        return 1 if len(c.items) > 0 else 0;
    }
    if isinstance(c, PyEllipsis) or isinstance(c, PyCode) or isinstance(c, PySlice) {
        return 1;
    }
    return 1 if c.tp_bool() else 0;
}

def float_int_equal(f: float, v: cint) -> bool {
    if not is_finite(f) {
        return False;
    }
    if f != f // 1.0 {
        return False;
    }
    neg = f < 0.0;
    rest = -f if neg else f;
    digits: list[int] = [];
    while rest > 0.0 {
        digit = rest % 32768.0;
        digits.append(int(digit));
        rest = (rest - digit) / 32768.0;
    }
    mag = mag_norm(digits);
    if len(mag) == 0 {
        return len(v.mag) == 0;
    }
    return neg == v.neg and mag_cmp(mag, v.mag) == 0;
}

def numeric_parts(c: PyObj) -> int {
    if is_int_const(c) {
        return 1;
    }
    if isinstance(c, PyFloat) {
        return 2;
    }
    if isinstance(c, PyComplex) {
        return 3;
    }
    return 0;
}

def const_equal(a: PyObj, b: PyObj) -> bool {
    if a is b {
        return True;
    }
    ka = numeric_parts(a);
    kb = numeric_parts(b);
    if ka and kb {
        if ka == 1 and kb == 1 {
            va = int_of(a);
            vb = int_of(b);
            return va.neg == vb.neg and mag_cmp(va.mag, vb.mag) == 0;
        }
        if ka == 3 or kb == 3 {
            ar = 0.0;
            ai = 0.0;
            br = 0.0;
            bi = 0.0;
            if ka == 3 {
                ar = (a as PyComplex).real;
                ai = (a as PyComplex).imag;
            }
            if kb == 3 {
                br = (b as PyComplex).real;
                bi = (b as PyComplex).imag;
            }
            if ka == 3 and kb == 3 {
                return ar == br and ai == bi;
            }
            if ka == 3 {
                return ai == 0.0 and const_equal(PyFloat(t="float", val=ar), b);
            }
            return bi == 0.0 and const_equal(a, PyFloat(t="float", val=br));
        }
        if ka == 2 and kb == 2 {
            return (a as PyFloat).val == (b as PyFloat).val;
        }
        if ka == 2 {
            return float_int_equal((a as PyFloat).val, int_of(b));
        }
        return float_int_equal((b as PyFloat).val, int_of(a));
    }
    if isinstance(a, PyStr) and isinstance(b, PyStr) {
        return a.val == b.val;
    }
    if isinstance(a, PyBytes) and isinstance(b, PyBytes) {
        if len(a.val) != len(b.val) {
            return False;
        }
        for k in range(len(a.val)) {
            if a.val[k] != b.val[k] {
                return False;
            }
        }
        return True;
    }
    if isinstance(a, PyTuple) and isinstance(b, PyTuple) {
        if len(a.items) != len(b.items) {
            return False;
        }
        for k in range(len(a.items)) {
            if not const_equal(a.items[k], b.items[k]) {
                return False;
            }
        }
        return True;
    }
    if isinstance(a, PyNoneType) and isinstance(b, PyNoneType) {
        return True;
    }
    if isinstance(a, PyEllipsis) and isinstance(b, PyEllipsis) {
        return True;
    }
    if isinstance(a, PySet) and isinstance(b, PySet) {
        av = list(a.items.values());
        bv = list(b.items.values());
        if len(av) != len(bv) {
            return False;
        }
        for x in av {
            found = False;
            for y in bv {
                if const_equal(x, y) {
                    found = True;
                    break;
                }
            }
            if not found {
                return False;
            }
        }
        return True;
    }
    return False;
}

def make_frozenset(values: list[PyObj]) -> PyObj | None {
    unique: list[PyObj] = [];
    for v in values {
        dup = False;
        for u in unique {
            if const_equal(u, v) {
                dup = True;
                break;
            }
        }
        if not dup {
            unique.append(v);
        }
    }
    frozen = PySet(t="frozenset", items={}, order=[], frozen=True);
    for v in unique {
        if is_error(frozen.set_add(v)) {
            return None;
        }
    }
    return frozen;
}
