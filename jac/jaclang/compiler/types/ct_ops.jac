import math;
import from jaclang.compiler.types.ct_int {
    MAG_MASK,
    MAG_SHIFT,
    MAX_STR_DIGITS,
    mag_add,
    mag_add_small,
    mag_bit_length,
    mag_cmp,
    mag_divmod,
    mag_from_int,
    mag_low_bits_nonzero,
    mag_mul,
    mag_parse_digits,
    mag_shl,
    mag_shr,
    mag_sub,
    mag_to_int,
    mag_to_pow2_str,
    twos_limbs,
    twos_to_signed
}
import from jaclang.compiler.types.ct_value {
    CT_FALSE,
    CT_NONE,
    CT_TRUE,
    CtBool,
    CtBytes,
    CtDeferred,
    CtDict,
    CtEnumMember,
    CtError,
    CtFloat,
    CtFunc,
    CtInt,
    CtList,
    CtNone,
    CtRange,
    CtRecord,
    CtSet,
    CtStr,
    CtTuple,
    CtType,
    CtValue,
    CtView,
    CtDeferredSignal,
    CtRaise,
    as_ct_int,
    bytes_has,
    ct_eq,
    ct_exc,
    ct_exc_value,
    ct_is_unhashable,
    ct_iter,
    dict_key_of,
    set_key_of,
    ct_len,
    ct_repr,
    ct_same_or_eq,
    ct_str,
    ct_truthy,
    ct_type_name,
    dict_copy,
    dict_get,
    dict_set,
    float_floor,
    float_to_ct_int,
    int_cmp,
    int_decimal,
    int_float_cmp,
    int_sign_mag,
    mk_bool,
    mk_bytes,
    mk_float,
    mk_int,
    mk_int_mag,
    mk_list,
    mk_set,
    mk_str,
    mk_tuple,
    range_len,
    set_add,
    set_has,
    view_items_set
}

glob CT_POW_BITS_LIMIT: int = 4000000,
     CT_SHIFT_LIMIT: int = 4000000,
     CT_INDEX_MAX: int = 9223372036854775807,
     CT_OP_SYMBOLS: dict[str, str] = {
         "PLUS": "+",
         "MINUS": "-",
         "STAR_MUL": "*",
         "DIV": "/",
         "FLOOR_DIV": "//",
         "MOD": "%",
         "STAR_POW": "**",
         "BW_AND": "&",
         "BW_OR": "|",
         "BW_XOR": "^",
         "LSHIFT": "<<",
         "RSHIFT": ">>",
         "LT": "<",
         "LTE": "<=",
         "GT": ">",
         "GTE": ">="
     };

def ct_symbol(opn: str) -> str {
    return CT_OP_SYMBOLS.get(opn, opn);
}

def int_neg(a: CtInt) -> CtInt {
    if not a.mag {
        return CtInt(small=-a.small);
    }
    return mk_int_mag(not a.neg, a.mag);
}

def int_abs(a: CtInt) -> CtInt {
    if not a.mag {
        return CtInt(small=abs(a.small));
    }
    return CtInt(mag=a.mag, neg=False);
}

def int_is_zero(a: CtInt) -> bool {
    return not a.mag and a.small == 0;
}

def int_is_neg(a: CtInt) -> bool {
    return a.neg if a.mag else a.small < 0;
}

def _signed_add(an: bool, am: list[int], bn: bool, bm: list[int]) -> CtInt {
    if an == bn {
        return mk_int_mag(an, mag_add(am, bm));
    }
    c = mag_cmp(am, bm);
    if c == 0 {
        return CtInt(small=0);
    }
    if c > 0 {
        return mk_int_mag(an, mag_sub(am, bm));
    }
    return mk_int_mag(bn, mag_sub(bm, am));
}

def int_add(a: CtInt, b: CtInt) -> CtInt {
    if not a.mag and not b.mag {
        return mk_int(a.small + b.small);
    }
    (an, am) = int_sign_mag(a);
    (bn, bm) = int_sign_mag(b);
    return _signed_add(an, am, bn, bm);
}

def int_sub(a: CtInt, b: CtInt) -> CtInt {
    if not a.mag and not b.mag {
        return mk_int(a.small - b.small);
    }
    (an, am) = int_sign_mag(a);
    (bn, bm) = int_sign_mag(b);
    return _signed_add(an, am, not bn, bm);
}

def int_mul(a: CtInt, b: CtInt) -> CtInt {
    if not a.mag and not b.mag {
        x = a.small;
        y = b.small;
        if x == 0 or y == 0 {
            return CtInt(small=0);
        }
        if abs(x) <= 4611686018427387903 // abs(y) {
            return CtInt(small=x * y);
        }
    }
    (an, am) = int_sign_mag(a);
    (bn, bm) = int_sign_mag(b);
    return mk_int_mag(an != bn, mag_mul(am, bm));
}

def int_divmod(a: CtInt, b: CtInt) -> tuple[CtInt, CtInt] {
    if int_is_zero(b) {
        raise ct_exc("ZeroDivisionError", "division by zero");
    }
    if not a.mag and not b.mag {
        return (mk_int(a.small // b.small), mk_int(a.small % b.small));
    }
    (an, am) = int_sign_mag(a);
    (bn, bm) = int_sign_mag(b);
    (qm, rm) = mag_divmod(am, bm);
    if an == bn {
        return (mk_int_mag(False, qm), mk_int_mag(bn, rm));
    }
    if not rm {
        return (mk_int_mag(True, qm), CtInt(small=0));
    }
    return (mk_int_mag(True, mag_add_small(qm, 1)), mk_int_mag(bn, mag_sub(bm, rm)));
}

def int_bit_length(a: CtInt) -> int {
    (_, m) = int_sign_mag(a);
    return mag_bit_length(m);
}

def int_small_index(a: CtInt) -> int {
    if a.mag {
        raise ct_exc("IndexError", "cannot fit 'int' into an index-sized integer");
    }
    return a.small;
}

def int_pow(a: CtInt, b: CtInt) -> CtValue {
    if int_is_neg(b) {
        return float_pow(int_to_float(a), int_to_float(b));
    }
    if not a.mag and a.small in (0, 1) {
        return a if not int_is_zero(b) else CtInt(small=1);
    }
    if not a.mag and a.small == -1 {
        (_, bm) = int_sign_mag(b);
        return CtInt(small=-1 if bm and bm[0] & 1 else 1);
    }
    if b.mag {
        raise CtError("comptime integer power result is too large");
    }
    e = b.small;
    if int_bit_length(a) * e > CT_POW_BITS_LIMIT {
        raise CtError("comptime integer power result is too large");
    }
    result = CtInt(small=1);
    base = a;
    while e > 0 {
        if e & 1 {
            result = int_mul(result, base);
        }
        e = e >> 1;
        if e {
            base = int_mul(base, base);
        }
    }
    return result;
}

def int_lshift(a: CtInt, b: CtInt) -> CtInt {
    if int_is_neg(b) {
        raise ct_exc("ValueError", "negative shift count");
    }
    if int_is_zero(a) {
        return a;
    }
    if b.mag or b.small > CT_SHIFT_LIMIT {
        raise CtError("comptime shift count is too large");
    }
    if not a.mag and b.small < 62 and abs(a.small) < (1 << (61 - b.small)) {
        return CtInt(small=a.small << b.small);
    }
    (an, am) = int_sign_mag(a);
    return mk_int_mag(an, mag_shl(am, b.small));
}

def int_rshift(a: CtInt, b: CtInt) -> CtInt {
    if int_is_neg(b) {
        raise ct_exc("ValueError", "negative shift count");
    }
    if b.mag {
        return CtInt(small=-1 if int_is_neg(a) else 0);
    }
    if not a.mag {
        if b.small >= 63 {
            return CtInt(small=-1 if a.small < 0 else 0);
        }
        return CtInt(small=a.small >> b.small);
    }
    if not a.neg {
        return mk_int_mag(False, mag_shr(a.mag, b.small));
    }
    lowered = mag_shr(a.mag, b.small);
    if mag_low_bits_nonzero(a.mag, b.small) {
        lowered = mag_add_small(lowered, 1);
    }
    return mk_int_mag(True, lowered);
}

def int_invert(a: CtInt) -> CtInt {
    return int_sub(int_neg(a), CtInt(small=1));
}

def int_bitop(a: CtInt, b: CtInt, op: str) -> CtInt {
    if not a.mag and not b.mag {
        if op == "&" {
            return CtInt(small=a.small & b.small);
        }
        if op == "|" {
            return CtInt(small=a.small | b.small);
        }
        return CtInt(small=a.small ^ b.small);
    }
    (an, am) = int_sign_mag(a);
    (bn, bm) = int_sign_mag(b);
    width = max(len(am), len(bm)) + 1;
    at = twos_limbs(an, am, width);
    bt = twos_limbs(bn, bm, width);
    out: list[int] = [];
    for i in range(width) {
        if op == "&" {
            out.append(at[i] & bt[i]);
        } elif op == "|" {
            out.append(at[i] | bt[i]);
        } else {
            out.append(at[i] ^ bt[i]);
        }
    }
    if op == "&" {
        rn = an and bn;
    } elif op == "|" {
        rn = an or bn;
    } else {
        rn = an != bn;
    }
    (neg, mag) = twos_to_signed(out, rn);
    return mk_int_mag(neg, mag);
}

def int_to_float(a: CtInt) -> float {
    if not a.mag {
        return float(a.small);
    }
    n = mag_bit_length(a.mag);
    if n > 1024 {
        raise ct_exc("OverflowError", "int too large to convert to float");
    }
    shift = n - 55;
    q = mag_to_int(mag_shr(a.mag, shift));
    if mag_low_bits_nonzero(a.mag, shift) {
        q = q | 1;
    }
    corrections = [0, -1, -2, 1, 0, -1, 2, 1];
    q += corrections[q & 7];
    if n == 1024 and q >= 36028797018963968 {
        raise ct_exc("OverflowError", "int too large to convert to float");
    }
    out = math.ldexp(float(q), shift);
    return -out if a.neg else out;
}

def int_truediv(a: CtInt, b: CtInt) -> float {
    if int_is_zero(b) {
        raise ct_exc("ZeroDivisionError", "division by zero");
    }
    if not a.mag
        and not b.mag
        and abs(a.small) <= 9007199254740992
        and abs(b.small) <= 9007199254740992 {
        return float(a.small) / float(b.small);
    }
    (an, am) = int_sign_mag(a);
    (bn, bm) = int_sign_mag(b);
    negate = an != bn;
    if not am {
        return -0.0 if negate else 0.0;
    }
    a_bits = mag_bit_length(am);
    b_bits = mag_bit_length(bm);
    diff = a_bits - b_bits;
    if diff > 1024 {
        raise ct_exc("OverflowError", "integer division result too large for a float");
    }
    if diff < -1075 {
        return -0.0 if negate else 0.0;
    }
    shift = max(diff, -1021) - 55;
    inexact = False;
    if shift <= 0 {
        x = mag_shl(am, -shift);
    } else {
        x = mag_shr(am, shift);
        inexact = mag_low_bits_nonzero(am, shift);
    }
    (qm, rm) = mag_divmod(x, bm);
    if rm {
        inexact = True;
    }
    q = mag_to_int(qm);
    x_bits = mag_bit_length(qm);
    extra_bits = max(x_bits, -1021 - shift) - 53;
    mask = 1 << (extra_bits - 1);
    low = q | (1 if inexact else 0);
    if (low & mask) and (low & (3 * mask - 1)) {
        q += mask;
    }
    q = q & ~(2 * mask - 1);
    dq = float(q);
    if shift + x_bits >= 1024
        and (shift + x_bits > 1024 or dq == math.ldexp(1.0, x_bits)) {
        raise ct_exc("OverflowError", "integer division result too large for a float");
    }
    result = math.ldexp(dq, shift);
    if result - result != 0.0 {
        raise ct_exc("OverflowError", "integer division result too large for a float");
    }
    return -result if negate else result;
}

def float_divmod(vx: float, wx: float) -> tuple[float, float] {
    if wx == 0.0 {
        raise ct_exc("ZeroDivisionError", "division by zero");
    }
    mod = c_fmod(vx, wx);
    div = (vx - mod) / wx;
    if mod != 0.0 {
        if (wx < 0.0) != (mod < 0.0) {
            mod += wx;
            div -= 1.0;
        }
    } else {
        mod = math.copysign(0.0, wx);
    }
    if div != 0.0 {
        floordiv = float_floor(div);
        if div - floordiv > 0.5 {
            floordiv += 1.0;
        }
    } else {
        floordiv = math.copysign(0.0, vx / wx);
    }
    return (floordiv, mod);
}

def c_fmod(vx: float, wx: float) -> float {
    if vx != vx or wx != wx or vx - vx != 0.0 {
        return float("nan");
    }
    return math.fmod(vx, wx);
}

def float_pow(v: float, w: float) -> CtValue {
    if w == 0.0 {
        return mk_float(1.0);
    }
    if v != v {
        return mk_float(v);
    }
    if w != w {
        return mk_float(1.0 if v == 1.0 else w);
    }
    if w - w != 0.0 {
        av = abs(v);
        if av == 1.0 {
            return mk_float(1.0);
        }
        if (w > 0.0) == (av > 1.0) {
            return mk_float(abs(w));
        }
        return mk_float(0.0);
    }
    w_odd = _float_is_odd_int(w);
    if v - v != 0.0 {
        if v > 0.0 {
            return mk_float(v if w > 0.0 else 0.0);
        }
        if w > 0.0 {
            return mk_float(v if w_odd else -v);
        }
        return mk_float(-0.0 if w_odd else 0.0);
    }
    if v == 0.0 {
        if w < 0.0 {
            raise ct_exc("ZeroDivisionError", "zero to a negative power");
        }
        return mk_float(v if w_odd else 0.0);
    }
    negate = False;
    if v < 0.0 {
        if w != float_floor(w) {
            raise CtError(
                "a negative number raised to a fractional power is complex, which comptime code does not model"
            );
        }
        v = -v;
        negate = w_odd;
    }
    if v == 1.0 {
        return mk_float(-1.0 if negate else 1.0);
    }
    try {
        ix = math.pow(v, w);
    } except OverflowError {
        raise ct_exc("OverflowError", "(34, 'Numerical result out of range')");
    }
    if ix - ix != 0.0 {
        raise ct_exc("OverflowError", "(34, 'Numerical result out of range')");
    }
    return mk_float(-ix if negate else ix);
}

def _float_is_odd_int(w: float) -> bool {
    if w != float_floor(w) or abs(w) >= 9007199254740992.0 {
        return False;
    }
    return int(w) % 2 != 0;
}

def to_float_operand(v: CtValue) -> (float | None) {
    if isinstance(v, CtFloat) {
        return v.value;
    }
    iv = as_ct_int(v);
    if iv is not None {
        return int_to_float(iv);
    }
    return None;
}

def _unsupported(sym: str, l: CtValue, r: CtValue) -> CtRaise {
    return ct_exc(
        "TypeError",
        f"unsupported operand type(s) for {sym}: '{ct_type_name(l)}' and '{ct_type_name(
            r
        )}'"
    );
}

def _repeat_count(n: CtInt) -> int {
    if n.mag {
        raise ct_exc("OverflowError", "cannot fit 'int' into an index-sized integer");
    }
    return max(n.small, 0);
}

def ct_binop(sym: str, l: CtValue, r: CtValue) -> CtValue {
    if isinstance(l, CtDeferred) or isinstance(r, CtDeferred) {
        raise CtDeferredSignal();
    }
    li = as_ct_int(l);
    ri = as_ct_int(r);
    if li is not None and ri is not None {
        if isinstance(l, CtBool) and isinstance(r, CtBool) and sym in ("&", "|", "^") {
            if sym == "&" {
                return mk_bool(l.value and r.value);
            }
            if sym == "|" {
                return mk_bool(l.value or r.value);
            }
            return mk_bool(l.value != r.value);
        }
        return _int_binop(sym, li, ri, l, r);
    }
    if (isinstance(l, CtFloat) or li is not None)
        and (isinstance(r, CtFloat) or ri is not None) {
        return _float_binop(sym, l, r);
    }
    if sym == "+" {
        if isinstance(l, CtStr) and isinstance(r, CtStr) {
            return mk_str(l.value + r.value);
        }
        if isinstance(l, CtBytes) and isinstance(r, CtBytes) {
            return mk_bytes(l.value + r.value);
        }
        if isinstance(l, CtList) and isinstance(r, CtList) {
            return mk_list(l.items + r.items);
        }
        if isinstance(l, CtTuple) and isinstance(r, CtTuple) {
            return mk_tuple(l.items + r.items);
        }
        if isinstance(l, CtStr) {
            raise ct_exc(
                "TypeError",
                f"can only concatenate str (not \"{ct_type_name(r)}\") to str"
            );
        }
        if isinstance(l, CtList) {
            raise ct_exc(
                "TypeError",
                f"can only concatenate list (not \"{ct_type_name(r)}\") to list"
            );
        }
        if isinstance(l, CtTuple) {
            raise ct_exc(
                "TypeError",
                f"can only concatenate tuple (not \"{ct_type_name(r)}\") to tuple"
            );
        }
        if isinstance(l, CtBytes) {
            raise ct_exc("TypeError", f"can't concat {ct_type_name(r)} to bytes");
        }
    }
    if sym == "*" {
        if isinstance(l, (CtStr, CtBytes, CtList, CtTuple)) and ri is not None {
            return _repeat(l, _repeat_count(ri));
        }
        if isinstance(r, (CtStr, CtBytes, CtList, CtTuple)) and li is not None {
            return _repeat(r, _repeat_count(li));
        }
        if isinstance(l, (CtStr, CtBytes, CtList, CtTuple))
            or isinstance(r, (CtStr, CtBytes, CtList, CtTuple)) {
            seq = l if isinstance(l, (CtStr, CtBytes, CtList, CtTuple)) else r;
            other = r if seq is l else l;
            raise ct_exc(
                "TypeError",
                f"can't multiply sequence by non-int of type '{ct_type_name(other)}'"
            );
        }
    }
    if sym == "|" and isinstance(l, CtDict) and isinstance(r, CtDict) {
        out = dict_copy(l);
        for (i, k) in enumerate(r.keys) {
            dict_set(out, k, r.vals[i]);
        }
        return out;
    }
    if sym in ("|", "&", "-", "^")
        and isinstance(l, (CtSet, CtView))
        and isinstance(r, (CtSet, CtView)) {
        if isinstance(l, CtView) or isinstance(r, CtView) {
            ls = l if isinstance(l, CtSet) else view_items_set(l);
            rs = r if isinstance(r, CtSet) else view_items_set(r);
            return set_algebra(sym, ls, rs, False);
        }
        return set_algebra(sym, l, r, l.frozen);
    }
    raise _unsupported(sym, l, r);
}

def set_algebra(sym: str, l: CtSet, r: CtSet, frozen: bool) -> CtSet {
    out = mk_set([], frozen=frozen);
    if sym == "|" {
        for item in l.items {
            set_add(out, item);
        }
        for item in r.items {
            set_add(out, item);
        }
    } elif sym == "&" {
        (small, big) = (l, r) if len(l.items) <= len(r.items) else (r, l);
        for item in small.items {
            if set_has(big, item) {
                set_add(out, item);
            }
        }
    } elif sym == "-" {
        for item in l.items {
            if not set_has(r, item) {
                set_add(out, item);
            }
        }
    } else {
        for item in l.items {
            if not set_has(r, item) {
                set_add(out, item);
            }
        }
        for item in r.items {
            if not set_has(l, item) {
                set_add(out, item);
            }
        }
    }
    return out;
}

def _repeat(seq: CtValue, n: int) -> CtValue {
    if isinstance(seq, CtStr) {
        if n and len(seq.value) * n > 100000000 {
            raise CtError("comptime sequence repetition is too large");
        }
        return mk_str(seq.value * n);
    }
    if isinstance(seq, CtBytes) {
        return mk_bytes(seq.value * n);
    }
    if isinstance(seq, CtList) {
        if n and len(seq.items) * n > 100000000 {
            raise CtError("comptime sequence repetition is too large");
        }
        return mk_list(seq.items * n);
    }
    if isinstance(seq, CtTuple) {
        return mk_tuple(seq.items * n);
    }
    return seq;
}

def _int_binop(sym: str, a: CtInt, b: CtInt, l: CtValue, r: CtValue) -> CtValue {
    if sym == "+" {
        return int_add(a, b);
    }
    if sym == "-" {
        return int_sub(a, b);
    }
    if sym == "*" {
        return int_mul(a, b);
    }
    if sym == "/" {
        return mk_float(int_truediv(a, b));
    }
    if sym == "//" {
        return int_divmod(a, b)[0];
    }
    if sym == "%" {
        return int_divmod(a, b)[1];
    }
    if sym == "**" {
        return int_pow(a, b);
    }
    if sym in ("&", "|", "^") {
        return int_bitop(a, b, sym);
    }
    if sym == "<<" {
        return int_lshift(a, b);
    }
    if sym == ">>" {
        return int_rshift(a, b);
    }
    raise _unsupported(sym, l, r);
}

def _float_binop(sym: str, l: CtValue, r: CtValue) -> CtValue {
    if sym in ("&", "|", "^", "<<", ">>") {
        raise _unsupported(sym, l, r);
    }
    x = to_float_operand(l);
    y = to_float_operand(r);
    if x is None or y is None {
        raise _unsupported(sym, l, r);
    }
    if sym == "+" {
        return mk_float(x + y);
    }
    if sym == "-" {
        return mk_float(x - y);
    }
    if sym == "*" {
        return mk_float(x * y);
    }
    if sym == "/" {
        if y == 0.0 {
            raise ct_exc("ZeroDivisionError", "division by zero");
        }
        return mk_float(x / y);
    }
    if sym == "//" {
        return mk_float(float_divmod(x, y)[0]);
    }
    if sym == "%" {
        return mk_float(float_divmod(x, y)[1]);
    }
    if sym == "**" {
        return float_pow(x, y);
    }
    raise _unsupported(sym, l, r);
}

def ct_unary(op: str, v: CtValue) -> CtValue {
    if isinstance(v, CtDeferred) {
        raise CtDeferredSignal();
    }
    if op == "not" {
        return mk_bool(not ct_truthy(v));
    }
    iv = as_ct_int(v);
    if iv is not None {
        if op == "-" {
            return int_neg(iv);
        }
        if op == "+" {
            return iv;
        }
        if op == "~" {
            return int_invert(iv);
        }
    }
    if isinstance(v, CtFloat) {
        if op == "-" {
            return mk_float(-v.value);
        }
        if op == "+" {
            return v;
        }
    }
    raise ct_exc("TypeError", f"bad operand type for unary {op}: '{ct_type_name(v)}'");
}

def _num_cmp(l: CtValue, r: CtValue) -> (int | None) {
    li = as_ct_int(l);
    ri = as_ct_int(r);
    if li is not None and ri is not None {
        return int_cmp(li, ri);
    }
    if isinstance(l, CtFloat) and isinstance(r, CtFloat) {
        if l.value != l.value or r.value != r.value {
            return 2;
        }
        if l.value < r.value {
            return -1;
        }
        return 1 if l.value > r.value else 0;
    }
    if isinstance(l, CtFloat) and ri is not None {
        c = int_float_cmp(ri, l.value);
        return c if c == 2 else -c;
    }
    if isinstance(r, CtFloat) and li is not None {
        return int_float_cmp(li, r.value);
    }
    return None;
}

def _apply_cmp(sym: str, c: int) -> bool {
    if c == 2 {
        return False;
    }
    if sym == "<" {
        return c < 0;
    }
    if sym == "<=" {
        return c <= 0;
    }
    if sym == ">" {
        return c > 0;
    }
    return c >= 0;
}

def ct_order(sym: str, l: CtValue, r: CtValue) -> bool {
    if isinstance(l, CtDeferred) or isinstance(r, CtDeferred) {
        raise CtDeferredSignal();
    }
    c = _num_cmp(l, r);
    if c is not None {
        return _apply_cmp(sym, c);
    }
    if isinstance(l, CtStr) and isinstance(r, CtStr) {
        if l.value == r.value {
            return _apply_cmp(sym, 0);
        }
        return _apply_cmp(sym, -1 if l.value < r.value else 1);
    }
    if isinstance(l, CtBytes) and isinstance(r, CtBytes) {
        if l.value == r.value {
            return _apply_cmp(sym, 0);
        }
        return _apply_cmp(sym, -1 if l.value < r.value else 1);
    }
    if (isinstance(l, CtList) and isinstance(r, CtList))
        or (isinstance(l, CtTuple) and isinstance(r, CtTuple)) {
        n = min(len(l.items), len(r.items));
        for i in range(n) {
            if not ct_same_or_eq(l.items[i], r.items[i]) {
                return ct_order(sym, l.items[i], r.items[i]);
            }
        }
        la = len(l.items);
        lb = len(r.items);
        return _apply_cmp(sym, -1 if la < lb else (1 if la > lb else 0));
    }
    if isinstance(l, (CtSet, CtView))
        and isinstance(r, (CtSet, CtView))
        and not (isinstance(l, CtView) and l.kind == "values")
        and not (isinstance(r, CtView) and r.kind == "values") {
        ls = l if isinstance(l, CtSet) else view_items_set(l);
        rs = r if isinstance(r, CtSet) else view_items_set(r);
        if sym in ("<", "<=") {
            if sym == "<" and len(ls.items) >= len(rs.items) {
                return False;
            }
            return _subset(ls, rs);
        }
        if sym == ">" and len(ls.items) <= len(rs.items) {
            return False;
        }
        return _subset(rs, ls);
    }
    raise ct_exc(
        "TypeError",
        f"'{sym}' not supported between instances of '{ct_type_name(l)}' and '{ct_type_name(
            r
        )}'"
    );
}

def _subset(a: CtSet, b: CtSet) -> bool {
    if len(a.items) > len(b.items) {
        return False;
    }
    for item in a.items {
        if not set_has(b, item) {
            return False;
        }
    }
    return True;
}

def ct_lt(a: CtValue, b: CtValue) -> bool {
    return ct_order("<", a, b);
}

def ct_contains(container: CtValue, item: CtValue) -> bool {
    if isinstance(container, CtDeferred) or isinstance(item, CtDeferred) {
        raise CtDeferredSignal();
    }
    if isinstance(container, CtStr) {
        if not isinstance(item, CtStr) {
            raise ct_exc(
                "TypeError",
                f"'in <string>' requires string as left operand, not {ct_type_name(
                    item
                )}"
            );
        }
        return item.value in container.value;
    }
    if isinstance(container, CtBytes) {
        iv = as_ct_int(item);
        if iv is not None {
            n = iv.small if not iv.mag else -1;
            if n < 0 or n > 255 {
                raise ct_exc("ValueError", "byte must be in range(0, 256)");
            }
            return bytes_has(container.value, n);
        }
        if isinstance(item, CtBytes) {
            return item.value in container.value;
        }
        raise ct_exc(
            "TypeError", f"a bytes-like object is required, not '{ct_type_name(item)}'"
        );
    }
    if isinstance(container, (CtList, CtTuple)) {
        for x in container.items {
            if ct_same_or_eq(x, item) {
                return True;
            }
        }
        return False;
    }
    if isinstance(container, CtDict) {
        return dict_key_of(item) in container.index;
    }
    if isinstance(container, CtSet) {
        return set_key_of(item) in container.index;
    }
    if isinstance(container, CtRange) {
        iv2 = as_ct_int(item);
        if iv2 is not None {
            if iv2.mag {
                return False;
            }
            n2 = iv2.small;
            r = container;
            if r.step > 0 {
                if n2 < r.start or n2 >= r.stop {
                    return False;
                }
            } elif n2 > r.start or n2 <= r.stop {
                return False;
            }
            return (n2 - r.start) % r.step == 0;
        }
        for x in ct_iter(container) {
            if ct_eq(x, item) {
                return True;
            }
        }
        return False;
    }
    if isinstance(container, CtView) {
        if container.kind == "keys" {
            return dict_key_of(item) in container.source.index;
        }
        for x in ct_iter(container) {
            if ct_same_or_eq(x, item) {
                return True;
            }
        }
        return False;
    }
    raise ct_exc(
        "TypeError",
        f"argument of type '{ct_type_name(container)}' is not a container or iterable"
    );
}

def ct_is(l: CtValue, r: CtValue) -> bool {
    if isinstance(l, CtNone) or isinstance(r, CtNone) {
        return isinstance(l, CtNone) and isinstance(r, CtNone);
    }
    if isinstance(l, CtBool) or isinstance(r, CtBool) {
        return isinstance(l, CtBool) and isinstance(r, CtBool) and l.value == r.value;
    }
    if isinstance(l, (CtType, CtEnumMember, CtFunc)) {
        return ct_eq(l, r);
    }
    if isinstance(l, CtInt) and isinstance(r, CtInt) {
        if not l.mag and not r.mag and -5 <= l.small and l.small <= 256 {
            return l.small == r.small;
        }
    }
    return l is r;
}

def ct_compare(sym: str, l: CtValue, r: CtValue) -> bool {
    if sym == "==" {
        return ct_eq(l, r);
    }
    if sym == "!=" {
        return not ct_eq(l, r);
    }
    if sym == "in" {
        return ct_contains(r, l);
    }
    if sym == "not in" {
        return not ct_contains(r, l);
    }
    if sym == "is" {
        return ct_is(l, r);
    }
    if sym == "is not" {
        return not ct_is(l, r);
    }
    return ct_order(sym, l, r);
}

def _index_of(base: CtValue, key: CtValue, what: str) -> int {
    kv = as_ct_int(key);
    if kv is None {
        tn = ct_type_name(base);
        if isinstance(base, CtStr) {
            raise ct_exc(
                "TypeError",
                f"string indices must be integers, not '{ct_type_name(key)}'"
            );
        }
        noun = "byte" if isinstance(base, CtBytes) else tn;
        raise ct_exc(
            "TypeError",
            f"{noun} indices must be integers or slices, not {ct_type_name(key)}"
        );
    }
    if kv.mag {
        raise ct_exc("IndexError", "cannot fit 'int' into an index-sized integer");
    }
    n = ct_len(base);
    idx = kv.small;
    if idx < 0 {
        idx += n;
    }
    if idx < 0 or idx >= n {
        raise ct_exc("IndexError", what);
    }
    return idx;
}

def ct_getitem(base: CtValue, key: CtValue) -> CtValue {
    if isinstance(base, CtDeferred) or isinstance(key, CtDeferred) {
        raise CtDeferredSignal();
    }
    if isinstance(base, CtList) {
        return base.items[_index_of(base, key, "list index out of range")];
    }
    if isinstance(base, CtTuple) {
        return base.items[_index_of(base, key, "tuple index out of range")];
    }
    if isinstance(base, CtStr) {
        return mk_str(base.value[_index_of(base, key, "string index out of range")]);
    }
    if isinstance(base, CtBytes) {
        return mk_int(base.value[_index_of(base, key, "index out of range")]);
    }
    if isinstance(base, CtRange) {
        i = _index_of(base, key, "range object index out of range");
        return mk_int(base.start + i * base.step);
    }
    if isinstance(base, CtDict) {
        got = dict_get(base, key);
        if got is None {
            raise ct_exc_value("KeyError", key);
        }
        return got;
    }
    raise ct_exc("TypeError", f"'{ct_type_name(base)}' object is not subscriptable");
}

def _slice_bound(v: (CtValue | None)) -> (int | None) {
    if v is None or isinstance(v, CtNone) {
        return None;
    }
    iv = as_ct_int(v);
    if iv is None {
        raise ct_exc(
            "TypeError",
            "slice indices must be integers or None or have an __index__ method"
        );
    }
    if iv.mag {
        return -CT_INDEX_MAX - 1 if iv.neg else CT_INDEX_MAX;
    }
    return iv.small;
}

def slice_indices(
    length: int, lo_v: (CtValue | None), hi_v: (CtValue | None), st_v: (CtValue | None)
) -> tuple[int, int, int, int] {
    step = _slice_bound(st_v);
    if step is None {
        step = 1;
    }
    if step == 0 {
        raise ct_exc("ValueError", "slice step cannot be zero");
    }
    lo = _slice_bound(lo_v);
    hi = _slice_bound(hi_v);
    if lo is None {
        start = length - 1 if step < 0 else 0;
    } else {
        start = lo;
        if start < 0 {
            start += length;
            if start < 0 {
                start = -1 if step < 0 else 0;
            }
        } elif start >= length {
            start = length - 1 if step < 0 else length;
        }
    }
    if hi is None {
        stop = -1 if step < 0 else length;
    } else {
        stop = hi;
        if stop < 0 {
            stop += length;
            if stop < 0 {
                stop = -1 if step < 0 else 0;
            }
        } elif stop >= length {
            stop = length - 1 if step < 0 else length;
        }
    }
    count = 0;
    if step < 0 {
        if stop < start {
            count = (start - stop - 1) // (-step) + 1;
        }
    } elif start < stop {
        count = (stop - start - 1) // step + 1;
    }
    return (start, stop, step, count);
}

def ct_getslice(
    base: CtValue, lo: (CtValue | None), hi: (CtValue | None), st: (CtValue | None)
) -> CtValue {
    if isinstance(base, CtDeferred) {
        raise CtDeferredSignal();
    }
    if not isinstance(base, (CtList, CtTuple, CtStr, CtBytes, CtRange)) {
        raise ct_exc(
            "TypeError", f"'{ct_type_name(base)}' object is not subscriptable"
        );
    }
    (start, _, step, count) = slice_indices(ct_len(base), lo, hi, st);
    if isinstance(base, CtRange) {
        new_start = base.start + start * base.step;
        new_step = base.step * step;
        return CtRange(
            start=new_start, stop=new_start + count * new_step, step=new_step
        );
    }
    idxs: list[int] = [];
    cur = start;
    for _ in range(count) {
        idxs.append(cur);
        cur += step;
    }
    if isinstance(base, CtStr) {
        return mk_str("".join([base.value[i] for i in idxs]));
    }
    if isinstance(base, CtBytes) {
        return mk_bytes(bytes([base.value[i] for i in idxs]));
    }
    picked: list[CtValue] = [base.items[i] for i in idxs];
    return mk_list(picked) if isinstance(base, CtList) else mk_tuple(picked);
}

def ct_setitem(base: CtValue, key: CtValue, val: CtValue) {
    if isinstance(base, CtList) {
        base.items[_index_of(base, key, "list assignment index out of range")] = val;
        return;
    }
    if isinstance(base, CtDict) {
        dict_set(base, key, val);
        return;
    }
    if isinstance(base, CtDeferred) {
        raise CtDeferredSignal();
    }
    raise ct_exc(
        "TypeError", f"'{ct_type_name(base)}' object does not support item assignment"
    );
}

def ct_int_parse(text: str, base: int) -> (CtInt | None) {
    s = text.strip();
    neg = False;
    if s.startswith("-") or s.startswith("+") {
        neg = s[0] == "-";
        s = s[1:];
    }
    if not s {
        return None;
    }
    low = s.lower();
    if base == 0 {
        if low.startswith("0x") {
            base = 16;
            s = s[2:];
        } elif low.startswith("0o") {
            base = 8;
            s = s[2:];
        } elif low.startswith("0b") {
            base = 2;
            s = s[2:];
        } else {
            base = 10;
            stripped = s.replace("_", "");
            if len(stripped) > 1 and stripped.startswith("0") and stripped.strip("0") {
                return None;
            }
        }
        if base != 10 and s.startswith("_") {
            s = s[1:];
        }
    } elif (base == 16 and low.startswith("0x"))
        or (base == 8 and low.startswith("0o"))
        or (base == 2 and low.startswith("0b")) {
        s = s[2:];
        if s.startswith("_") {
            s = s[1:];
        }
    }
    if not s or s.startswith("_") or s.endswith("_") or "__" in s {
        return None;
    }
    digits = s.replace("_", "");
    if base == 10 and len(digits) > MAX_STR_DIGITS {
        raise ct_exc(
            "ValueError",
            f"Exceeds the limit ({MAX_STR_DIGITS} digits) for integer string conversion: value has {len(
                digits
            )} digits; use sys.set_int_max_str_digits() to increase the limit"
        );
    }
    mag = mag_parse_digits(digits, base);
    if mag is None {
        return None;
    }
    return mk_int_mag(neg, mag);
}

def ct_int_literal(text: str) -> CtInt {
    got = ct_int_parse(text, 0);
    if got is None {
        raise CtError(f"invalid integer literal {text!r}");
    }
    return got;
}

def int_to_base_str(a: CtInt, base: int) -> str {
    (_, m) = int_sign_mag(a);
    if base == 10 {
        return int_decimal(int_abs(a));
    }
    bits = 4 if base == 16 else (3 if base == 8 else 1);
    return mag_to_pow2_str(m, bits);
}

def int_prefixed(a: CtInt, base: int) -> str {
    prefix = {16: "0x", 8: "0o", 2: "0b"}[base];
    body = int_to_base_str(a, base);
    return ("-" if int_is_neg(a) else "") + prefix + body;
}

def int_round(a: CtInt, ndigits: int) -> CtInt {
    if ndigits >= 0 {
        return a;
    }
    pow10 = int_pow(CtInt(small=10), CtInt(small=-ndigits));
    if not isinstance(pow10, CtInt) {
        return a;
    }
    (q, r) = int_divmod(a, pow10);
    twice = int_add(r, r);
    c = int_cmp(twice, pow10);
    if c > 0 or (c == 0 and not int_is_zero(int_divmod(q, CtInt(small=2))[1])) {
        q = int_add(q, CtInt(small=1));
    }
    return int_mul(q, pow10);
}

def float_round_to_int(f: float) -> CtInt {
    if f != f {
        raise ct_exc("ValueError", "cannot convert float NaN to integer");
    }
    if f - f != 0.0 {
        raise ct_exc("OverflowError", "cannot convert float infinity to integer");
    }
    if abs(f) >= 4503599627370496.0 {
        return float_to_ct_int(f);
    }
    fl = float_floor(f);
    diff = f - fl;
    if diff > 0.5 or (diff == 0.5 and float_floor(fl / 2.0) * 2.0 != fl) {
        fl += 1.0;
    }
    return float_to_ct_int(fl);
}

glob HASH_MODULUS: int = 2305843009213693951,
     HASH_BITS: int = 61;

def _hash_rotl(x: int, bits: int) -> int {
    low = x & ((1 << (HASH_BITS - bits)) - 1);
    return (low << bits) | (x >> (HASH_BITS - bits));
}

def hash_int(a: CtInt) -> int {
    if not a.mag {
        v = a.small;
        neg = v < 0;
        x = abs(v) % HASH_MODULUS;
        x = -x if neg else x;
        return -2 if x == -1 else x;
    }
    x = 0;
    i = len(a.mag) - 1;
    while i >= 0 {
        x = _hash_rotl(x, MAG_SHIFT);
        x += a.mag[i];
        if x >= HASH_MODULUS {
            x -= HASH_MODULUS;
        }
        i -= 1;
    }
    x = -x if a.neg else x;
    return -2 if x == -1 else x;
}

def hash_float(f: float) -> int {
    if f != f {
        raise CtError(
            "hash() of NaN depends on object identity and is not reproducible at compile time"
        );
    }
    if f - f != 0.0 {
        return 314159 if f > 0.0 else -314159;
    }
    (m, e) = math.frexp(f);
    sign = 1;
    if m < 0.0 {
        sign = -1;
        m = -m;
    }
    x = 0;
    while m != 0.0 {
        x = _hash_rotl(x, 28);
        m *= 268435456.0;
        e -= 28;
        y = int(m);
        m -= float(y);
        x += y;
        if x >= HASH_MODULUS {
            x -= HASH_MODULUS;
        }
    }
    e = e % HASH_BITS if e >= 0 else HASH_BITS - 1 - ((-1 - e) % HASH_BITS);
    x = _hash_rotl(x, e) if e else x;
    x = x * sign;
    return -2 if x == -1 else x;
}

glob U64_MASK_MAG: list[int] = [1073741823, 1073741823, 15],
     U64_MOD_MAG: list[int] = [0, 0, 16],
     XXPRIME_1: list[int] = [99338887, 954066630, 9],
     XXPRIME_2: list[int] = [668265295, 181057780, 12],
     XXPRIME_5: list[int] = [374761413, 525577404, 2];

def _u64(m: list[int]) -> list[int] {
    out: list[int] = [];
    for i in range(min(len(m), 3)) {
        out.append(m[i] & U64_MASK_MAG[i]);
    }
    while out and out[-1] == 0 {
        out.pop();
    }
    return out;
}

def _u64_of(v: CtInt) -> list[int] {
    (neg, m) = int_sign_mag(v);
    if not neg or not m {
        return _u64(m);
    }
    return _u64(mag_sub(U64_MOD_MAG, _u64(m)));
}

def _u64_rotl31(m: list[int]) -> list[int] {
    return _u64(mag_add(mag_shl(m, 31), mag_shr(m, 33)));
}

def hash_tuple(items: list[CtValue]) -> CtInt {
    acc = XXPRIME_5;
    for item in items {
        lane = _u64_of(ct_hash(item));
        acc = _u64(mag_add(acc, _u64(mag_mul(lane, XXPRIME_2))));
        acc = _u64_rotl31(acc);
        acc = _u64(mag_mul(acc, XXPRIME_1));
    }
    tail = mag_from_int(len(items) ^ 2870177450013471926);
    acc = _u64(mag_add(acc, tail));
    signed = mk_int_mag(False, acc);
    if mag_bit_length(acc) == 64 {
        signed = mk_int_mag(True, mag_sub(U64_MOD_MAG, acc));
    }
    if not signed.mag and signed.small == -1 {
        return CtInt(small=1546275796);
    }
    return signed;
}

def ct_hash(v: CtValue) -> CtInt {
    if isinstance(v, CtBool) {
        return CtInt(small=1 if v.value else 0);
    }
    if isinstance(v, CtInt) {
        return CtInt(small=hash_int(v));
    }
    if isinstance(v, CtFloat) {
        return CtInt(small=hash_float(v.value));
    }
    if isinstance(v, CtNone) {
        return CtInt(small=4238894112);
    }
    if isinstance(v, CtTuple) {
        return hash_tuple(v.items);
    }
    if ct_is_unhashable(v) {
        raise ct_exc("TypeError", f"unhashable type: '{ct_type_name(v)}'");
    }
    raise CtError(
        f"hash() of a '{ct_type_name(
            v
        )}' value is seeded per process and is not reproducible at compile time"
    );
}
