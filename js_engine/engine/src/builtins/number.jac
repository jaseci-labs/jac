"""
Built-in: Number & Boolean constructors

Number: constructor, static properties/methods, and prototype methods.
Boolean: constructor and prototype methods.
Global helpers: parseInt, parseFloat, isNaN, isFinite.

Bun reference   : bun/src/js/builtins/NumberConstructor.ts
                  JSC NumberPrototype.cpp / NumberConstructor.cpp
                  JSC JSGlobalObjectFunctions.cpp
ECMAScript spec : §21.1 — Number Objects
                  §20.3 — Boolean Objects

Encoding:
  Number object   → JSValue{tag=Object} with KEY_IS_NUMBER_OBJ  = wrapped float JSValue
  Boolean object  → JSValue{tag=Object} with KEY_IS_BOOLEAN_OBJ = wrapped bool JSValue
"""

import from engine.src.runtime.jsvalue {
    JSValue,
    MATH_INF,
    MATH_NEG_INF,
    MATH_NAN,
    js_undefined,
    js_true,
    js_false,
    js_int,
    js_number,
    js_nan,
    js_infinity,
    js_neg_infinity,
    jsv_from_string_id,
    jsv_is_undefined,
    jsv_is_null,
    jsv_is_bool,
    jsv_is_int32,
    jsv_is_double,
    jsv_is_object_cell,
    jsv_is_string_cell,
    jsv_is_bigint_cell,
    jsv_is_symbol,
    jsv_coerce_to_bool,
    jsv_from_bool,
    jsv_is_cell,
    jsv_cell_kind,
    JS_CELL_KIND_NATIVE,
    jsv_to_bool,
    jsv_to_int32,
    jsv_to_double,
    jsv_to_table_id,
    __float_bits
}
import from engine.src.runtime.dtoa {
    dtoa_shortest,
    dtoa_fixed,
    dtoa_mul_round,
    number_to_string_radix10,
    dtoa_fixed_digits,
    _dtoa_run_shortest,
    _dtoa_run_fixed,
    _DTOA_OUT_DIGITS,
    _DTOA_OUT_K,
    _trim_trailing_zeros
}
import from engine.src.runtime.jsstring {
    str_intern,
    str_heap,
    str_from_id,
    str_substr,
    str_char_at,
    str_to_float,
    js_string_utf16_units,
    js_string_from_utf16_code_units
}
import from engine.src.runtime.jsobject {
    js_object_create_null,
    js_object_create,
    js_object_get,
    js_object_set
}
import from engine.src.runtime.error {
    make_type_error,
    make_range_error,
    vm_throw_native,
    vm_has_native_exc
}
import from engine.src.vm.vm_obs { js_to_number_observable, js_to_string_observable }
import from engine.src.builtins.array { _to_integer_or_infinity }
import from engine.src.builtins.string { js_coerce_to_string }
import from engine.src.runtime.gc_pin { gc_pin_value }

# ══════════════════════════════════════════════════════════════════════════════
# 1.  Hidden property key sentinels
# ══════════════════════════════════════════════════════════════════════════════

"""
  KEY_IS_NUMBER_OBJ / KEY_IS_BOOLEAN_OBJ mark Number/Boolean wrapper objects.
  Use negative int keys (see string.na.jac) so str_intern() can never collide.
"""
glob KEY_IS_NUMBER_OBJ: int = -21;
glob KEY_IS_BOOLEAN_OBJ: int = -22;

"""Wired from init_global after Boolean.prototype is created — used by new Boolean().

ES §20.3.3: "The Boolean prototype object is itself a Boolean object; it has a
[[BooleanData]] internal slot whose value is false." Marking it makes
`Boolean.prototype == false` hold and lets Boolean.prototype.toString/valueOf
accept it as a receiver instead of throwing "incompatible receiver"."""
glob _BOOL_PROTO: JSValue = js_undefined();

def:pub js_boolean_set_proto(proto: JSValue) {
    _BOOL_PROTO = proto;
    gc_pin_value(proto);  # glob-held singleton — invisible to the GC root walk
    js_object_set(proto, KEY_IS_BOOLEAN_OBJ, js_false());
}

"""Boolean.prototype, for property lookups on a primitive boolean receiver."""
def:pub js_boolean_get_proto -> JSValue {
    return _BOOL_PROTO;
}

"""Wired from init_global after Number.prototype is created — used by new Number() / Object(n).

ES §21.1.3: the Number prototype object is itself a Number object with
[[NumberData]] = +0."""
glob _NUM_PROTO: JSValue = js_undefined();

def:pub js_number_set_proto(proto: JSValue) {
    _NUM_PROTO = proto;
    gc_pin_value(proto);  # glob-held singleton — invisible to the GC root walk
    js_object_set(proto, KEY_IS_NUMBER_OBJ, js_int(0));
}

"""Number.prototype, for property lookups on a primitive number receiver."""
def:pub js_number_get_proto -> JSValue {
    return _NUM_PROTO;
}

# ══════════════════════════════════════════════════════════════════════════════
# 2.  ECMAScript Number constants  (§21.1.2)
# ══════════════════════════════════════════════════════════════════════════════

glob NUM_MAX_VALUE: float = 1.7976931348623157e+308,
     NUM_MIN_VALUE: float = 5e-324,
     NUM_EPSILON: float = 2.220446049250313e-16,
     NUM_MAX_SAFE_INTEGER: float = 9007199254740991.0,
     NUM_MIN_SAFE_INTEGER: float = -9007199254740991.0;

# ══════════════════════════════════════════════════════════════════════════════
# 3.  Internal helpers
# ══════════════════════════════════════════════════════════════════════════════

"""Digit alphabet for base 2–36 conversion."""
glob _DIGITS: str = "0123456789abcdefghijklmnopqrstuvwxyz";

"""Create a JSValue{tag=String} from a raw Jac str."""
def _num_js_str(s: str) -> JSValue {
    return jsv_from_string_id(str_heap(s));  # G1.5: number toString is a transient value
}

"""
Extract the float value from a Number JSValue (primitive or wrapper object).
Returns 0.0 for non-numeric values.
"""
def _num_prim(v: JSValue) -> float {
    if jsv_is_int32(v) {
        return float(jsv_to_int32(v));
    }
    if jsv_is_double(v) {
        return jsv_to_double(v);
    }
    if jsv_is_object_cell(v) {
        inner: JSValue = js_object_get(v, KEY_IS_NUMBER_OBJ);
        if jsv_is_int32(inner) {
            return float(jsv_to_int32(inner));
        }
        if jsv_is_double(inner) {
            return jsv_to_double(inner);
        }
    }
    return 0.0;
}

"""
thisNumberValue — ECMAScript abstract operation (§21.1.3).
Throws TypeError when `this` is not a Number primitive or Number object.
"""
def _this_number_value(v: JSValue) -> float {
    if jsv_is_int32(v) {
        return float(jsv_to_int32(v));
    }
    if jsv_is_double(v) {
        return jsv_to_double(v);
    }
    if is_number_object(v) {
        inner: JSValue = js_object_get(v, KEY_IS_NUMBER_OBJ);
        if jsv_is_int32(inner) {
            return float(jsv_to_int32(inner));
        }
        if jsv_is_double(inner) {
            return jsv_to_double(inner);
        }
    }
    vm_throw_native(
        make_type_error("Number.prototype method called on incompatible receiver")
    );
    return 0.0;
}

"""Return thisNumberValue as a JSValue for ToString delegation."""
def _this_number_jsvalue(v: JSValue) -> JSValue {
    if jsv_is_int32(v) or jsv_is_double(v) {
        return v;
    }
    if is_number_object(v) {
        return js_object_get(v, KEY_IS_NUMBER_OBJ);
    }
    vm_throw_native(
        make_type_error("Number.prototype method called on incompatible receiver")
    );
    return js_int(0);
}

"""Repeat `ch` exactly `count` times."""
def _repeat_char(ch: str, count: int) -> str {
    out: str = "";
    i: int = 0;
    while i < count {
        out = out + ch;
        i = i + 1;
    }
    return out;
}

"""Coerce an argument with ToIntegerOrInfinity; propagate abrupt completions."""
def _to_int_or_inf_arg(v: JSValue) -> float {
    n: float = _to_integer_or_infinity(v);
    if vm_has_native_exc() {
        return 0.0;
    }
    return n;
}

"""Validate fractionDigits for toFixed / toExponential: [0, 100]."""
def _validate_fraction_digits(v: JSValue) -> int {
    f: float = _to_int_or_inf_arg(v);
    if vm_has_native_exc() {
        return 0;
    }
    if f < 0.0 or f > 100.0 {
        vm_throw_native(
            make_range_error("toFixed() digits argument must be between 0 and 100")
        );
        return 0;
    }
    return int(f);
}

"""Validate precision for toPrecision: [1, 100]."""
def _validate_precision(v: JSValue) -> int {
    p: float = _to_int_or_inf_arg(v);
    if vm_has_native_exc() {
        return 0;
    }
    if p < 1.0 or p > 100.0 {
        vm_throw_native(
            make_range_error("toPrecision() precision must be between 1 and 100")
        );
        return 0;
    }
    return int(p);
}

"""Validate radix for toString: [2, 36]."""
def _validate_radix(v: JSValue) -> int {
    r: float = _to_int_or_inf_arg(v);
    if vm_has_native_exc() {
        return 0;
    }
    if r < 2.0 or r > 36.0 {
        vm_throw_native(
            make_range_error("toString() radix argument must be between 2 and 36")
        );
        return 0;
    }
    return int(r);
}

"""ECMAScript ToString on a Number value (radix 10)."""
def _number_to_string(n: float) -> str {
    return number_to_string_radix10(n);
}

"""True when x is negative zero."""
def _num_is_negative_zero(x: float) -> bool {
    return x == 0.0 and __float_bits(x) < 0;
}

"""
Absolute value of a float (avoids depending on Python abs()).
"""
def _fabs(x: float) -> float {
    if x < 0.0 {
        return -x;
    }
    return x;
}

"""
Raise base to an integer exponent (non-negative).
Used to compute powers of 10 for toFixed / toPrecision.
"""
def _pow_int(base: float, exp: int) -> float {
    result: float = 1.0;
    i: int = 0;
    while i < exp {
        result = result * base;
        i = i + 1;
    }
    return result;
}

"""
Convert non-negative integer `n` to a string in a given radix (2–36).
"""
def _uint_to_radix(n: int, radix: int) -> str {
    if n == 0 {
        return "0";
    }
    result: str = "";
    m: int = n;
    while m > 0 {
        d: int = m % radix;
        result = str_char_at(_DIGITS, d) + result;
        m = m // radix;
    }
    return result;
}

"""
Build a string with exactly `digits` decimal places from a rounded integer.
`rounded` is |n| * 10^digits, rounded to nearest.
`sign` is "" or "-".
"""
def _format_fixed(sign: str, rounded: int, digits: int) -> str {
    # Convert rounded integer to a digit string
    raw: str = str(rounded);
    # Pad with leading zeros so len(raw) > digits
    while len(raw) <= digits {
        raw = "0" + raw;
    }
    # Split: integer part = raw[0 : len-digits], frac part = raw[len-digits : len]
    split: int = len(raw) - digits;
    int_part: str = str_substr(raw, 0, split);
    frac_part: str = str_substr(raw, split, len(raw));
    if digits == 0 {
        return sign + int_part;
    }
    return sign + int_part + "." + frac_part;
}

"""
toFixed core — format float `n` with exactly `d` decimal places.
ECMAScript §21.1.3.3 steps 4–8.
"""
def _to_fixed_str(n: float, d: int) -> str {
    if not (n == n) {
        return "NaN";
    }
    if n >= 1e21 or n <= -1e21 {
        return _number_to_string(n);
    }
    sign: str = "";
    pos: float = n;
    if pos < 0.0 {
        sign = "-";
        pos = -pos;
    }
    if pos >= 1e21 {
        return _number_to_string(n);
    }
    # Fast path: exact integer mantissa only needs zero padding for d > 0
    if pos == int(pos) and pos <= NUM_MAX_SAFE_INTEGER {
        ip: int = int(pos);
        if d == 0 {
            return sign + str(ip);
        }
        return sign + str(ip) + "." + _repeat_char("0", d);
    }
    fd: str = dtoa_fixed_digits(pos, d);
    if d == 0 {
        return sign + fd;
    }
    while len(fd) < d + 1 {
        fd = "0" + fd;
    }
    return sign
        + str_substr(fd, 0, len(fd) - d)
        + "."
        + str_substr(fd, len(fd) - d, len(fd));
}

def _trim_leading_zeros(digits: str) -> str {
    while len(digits) > 1 and str_char_at(digits, 0) == "0" {
        digits = str_substr(digits, 1, len(digits));
    }
    return digits;
}

def _num_inc_digit_str(s: str) -> str {
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

def _digits_all_nines(digits: str) -> bool {
    if len(digits) == 0 {
        return False;
    }
    i: int = 0;
    while i < len(digits) {
        if str_char_at(digits, i) != "9" {
            return False;
        }
        i = i + 1;
    }
    return True;
}

def _to_exponential_explicit(pos: float, f_d: int) -> str {
    need: int = f_d + 1;
    _dtoa_run_shortest(pos);
    dig: str = _DTOA_OUT_DIGITS;
    k: int = _DTOA_OUT_K;
    if len(dig) < need {
        _dtoa_run_fixed(pos, need, True);
        dig = _DTOA_OUT_DIGITS;
        k = _DTOA_OUT_K;
    } elif len(dig) > need {
        extra: int = int(str_char_at(dig, need)) - int(str_char_at("0", 0));
        head: str = str_substr(dig, 0, need);
        if extra >= 5 {
            head = _num_inc_digit_str(head);
        }
        if len(head) > need {
            head = str_substr(head, 0, need);
            k = k + 1;
        }
        dig = head;
    }
    exp_e: int = k - len(dig) + 1 + f_d;
    return _format_exponential_mantissa_str(dig, f_d, exp_e);
}

def _format_exponential_mantissa_str(raw: str, f: int, exp: int) -> str {
    need: int = f + 1;
    while len(raw) < need {
        raw = "0" + raw;
    }
    if len(raw) > need {
        raw = str_substr(raw, 0, need);
    }
    int_d: str = str_substr(raw, 0, 1);
    mant: str = int_d;
    if f > 0 {
        frac: str = str_substr(raw, 1, len(raw));
        while len(frac) < f {
            frac = frac + "0";
        }
        if len(frac) > f {
            frac = str_substr(frac, 0, f);
        }  # jac:ignore[E1001]
        mant = int_d + "." + frac;
    }
    exp_sign: str = "+";
    exp_abs: int = exp;
    if exp < 0 {
        exp_sign = "-";
        exp_abs = -exp;
    }
    return mant + "e" + exp_sign + str(exp_abs);
}

"""
Format a positive integer `n` with exactly `f` fractional digits in exponential form.
`exp` is the decimal exponent (n × 10^(exp-f) = x).
"""
def _format_exponential_mantissa(n: int, f: int, exp: int) -> str {
    return _format_exponential_mantissa_str(str(n), f, exp);
}

"""
Find [e, n, f] for toExponential(undefined): minimal f ≥ 0 with n × 10^(e-f) = x.
Returns a three-element list [e, n, f].
"""
def _to_exponential_auto_parts(pos: float) -> list[int] {
    _dtoa_run_shortest(pos);
    dig: str = _DTOA_OUT_DIGITS;
    k: int = _DTOA_OUT_K;
    n: int = int(dig);
    f: int = len(dig) - 1;
    return [k, n, f];
}

"""
toExponential core — scientific notation with optional fractionDigits.
Pass fraction_digits = -1 for the undefined/minimal-digits branch.
"""
def _to_exponential_str(n: float, fraction_digits: int) -> str {
    if not (n == n) {
        return "NaN";
    }
    if n > NUM_MAX_VALUE {
        return "Infinity";
    }
    if n < -NUM_MAX_VALUE {
        return "-Infinity";
    }
    sign: str = "";
    pos: float = n;
    if pos < 0.0 {
        sign = "-";
        pos = -pos;
    }
    if _num_is_negative_zero(n) {
        pos = 0.0;
        if fraction_digits < 0 {
            fraction_digits = 0;
        }
    }
    if pos == 0.0 {
        f0: int = fraction_digits;
        if f0 < 0 {
            f0 = 0;
        }
        frac_zeros: str = _repeat_char("0", f0);
        if f0 == 0 {
            return sign + "0e+0";
        }
        return sign + "0." + frac_zeros + "e+0";
    }
    if fraction_digits < 0 {
        _dtoa_run_shortest(pos);
        dig_a: str = _trim_trailing_zeros(_DTOA_OUT_DIGITS);
        f_a: int = len(dig_a) - 1;
        if f_a < 0 {
            f_a = 0;
        }
        return sign + _format_exponential_mantissa_str(dig_a, f_a, _DTOA_OUT_K);
    }
    # Spec branch with explicit fractionDigits f
    f_d: int = fraction_digits;
    return sign + _to_exponential_explicit(pos, f_d);
}

"""
Format significant-digit string `m` with exponent `e` and precision `p`.
"""
def _format_precision_plain(sign: str, m: str, e: int, p: int) -> str {
    if e >= 0 {
        if e + 1 >= len(m) {
            pad: str = _repeat_char("0", e + 1 - len(m));
            m = m + pad;
        }
        int_part: str = str_substr(m, 0, e + 1);
        frac_part: str = str_substr(m, e + 1, len(m));
        while len(frac_part) < p - (e + 1) {
            frac_part = frac_part + "0";
        }
        if p == e + 1 {
            return sign + int_part;
        }
        return sign + int_part + "." + frac_part;
    }
    zeros: str = _repeat_char("0", -(e + 1));
    return sign + "0." + zeros + m;
}

"""
toPrecision core — ECMAScript §21.1.3.5 steps 6–14.
"""
def _to_precision_str(n: float, p: int) -> str {
    if not (n == n) {
        return "NaN";
    }
    if n > NUM_MAX_VALUE {
        return "Infinity";
    }
    if n < -NUM_MAX_VALUE {
        return "-Infinity";
    }
    sign: str = "";
    pos: float = n;
    if pos < 0.0 {
        sign = "-";
        pos = -pos;
    }
    if _num_is_negative_zero(n) or pos == 0.0 {
        if p <= 1 {
            return sign + "0";
        }
        return sign + "0." + _repeat_char("0", p - 1);
    }
    _dtoa_run_fixed(pos, p, False);
    m: str = _DTOA_OUT_DIGITS;
    exp_e: int = _DTOA_OUT_K;
    # Exponential form when e < -6 or e >= p  (spec step 10.c)
    if exp_e < -6 or exp_e >= p {
        f_prec: int = p - 1;
        return sign + _format_exponential_mantissa_str(m, f_prec, exp_e);
    }
    return _format_precision_plain(sign, m, exp_e, p);
}

# ══════════════════════════════════════════════════════════════════════════════
# 4.  Number constructor
# ══════════════════════════════════════════════════════════════════════════════

"""Return True if v is a Number object wrapper (not a primitive)."""
def:pub is_number_object(v: JSValue) -> bool {
    if not jsv_is_object_cell(v) {
        return False;
    }
    inner: JSValue = js_object_get(v, KEY_IS_NUMBER_OBJ);
    return jsv_is_int32(inner) or jsv_is_double(inner);
}

"""
Extract the Number primitive from a Number primitive or object.
Implements RequireInternalSlot[[NumberData]].
"""
def:pub number_value_of(v: JSValue) -> JSValue {
    if jsv_is_int32(v) or jsv_is_double(v) {
        return v;
    }
    if is_number_object(v) {
        return js_object_get(v, KEY_IS_NUMBER_OBJ);
    }
    return js_int(0);
}

"""Convert a finite float ToNumber result to the most compact JSValue (preserve -0)."""
def _float_to_number_jsvalue(n: float) -> JSValue {
    if not (n == n) {
        return js_nan();
    }
    if n == MATH_INF {
        return js_infinity();
    }
    if n == MATH_NEG_INF {
        return js_neg_infinity();
    }
    # ECMAScript §6.1.6: -0 must remain a double with sign bit set.
    if n == 0.0 and __float_bits(n) < 0 {
        return js_number(n);
    }
    if n >= -2147483648.0 and n <= 2147483647.0 {
        i: int = int(n);
        if float(i) == n {
            return js_int(i);
        }
    }
    return js_number(n);
}

"""
Number(v) — called as a function: coerce to a number primitive.
ECMAScript §21.1.1.1 / §7.1.4 (ToNumber)
"""
def:pub js_Number_call(args: list[JSValue]) -> JSValue {
    if len(args) == 0 {
        return js_int(0);
    }
    v: JSValue = args[0];
    if jsv_is_int32(v) or jsv_is_double(v) {
        return v;
    }
    if jsv_is_bool(v) {
        if jsv_to_bool(v) {
            return js_int(1);
        } else {
            return js_int(0);
        }
    }
    if jsv_is_undefined(v) {
        return js_nan();
    }
    if jsv_is_null(v) {
        return js_int(0);
    }
    if jsv_is_string_cell(v) {
        s: str = str_from_id(jsv_to_table_id(v));
        return _float_to_number_jsvalue(str_to_float(s));
    }
    if jsv_is_symbol(v) {
        vm_throw_native(make_type_error("Cannot convert a Symbol value to a number"));
        return js_undefined();
    }
    # Number(bigint) converts (test262 Number/bigint-conversion); unary + / ToNumber still TypeError.
    if jsv_is_bigint_cell(v) {
        bi_s: str = str_from_id(jsv_to_table_id(v));
        return _float_to_number_jsvalue(float(bi_s));
    }
    if is_number_object(v) {
        return number_value_of(v);
    }
    if jsv_is_object_cell(v) {
        n: float = js_to_number_observable(v);
        if vm_has_native_exc() {
            return js_undefined();
        }
        return _float_to_number_jsvalue(n);
    }
    return js_nan();
}

"""
new Number(v) — returns a Number object wrapper.
ECMAScript §21.1.1
"""
def:pub js_Number_new(args: list[JSValue]) -> JSValue {
    prim: JSValue = js_Number_call(args);
    if vm_has_native_exc() {
        return js_undefined();
    }
    wrapper: JSValue;
    if jsv_is_undefined(_NUM_PROTO) {
        wrapper = js_object_create_null();
    } else {
        wrapper = js_object_create(_NUM_PROTO);
    }
    js_object_set(wrapper, KEY_IS_NUMBER_OBJ, prim);
    return wrapper;
}

# ══════════════════════════════════════════════════════════════════════════════
# 5.  Number static constants as accessor functions  (§21.1.2)
# ══════════════════════════════════════════════════════════════════════════════

"""Number.MAX_VALUE — largest positive finite float."""
def:pub js_Number_MAX_VALUE -> JSValue {
    return js_number(NUM_MAX_VALUE);
}

"""Number.MIN_VALUE — smallest positive float (5e-324)."""
def:pub js_Number_MIN_VALUE -> JSValue {
    return js_number(NUM_MIN_VALUE);
}

"""Number.EPSILON — difference between 1 and the smallest float > 1."""
def:pub js_Number_EPSILON -> JSValue {
    return js_number(NUM_EPSILON);
}

"""Number.MAX_SAFE_INTEGER — 2^53 − 1."""
def:pub js_Number_MAX_SAFE_INTEGER -> JSValue {
    return js_number(NUM_MAX_SAFE_INTEGER);
}

"""Number.MIN_SAFE_INTEGER — −(2^53 − 1)."""
def:pub js_Number_MIN_SAFE_INTEGER -> JSValue {
    return js_number(NUM_MIN_SAFE_INTEGER);
}

"""Number.POSITIVE_INFINITY."""
def:pub js_Number_POSITIVE_INFINITY -> JSValue {
    return js_infinity();
}

"""Number.NEGATIVE_INFINITY."""
def:pub js_Number_NEGATIVE_INFINITY -> JSValue {
    return js_neg_infinity();
}

"""Number.NaN."""
def:pub js_Number_NaN -> JSValue {
    return js_nan();
}

# ══════════════════════════════════════════════════════════════════════════════
# 6.  Number static methods  (§21.1.2.*)
# ══════════════════════════════════════════════════════════════════════════════

"""
Number.isNaN(v) — true only for actual NaN (no coercion).
ECMAScript §21.1.2.4
"""
def:pub js_Number_isNaN(args: list[JSValue]) -> JSValue {
    if len(args) == 0 {
        return js_false();
    }
    v: JSValue = args[0];
    if jsv_is_double(v) {
        n: float = jsv_to_double(v);
        if not (n == n) {
            return js_true();
        }
    }
    return js_false();
}

"""
Number.isFinite(v) — true only for finite numbers (no coercion).
ECMAScript §21.1.2.2
"""
def:pub js_Number_isFinite(args: list[JSValue]) -> JSValue {
    if len(args) == 0 {
        return js_false();
    }
    v: JSValue = args[0];
    if jsv_is_int32(v) {
        return js_true();
    }
    if jsv_is_double(v) {
        n: float = jsv_to_double(v);
        if not (n == n) {
            return js_false();
        }
        if n == MATH_INF or n == MATH_NEG_INF {
            return js_false();
        }
        return js_true();
    }
    return js_false();
}

"""
Number.isInteger(v) — true for integers (no coercion).
ECMAScript §21.1.2.3
"""
def:pub js_Number_isInteger(args: list[JSValue]) -> JSValue {
    if len(args) == 0 {
        return js_false();
    }
    v: JSValue = args[0];
    if jsv_is_int32(v) {
        return js_true();
    }
    if jsv_is_double(v) {
        n: float = jsv_to_double(v);
        if not (n == n) {
            return js_false();
        }
        if n == MATH_INF or n == MATH_NEG_INF {
            return js_false();
        }
        if n.is_integer() {
            return js_true();
        }
    }
    return js_false();
}

"""
Number.isSafeInteger(v) — integer in [−2^53+1, 2^53−1].
ECMAScript §21.1.2.5
"""
def:pub js_Number_isSafeInteger(args: list[JSValue]) -> JSValue {
    if len(args) == 0 {
        return js_false();
    }
    v: JSValue = args[0];
    if jsv_is_int32(v) {
        return js_true();
    }
    if jsv_is_double(v) {
        n: float = jsv_to_double(v);
        if not (n == n) {
            return js_false();
        }
        if not n.is_integer() {
            return js_false();
        }
        if n > NUM_MAX_SAFE_INTEGER or n < NUM_MIN_SAFE_INTEGER {
            return js_false();
        }
        return js_true();
    }
    return js_false();
}

"""
Number.parseFloat(s) — same as global parseFloat.
ECMAScript §21.1.2.7
"""
def:pub js_Number_parseFloat(args: list[JSValue]) -> JSValue {
    return js_parseFloat(args);
}

"""
Number.parseInt(s, radix) — same as global parseInt.
ECMAScript §21.1.2.8
"""
def:pub js_Number_parseInt(args: list[JSValue]) -> JSValue {
    return js_parseInt(args);
}

# ══════════════════════════════════════════════════════════════════════════════
# 7.  Number prototype methods  (§21.1.3.*)
# ══════════════════════════════════════════════════════════════════════════════

"""
Number.prototype.toFixed(digits) — fixed-point notation.
ECMAScript §21.1.3.3
"""
def:pub js_num_toFixed(this_val: JSValue, args: list[JSValue]) -> JSValue {
    n: float = _this_number_value(this_val);
    if vm_has_native_exc() {
        return js_undefined();
    }
    digits: int = 0;
    if len(args) > 0 {
        digits = _validate_fraction_digits(args[0]);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    if not (n == n) {
        return _num_js_str("NaN");
    }
    if n >= 1e21 or n <= -1e21 {
        return _num_js_str(_number_to_string(n));
    }
    return _num_js_str(_to_fixed_str(n, digits));
}

"""
Number.prototype.toPrecision(precision) — significant-digit notation.
ECMAScript §21.1.3.5
"""
def:pub js_num_toPrecision(this_val: JSValue, args: list[JSValue]) -> JSValue {
    n: float = _this_number_value(this_val);
    if vm_has_native_exc() {
        return js_undefined();
    }
    if len(args) == 0 or jsv_is_undefined(args[0]) {
        return _num_js_str(js_coerce_to_string(_this_number_jsvalue(this_val)));
    }
    p_val: float = _to_int_or_inf_arg(args[0]);
    if vm_has_native_exc() {
        return js_undefined();
    }
    if not (n == n) {
        return _num_js_str("NaN");
    }
    if n > NUM_MAX_VALUE {
        return _num_js_str("Infinity");
    }
    if n < -NUM_MAX_VALUE {
        return _num_js_str("-Infinity");
    }
    if p_val < 1.0 or p_val > 100.0 {
        vm_throw_native(
            make_range_error("toPrecision() precision must be between 1 and 100")
        );
        return js_undefined();
    }
    prec: int = int(p_val);
    return _num_js_str(_to_precision_str(n, prec));
}

"""
Number.prototype.toExponential(digits) — scientific notation.
ECMAScript §21.1.3.2
"""
def:pub js_num_toExponential(this_val: JSValue, args: list[JSValue]) -> JSValue {
    n: float = _this_number_value(this_val);
    if vm_has_native_exc() {
        return js_undefined();
    }
    frac: int = -1;
    if len(args) > 0 and not jsv_is_undefined(args[0]) {
        f_val: float = _to_int_or_inf_arg(args[0]);
        if vm_has_native_exc() {
            return js_undefined();
        }
        if not (n == n) {
            return _num_js_str("NaN");
        }
        if n > NUM_MAX_VALUE {
            return _num_js_str("Infinity");
        }
        if n < -NUM_MAX_VALUE {
            return _num_js_str("-Infinity");
        }
        if f_val < 0.0 or f_val > 100.0 {
            vm_throw_native(
                make_range_error(
                    "toExponential() fractionDigits must be between 0 and 100"
                )
            );
            return js_undefined();
        }
        frac = int(f_val);
    } else {
        if not (n == n) {
            return _num_js_str("NaN");
        }
        if n > NUM_MAX_VALUE {
            return _num_js_str("Infinity");
        }
        if n < -NUM_MAX_VALUE {
            return _num_js_str("-Infinity");
        }
    }
    return _num_js_str(_to_exponential_str(n, frac));
}

"""
Number.prototype.toString(radix) — base conversion 2–36.
ECMAScript §21.1.3.6
"""
def:pub js_num_toString(this_val: JSValue, args: list[JSValue]) -> JSValue {
    n: float = _this_number_value(this_val);
    if vm_has_native_exc() {
        return js_undefined();
    }
    radix: int = 10;
    if len(args) > 0 and not jsv_is_undefined(args[0]) {
        radix = _validate_radix(args[0]);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    # Special values
    if not (n == n) {
        return _num_js_str("NaN");
    }
    if n == MATH_INF {
        return _num_js_str("Infinity");
    }
    if n == MATH_NEG_INF {
        return _num_js_str("-Infinity");
    }
    if radix == 10 {
        return _num_js_str(_number_to_string(n));
    }
    # Non-decimal: convert truncated integer part
    sign: str = "";
    pos: float = n;
    if pos < 0.0 {
        sign = "-";
        pos = -pos;
    }
    int_part: int = int(pos);
    return _num_js_str(sign + _uint_to_radix(int_part, radix));
}

"""
Number.prototype.valueOf() — return the number primitive.
ECMAScript §21.1.3.7
"""
def:pub js_num_valueOf(this_val: JSValue) -> JSValue {
    n: float = _this_number_value(this_val);
    if vm_has_native_exc() {
        return js_undefined();
    }
    return _float_to_number_jsvalue(n);
}

# ══════════════════════════════════════════════════════════════════════════════
# 8.  Boolean constructor  (§20.3)
# ══════════════════════════════════════════════════════════════════════════════

"""
Boolean(v) — coerce to boolean primitive.
ECMAScript §20.3.1.1
"""
def:pub js_Boolean_call(args: list[JSValue]) -> JSValue {
    if len(args) == 0 {
        return js_false();
    }
    v: JSValue = args[0];
    if jsv_is_undefined(v) or jsv_is_null(v) {
        return js_false();
    }
    if jsv_is_bool(v) {
        return v;
    }
    if jsv_is_int32(v) {
        if jsv_to_int32(v) != 0 {
            return js_true();
        } else {
            return js_false();
        }
    }
    if jsv_is_double(v) {
        n: float = jsv_to_double(v);
        if n == 0.0 or not (n == n) {
            return js_false();
        }
        return js_true();
    }
    if jsv_is_string_cell(v) {
        if jsv_to_table_id(v) == 0 {
            return js_false();
        }  # empty string interned as id 0 → false
        s: str = str_from_id(jsv_to_table_id(v));
        if s == "" {
            return js_false();
        }
        return js_true();
    }
    if jsv_is_bigint_cell(v) {
        return jsv_from_bool(jsv_coerce_to_bool(v));
    }
    # Objects are always truthy
    return js_true();
}

"""new Boolean(v) — returns a Boolean wrapper object."""
def:pub js_Boolean_new(args: list[JSValue]) -> JSValue {
    prim: JSValue = js_Boolean_call(args);
    wrapper: JSValue;
    if jsv_is_undefined(_BOOL_PROTO) {
        wrapper = js_object_create_null();
    } else {
        wrapper = js_object_create(_BOOL_PROTO);
    }
    js_object_set(wrapper, KEY_IS_BOOLEAN_OBJ, prim);
    return wrapper;
}

"""Return True if v is a Boolean object wrapper."""
def:pub is_boolean_object(v: JSValue) -> bool {
    if not jsv_is_object_cell(v) {
        return False;
    }
    inner: JSValue = js_object_get(v, KEY_IS_BOOLEAN_OBJ);
    return jsv_is_bool(inner);
}

"""Extract the Boolean primitive from a Boolean value or object."""
def:pub boolean_value_of(v: JSValue) -> JSValue {
    if jsv_is_bool(v) {
        return v;
    }
    if is_boolean_object(v) {
        return js_object_get(v, KEY_IS_BOOLEAN_OBJ);
    }
    return js_false();
}

"""Boolean.prototype.toString() — "true" or "false" (TypeError if not a boolean)."""
def:pub js_Boolean_prototype_toString(this_val: JSValue) -> JSValue {
    if not jsv_is_bool(this_val) and not is_boolean_object(this_val) {
        te: JSValue = make_type_error(
            "Boolean.prototype.toString called on incompatible receiver"
        );
        vm_throw_native(te);
        return js_undefined();
    }
    b: JSValue = boolean_value_of(this_val);
    if jsv_to_bool(b) {
        return _num_js_str("true");
    }
    return _num_js_str("false");
}

"""Boolean.prototype.valueOf() — return the boolean primitive (TypeError if not a boolean)."""
def:pub js_Boolean_prototype_valueOf(this_val: JSValue) -> JSValue {
    if jsv_is_bool(this_val) {
        return this_val;
    }
    if is_boolean_object(this_val) {
        return js_object_get(this_val, KEY_IS_BOOLEAN_OBJ);
    }
    te2: JSValue = make_type_error(
        "Boolean.prototype.valueOf called on incompatible receiver"
    );
    vm_throw_native(te2);
    return js_undefined();
}

# ══════════════════════════════════════════════════════════════════════════════
# 9.  Global functions: parseInt, parseFloat, isNaN, isFinite
# ══════════════════════════════════════════════════════════════════════════════

"""
Parse an ASCII digit character in base `radix`.
Returns -1 if the character is not a valid digit.
"""
def _digit_value(c: str, radix: int) -> int {
    v: int = -1;
    o: int = ord(c);
    if o >= 48 and o <= 57 {
        v = o - 48;
    } elif o >= 65 and o <= 90 {  # '0'–'9'
        v = o - 55;
    } elif o >= 97 and o <= 122 {  # 'A'–'Z'
        v = o - 87;
    }  # 'a'–'z'
    if v >= radix {
        return -1;
    }
    return v;
}

"""
Parse a Jac str as an integer in the given radix.
Returns 0 on empty or invalid input (ECMAScript returns NaN for these;
the caller wraps appropriately).
"""
def _parse_int_str(s: str, radix: int) -> int {
    result: int = 0;
    found: bool = False;
    i: int = 0;
    while i < len(s) {
        c: str = s[i];
        dv: int = _digit_value(c, radix);
        if dv < 0 {
            break;
        }
        result = result * radix + dv;
        found = True;
        i = i + 1;
    }
    if not found {
        return -1;
    }  # sentinel: no digits read
    return result;
}

"""
Parse a Jac str as a decimal float (integer + optional fractional + optional exponent).
Returns NaN (MATH_NAN) on failure.
"""
def _parse_float_str(s: str) -> float {
    n: int = len(s);
    if n == 0 {
        return MATH_NAN;
    }
    i: int = 0;
    sign: float = 1.0;
    # Read sign
    if i < n and (s[i] == "+" or s[i] == "-") {
        if s[i] == "-" {
            sign = -1.0;
        }
        i = i + 1;
    }
    # Integer part
    int_part: float = 0.0;
    has_int: bool = False;
    while i < n {
        c: str = s[i];
        dv: int = _digit_value(c, 10);
        if dv < 0 {
            break;
        }
        int_part = int_part * 10.0 + float(dv);
        has_int = True;
        i = i + 1;
    }
    # Fractional part
    frac_part: float = 0.0;
    frac_div: float = 1.0;
    has_frac: bool = False;
    if i < n and s[i] == "." {
        i = i + 1;
        while i < n {
            c2: str = s[i];
            dv2: int = _digit_value(c2, 10);
            if dv2 < 0 {
                break;
            }
            frac_div = frac_div * 10.0;
            frac_part = frac_part * 10.0 + float(dv2);
            has_frac = True;
            i = i + 1;
        }
    }
    if not has_int and not has_frac {
        return MATH_NAN;
    }
    mantissa: float = sign * (int_part + frac_part / frac_div);
    # Exponent part
    if i < n and (s[i] == "e" or s[i] == "E") {
        i = i + 1;
        exp_sign: float = 1.0;
        if i < n and (s[i] == "+" or s[i] == "-") {
            if s[i] == "-" {
                exp_sign = -1.0;
            }
            i = i + 1;
        }
        exp_val: float = 0.0;
        while i < n {
            c3: str = s[i];
            dv3: int = _digit_value(c3, 10);
            if dv3 < 0 {
                break;
            }
            exp_val = exp_val * 10.0 + float(dv3);
            i = i + 1;
        }
        if exp_sign > 0.0 {
            j: int = 0;
            while j < int(exp_val) {
                mantissa = mantissa * 10.0;
                j = j + 1;
            }
        } else {
            j2: int = 0;
            while j2 < int(exp_val) {
                mantissa = mantissa / 10.0;
                j2 = j2 + 1;
            }
        }
    }
    return mantissa;
}

"""Strip leading/trailing StrWhiteSpace — ECMAScript §7.1.4.1 / table 34.

`.strip()` only removes ASCII blanks, but the numeric-conversion grammar also
treats NBSP, the U+2000-200A set, LS/PS, NNBSP, MMSP, ideographic space and the
BOM as whitespace. parseInt("\u00A042") must be 42, not NaN."""
def _strip_js_whitespace(s: str) -> str {
    # Fast path: the overwhelmingly common case is a string with no leading or
    # trailing whitespace at all, or plain ASCII blanks. Decoding to UTF-16 units
    # allocates two lists, so first check the ASCII ends directly — only fall
    # through to the full Unicode scan when a non-ASCII byte is actually present
    # at either end (the only way a non-ASCII space can appear there).
    n0: int = len(s);
    if n0 == 0 {
        return s;
    }
    f0: int = ord(str_char_at(s, 0));
    l0: int = ord(str_char_at(s, n0 - 1));
    if f0 < 128 and l0 < 128 {
        lo0: int = 0;
        while lo0 < n0 {
            c0: int = ord(str_char_at(s, lo0));
            if c0 == 32 or (c0 >= 9 and c0 <= 13) {
                lo0 = lo0 + 1;
            } else {
                break;
            }
        }
        hi0: int = n0;
        while hi0 > lo0 {
            c1: int = ord(str_char_at(s, hi0 - 1));
            if c1 == 32 or (c1 >= 9 and c1 <= 13) {
                hi0 = hi0 - 1;
            } else {
                break;
            }
        }
        if lo0 == 0 and hi0 == n0 {
            return s;
        }
        return str_substr(s, lo0, hi0);
    }
    units: list[int] = js_string_utf16_units(s);
    n: int = len(units);
    lo: int = 0;
    while lo < n and _is_js_ws_unit(units[lo]) {
        lo = lo + 1;
    }
    hi: int = n;
    while hi > lo and _is_js_ws_unit(units[hi - 1]) {
        hi = hi - 1;
    }
    if lo == 0 and hi == n {
        return s;
    }
    out: list[int] = [];
    i: int = lo;
    while i < hi {
        out.append(units[i]);
        i = i + 1;
    }
    return js_string_from_utf16_code_units(out);
}

"""True for a UTF-16 unit in the StrWhiteSpace set."""
def _is_js_ws_unit(u: int) -> bool {
    if u == 9 or u == 10 or u == 11 or u == 12 or u == 13 or u == 32 {
        return True;
    }
    if u == 160 or u == 5760 {
        return True;
    }  # NBSP, OGHAM SPACE MARK
    if u >= 8192 and u <= 8202 {
        return True;
    }  # EN QUAD .. HAIR SPACE
    if u == 8232 or u == 8233 {
        return True;
    }  # LS, PS
    if u == 8239 or u == 8287 or u == 12288 {
        return True;
    }  # NNBSP, MMSP, IDEOGRAPHIC
    if u == 65279 {
        return True;
    }  # BOM / ZWNBSP
    return False;
}

"""ToString for the parse* globals, honouring a user toString/valueOf and
throwing TypeError for Symbols (§7.1.17)."""
def _parse_arg_to_string(v: JSValue) -> str {
    if jsv_is_string_cell(v) {
        return str_from_id(jsv_to_table_id(v));
    }
    if jsv_is_symbol(v) {
        vm_throw_native(make_type_error("Cannot convert a Symbol value to a string"));
        return "";
    }
    if jsv_is_object_cell(v) {
        return js_to_string_observable(v);
    }
    return js_coerce_to_string(v);
}

"""
parseInt(string, radix?) — ECMAScript §19.2.5
Parse the leading integer of a string. A 0x/0X prefix implies radix 16 when the
radix argument is absent or 16; 0b/0o are NOT parseInt prefixes.
Returns NaN if no valid digits are found.
"""
def:pub js_parseInt(args: list[JSValue]) -> JSValue {
    if len(args) == 0 {
        return js_nan();
    }
    # ES §19.2.5 step 1: ToString(string) — every argument type is stringified,
    # including numbers (parseInt(0.0000001) parses "1e-7" and yields 1).
    s: str = _parse_arg_to_string(args[0]);
    if vm_has_native_exc() {
        return js_nan();
    }
    # Step 2: strip leading StrWhiteSpace only (trailing junk is ignored anyway).
    s = _strip_js_whitespace(s);
    if len(s) == 0 {
        return js_nan();
    }
    sign: int = 1;
    start: int = 0;
    if s[0] == "+" {
        start = 1;
    } elif s[0] == "-" {
        sign = -1;
        start = 1;
    }
    # Steps 6-8: R = ToInt32(radix). R = 0 means "unspecified" → infer below;
    # any other R outside 2..36 is NaN.
    radix: int = 0;
    if len(args) >= 2 {
        rv: JSValue = args[1];
        if jsv_is_int32(rv) {
            radix = jsv_to_int32(rv);
        } elif jsv_is_double(rv) {
            rd: float = jsv_to_double(rv);
            if rd == rd and rd != MATH_INF and rd != MATH_NEG_INF {
                radix = int(rd);
            }
        } elif jsv_is_bool(rv) {
            if jsv_to_bool(rv) {
                radix = 1;
            }
        } elif jsv_is_string_cell(rv) {
            radix = int(str_to_float(str_from_id(jsv_to_table_id(rv))));
        }
    }
    if radix != 0 and (radix < 2 or radix > 36) {
        return js_nan();
    }
    rest: str = str_substr(s, start, len(s));
    # Step 10: a 0x/0X prefix is stripped when R is 16 or unspecified. Note that
    # 0b/0o are NOT parseInt prefixes — parseInt("0b1") is 0, not 1.
    if (radix == 0 or radix == 16)
        and len(rest) >= 2
        and rest[0] == "0"
        and (rest[1] == "x" or rest[1] == "X") {
        radix = 16;
        rest = str_substr(rest, 2, len(rest));
    } elif radix == 0 {
        radix = 10;
    }
    result: int = _parse_int_str(rest, radix);
    if result < 0 {
        return js_nan();
    }
    # Step 15: "-0" and any negative zero result is -0, not +0.
    if result == 0 and sign < 0 {
        return js_number(-0.0);
    }
    return js_int(sign * result);
}

"""
parseFloat(string) — ECMAScript §19.2.4
Parse a string as a decimal floating-point number. Returns NaN on failure.
"""
def:pub js_parseFloat(args: list[JSValue]) -> JSValue {
    if len(args) == 0 {
        return js_nan();
    }
    sv: JSValue = args[0];
    # ES §19.2.4 step 1: ToString(string) for EVERY argument type — a Number
    # argument is stringified first, so parseFloat(-0) sees "0" and returns +0.
    s: str = _parse_arg_to_string(sv);
    if vm_has_native_exc() {
        return js_nan();
    }
    # parseFloat parses the LONGEST valid numeric PREFIX (trailing non-numeric
    # chars are ignored — `parseFloat("3.14abc")` is 3.14). Use the prefix parser
    # `_parse_float_str`, NOT `str_to_float` (the strict whole-string ToNumber
    # path used by Number(str)).
    s = _strip_js_whitespace(s);
    # `Infinity` / `±Infinity` prefix (e.g. `parseFloat("Infinityxyz")` → Infinity).
    if len(s) >= 8 and str_substr(s, 0, 8) == "Infinity" {
        return js_infinity();
    }
    if len(s) >= 9 and str_substr(s, 0, 9) == "+Infinity" {
        return js_infinity();
    }
    if len(s) >= 9 and str_substr(s, 0, 9) == "-Infinity" {
        return js_neg_infinity();
    }
    f: float = _parse_float_str(s);
    if not (f == f) {
        return js_nan();
    }
    return _float_to_number_jsvalue(f);
}

"""ToNumber for the isNaN/isFinite globals.

obs_to_number only runs OrdinaryToPrimitive for object CELLS; a function is a
NATIVE cell, so it fell through to js_to_num and yielded 0 — making
isNaN(function(){}) false. ToNumber of any function is NaN (its toString is
never numeric), so short-circuit that case before delegating."""
def _global_to_number(v: JSValue) -> float {
    if jsv_is_cell(v) and jsv_cell_kind(v) == JS_CELL_KIND_NATIVE {
        return MATH_NAN;
    }
    return js_to_number_observable(v);
}

"""
isNaN(v) — ECMAScript §19.2.3
Coerces v to number, then checks for NaN.
"""
def:pub js_isNaN(args: list[JSValue]) -> JSValue {
    if len(args) == 0 {
        return js_true();
    }
    # ES §19.2.3 step 1: ToNumber(number). Observable, so a user valueOf/toString
    # runs and its abrupt completion propagates; a Symbol argument is a TypeError.
    # This must be the STRICT whole-string conversion, not the prefix parser
    # parseFloat uses — isNaN("12abc") is true because ToNumber("12abc") is NaN.
    n: float = _global_to_number(args[0]);
    if vm_has_native_exc() {
        return js_false();
    }
    if not (n == n) {
        return js_true();
    }
    return js_false();
}

"""
isFinite(v) — ECMAScript §19.2.2
Coerces v to number, then checks finiteness.
"""
def:pub js_isFinite(args: list[JSValue]) -> JSValue {
    if len(args) == 0 {
        return js_false();
    }
    # ES §19.2.2 step 1: ToNumber(number) — observable, strict whole-string.
    n: float = _global_to_number(args[0]);
    if vm_has_native_exc() {
        return js_false();
    }
    if not (n == n) or n == MATH_INF or n == MATH_NEG_INF {
        return js_false();
    }
    return js_true();
}

# ══════════════════════════════════════════════════════════════════════════════
# 10.  Registration stubs  (wired)
# ══════════════════════════════════════════════════════════════════════════════

"""
register_Number —  will call this to install Number and its static
properties + prototype methods on the global object.  Stub returns 0.
"""
def:pub register_Number -> int {
    return 0;
}

"""
register_Boolean —  will call this to install Boolean on the global
object with its prototype methods.  Stub returns 0.
"""
def:pub register_Boolean -> int {
    return 0;
}
