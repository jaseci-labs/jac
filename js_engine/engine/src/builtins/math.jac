"""ES2023 Math object — native Jac implementations.

Each js_math_* function receives a list[JSValue] of arguments and
returns a JSValue.  All numeric inputs are coerced to float64 via the
helpers below.  The underlying arithmetic is provided by C libm via
the ffi/libm.na.jac bindings.

Bun reference:
  bun/src/bun.js/bindings/JSMathObject.cpp
"""

import from engine.src.runtime.jsvalue {
    JSValue,
    MATH_INF,
    MATH_NEG_INF,
    MATH_NAN,
    js_nan,
    js_int,
    js_number,
    f32_bits_to_double,
    double_to_f32_bits,
    jsv_is_int32,
    jsv_is_double,
    jsv_is_bool,
    jsv_is_null,
    jsv_is_string_cell,
    jsv_to_int32,
    jsv_to_double,
    jsv_to_bool,
    jsv_to_table_id,
    jsv_coerce_to_number
}

import from engine.src.ffi.libm {
    fabs,
    ceil,
    floor,
    round,
    trunc,
    sqrt,
    cbrt,
    pow,
    exp,
    expm1,
    log,
    log2,
    log10,
    log1p,
    sin,
    cos,
    tan,
    asin,
    acos,
    atan,
    atan2,
    sinh,
    cosh,
    tanh,
    asinh,
    acosh,
    atanh,
    hypot,
    fmax,
    fmin,
    time,
    srand48,
    drand48
}

import from engine.src.runtime.jsstring { str_from_id, str_to_float }
import from engine.src.vm.vm_obs { js_to_number_observable }
import from engine.src.runtime.error { vm_has_native_exc }

# ── Argument coercion helpers ─────────────────────────────────────────────────

"""Coerce args[i] to float64.  Missing / unconvertible → NaN."""
def _math_arg(args: list[JSValue], i: int) -> float {
    if i >= len(args) {
        return MATH_NAN;
    }
    v: JSValue = args[i];
    if jsv_is_int32(v) {
        return float(jsv_to_int32(v));
    }
    if jsv_is_double(v) {
        return jsv_to_double(v);
    }
    if jsv_is_bool(v) {
        if jsv_to_bool(v) {
            return 1.0;
        } else {
            return 0.0;
        }
    }
    if jsv_is_null(v) {
        return 0.0;
    }
    if jsv_is_string_cell(v) {
        return str_to_float(str_from_id(jsv_to_table_id(v)));
    }
    # Objects (valueOf / toString / @@toPrimitive), undefined, symbols:
    # the observable ToNumber (a throw is left on the native channel).
    return js_to_number_observable(v);
}

"""Coerce args[i] to int32 (ECMAScript ToInt32)."""
def _math_arg_i32(args: list[JSValue], i: int) -> int {
    f: float = _math_arg(args, i);
    if not (f == f) {
        return 0;
    }  # NaN → 0
    if f >= MATH_INF or f <= MATH_NEG_INF {
        return 0;
    }
    n: int = int(f);
    n = n & 0xFFFFFFFF;  # ToUint32
    if n >= 0x80000000 {
        n = n - 0x100000000;
    }  # ToInt32 sign-extend
    return n;
}

"""Return a float JSValue, but collapse NaN/±Inf correctly."""
def _ret_f(v: float) -> JSValue {
    return js_number(v);
}

"""True when v is negative zero.

-0 == 0 is true and -0 < 0 is false, so the sign is not recoverable by
comparison. Division (1.0 / v) would work in IEEE terms but traps on the native
backend, so the sign is read from the formatted value — the same approach
object.na.jac's _is_negative_zero uses."""
def _is_neg_zero(v: float) -> bool {
    if v != 0.0 {
        return False;
    }
    return str(v).startswith("-");
}

# ── One-time PRNG seed (called from global.na.jac at startup) ─────────────────

def js_math_seed_random {
    srand48(time(0));
}

# ── Math method implementations ───────────────────────────────────────────────

def js_math_abs(args: list[JSValue]) -> JSValue {
    return _ret_f(fabs(_math_arg(args, 0)));
}

def js_math_acos(args: list[JSValue]) -> JSValue {
    return _ret_f(acos(_math_arg(args, 0)));
}

def js_math_acosh(args: list[JSValue]) -> JSValue {
    return _ret_f(acosh(_math_arg(args, 0)));
}

def js_math_asin(args: list[JSValue]) -> JSValue {
    return _ret_f(asin(_math_arg(args, 0)));
}

def js_math_asinh(args: list[JSValue]) -> JSValue {
    return _ret_f(asinh(_math_arg(args, 0)));
}

def js_math_atan(args: list[JSValue]) -> JSValue {
    return _ret_f(atan(_math_arg(args, 0)));
}

def js_math_atan2(args: list[JSValue]) -> JSValue {
    y: float = _math_arg(args, 0);
    x: float = _math_arg(args, 1);
    return _ret_f(atan2(y, x));
}

def js_math_atanh(args: list[JSValue]) -> JSValue {
    return _ret_f(atanh(_math_arg(args, 0)));
}

def js_math_cbrt(args: list[JSValue]) -> JSValue {
    return _ret_f(cbrt(_math_arg(args, 0)));
}

def js_math_ceil(args: list[JSValue]) -> JSValue {
    return _ret_f(ceil(_math_arg(args, 0)));
}

"""Math.clz32 — count leading zero bits in the 32-bit representation."""
def js_math_clz32(args: list[JSValue]) -> JSValue {
    n: int = _math_arg_i32(args, 0);
    u: int = n & 0xFFFFFFFF;
    if u == 0 {
        return js_int(32);
    }
    count: int = 0;
    mask: int = 0x80000000;
    while mask > 0 {
        if (u & mask) != 0 {
            break;
        }
        count = count + 1;
        mask = mask >> 1;
    }
    return js_int(count);
}

def js_math_cos(args: list[JSValue]) -> JSValue {
    return _ret_f(cos(_math_arg(args, 0)));
}

def js_math_cosh(args: list[JSValue]) -> JSValue {
    return _ret_f(cosh(_math_arg(args, 0)));
}

def js_math_exp(args: list[JSValue]) -> JSValue {
    return _ret_f(exp(_math_arg(args, 0)));
}

def js_math_expm1(args: list[JSValue]) -> JSValue {
    return _ret_f(expm1(_math_arg(args, 0)));
}

def js_math_floor(args: list[JSValue]) -> JSValue {
    return _ret_f(floor(_math_arg(args, 0)));
}

"""Math.fround — coerce to nearest float32 and back to float64.
   Uses a cast via a temporary to force single-precision rounding.
   (In Jac native there is no float32; apply the double value directly
    — caller should not depend on exact float32 bit pattern.  TODO:
    add a C helper once cast builtins land.)"""
def js_math_fround(args: list[JSValue]) -> JSValue {
    return _ret_f(f32_bits_to_double(double_to_f32_bits(_math_arg(args, 0))));
}

"""Math.hypot — variadic, Euclidean distance: sqrt(Σ xᵢ²)."""
def js_math_hypot(args: list[JSValue]) -> JSValue {
    if len(args) == 0 {
        return js_int(0);
    }
    # ES §21.3.2.18: coerce every argument first, then apply the ordering rule —
    # if ANY argument is ±Infinity the result is +Infinity, *even when another
    # argument is NaN*. Only with no infinity does NaN propagate.
    vals: list[float] = [];
    saw_inf: bool = False;
    saw_nan: bool = False;
    i: int = 0;
    while i < len(args) {
        x: float = _math_arg(args, i);
        if x == MATH_INF or x == MATH_NEG_INF {
            saw_inf = True;
        } elif not (x == x) {
            saw_nan = True;
        }
        vals.append(x);
        i = i + 1;
    }
    if saw_inf {
        return js_number(MATH_INF);
    }
    if saw_nan {
        return js_nan();
    }
    if len(vals) == 1 {
        return _ret_f(fabs(vals[0]));
    }
    if len(vals) == 2 {
        return _ret_f(hypot(vals[0], vals[1]));
    }
    sum: float = 0.0;
    i = 0;
    while i < len(vals) {
        sum = sum + vals[i] * vals[i];
        i = i + 1;
    }
    return _ret_f(sqrt(sum));
}

"""Math.imul — C-style 32-bit integer multiplication."""
def js_math_imul(args: list[JSValue]) -> JSValue {
    fa: float = _math_arg(args, 0);
    fb: float = _math_arg(args, 1);
    if not (fa == fa) {
        fa = 0.0;
    }
    if not (fb == fb) {
        fb = 0.0;
    }
    # ToUint32 → sign-extend to int32 before multiplying so the product fits in i64
    a: int = int(fa) & 0xFFFFFFFF;
    if a >= 0x80000000 {
        a = a - 0x100000000;
    }
    b: int = int(fb) & 0xFFFFFFFF;
    if b >= 0x80000000 {
        b = b - 0x100000000;
    }
    result: int = (a * b) & 0xFFFFFFFF;
    if result >= 0x80000000 {
        result = result - 0x100000000;
    }
    return js_int(result);
}

def js_math_log(args: list[JSValue]) -> JSValue {
    return _ret_f(log(_math_arg(args, 0)));
}

def js_math_log10(args: list[JSValue]) -> JSValue {
    return _ret_f(log10(_math_arg(args, 0)));
}

def js_math_log1p(args: list[JSValue]) -> JSValue {
    return _ret_f(log1p(_math_arg(args, 0)));
}

def js_math_log2(args: list[JSValue]) -> JSValue {
    return _ret_f(log2(_math_arg(args, 0)));
}

"""Math.max — variadic; returns -Infinity on empty arg list."""
def js_math_max(args: list[JSValue]) -> JSValue {
    if len(args) == 0 {
        return js_number(MATH_NEG_INF);
    }
    # ES §21.3.2.24: coerce EVERY argument first (observable ToNumber side
    # effects must all run), then reduce. NaN anywhere wins, and +0 beats -0 —
    # fmax cannot express the latter, so zeros are compared by sign.
    vals: list[float] = [];
    saw_nan: bool = False;
    i: int = 0;
    while i < len(args) {
        x: float = _math_arg(args, i);
        if vm_has_native_exc() {
            return js_nan();
        }
        if not (x == x) {
            saw_nan = True;
        }
        vals.append(x);
        i = i + 1;
    }
    if saw_nan {
        return js_nan();
    }
    result: float = vals[0];
    i = 1;
    while i < len(vals) {
        x2: float = vals[i];
        if x2 > result {
            result = x2;
        } elif x2 == 0.0 and result == 0.0 and not _is_neg_zero(x2) {
            result = x2;
        }
        i = i + 1;
    }
    return _ret_f(result);
}

"""Math.min — variadic; returns +Infinity on empty arg list."""
def js_math_min(args: list[JSValue]) -> JSValue {
    if len(args) == 0 {
        return js_number(MATH_INF);
    }
    # Mirror of max: coerce all args, NaN wins, and -0 beats +0.
    vals: list[float] = [];
    saw_nan: bool = False;
    i: int = 0;
    while i < len(args) {
        x: float = _math_arg(args, i);
        if vm_has_native_exc() {
            return js_nan();
        }
        if not (x == x) {
            saw_nan = True;
        }
        vals.append(x);
        i = i + 1;
    }
    if saw_nan {
        return js_nan();
    }
    result: float = vals[0];
    i = 1;
    while i < len(vals) {
        x2: float = vals[i];
        if x2 < result {
            result = x2;
        } elif x2 == 0.0 and result == 0.0 and _is_neg_zero(x2) {
            result = x2;
        }
        i = i + 1;
    }
    return _ret_f(result);
}

"""ES §6.1.6.1.3 Number::exponentiate(base, exponent). Shared by both Math.pow
(§21.3.2.26) and the `**` operator (§13.6). Differs from C pow() in the two
cases C defines for IEEE compatibility but JS defines differently:
  * exponent ±0 → 1 for EVERY base, including NaN (`NaN ** 0` is 1, not NaN).
  * base whose magnitude is exactly 1 with an infinite exponent → NaN
    (C's pow(±1, ±Infinity) is 1)."""
def:pub _number_exponentiate(base: float, exp_v: float) -> float {
    # exponent ±0 → 1 (checked before the NaN-base guard so NaN ** 0 === 1).
    if exp_v == 0.0 {
        return 1.0;
    }
    if not (base == base) {
        return MATH_NAN;
    }
    abs_base: float = base;
    if abs_base < 0.0 {
        abs_base = -abs_base;
    }
    if abs_base == 1.0 and (exp_v == MATH_INF or exp_v == MATH_NEG_INF) {
        return MATH_NAN;
    }
    return pow(base, exp_v);
}

def js_math_pow(args: list[JSValue]) -> JSValue {
    base: float = _math_arg(args, 0);
    exp_v: float = _math_arg(args, 1);
    return _ret_f(_number_exponentiate(base, exp_v));
}

def js_math_random(args: list[JSValue]) -> JSValue {
    return _ret_f(drand48());
}

"""Math.round — round half up (towards +∞), matching ECMAScript."""
def js_math_round(args: list[JSValue]) -> JSValue {
    x: float = _math_arg(args, 0);
    if not (x == x) {
        return js_nan();
    }
    if x == MATH_INF or x == MATH_NEG_INF {
        return _ret_f(x);
    }
    # ES §21.3.2.28: the result is -0 when x is -0, and also when
    # -0.5 <= x < 0 (floor(x + 0.5) would give +0 there). Preserving the sign
    # matters because 1/Math.round(-0.5) must be -Infinity.
    if x == 0.0 {
        return _ret_f(x);
    }
    if x < 0.0 and x >= -0.5 {
        return _ret_f(-0.0);
    }
    return _ret_f(floor(x + 0.5));
}

"""Math.sign — returns -1, +0, -0, or 1 (NaN for NaN input)."""
def js_math_sign(args: list[JSValue]) -> JSValue {
    x: float = _math_arg(args, 0);
    if not (x == x) {
        return js_nan();
    }
    if x > 0.0 {
        return js_int(1);
    }
    if x < 0.0 {
        return js_int(-1);
    }
    # ES §21.3.2.29: zero is returned with its sign intact, so Math.sign(-0)
    # is -0, not +0. js_int(0) would collapse both to +0.
    return _ret_f(x);
}

def js_math_sin(args: list[JSValue]) -> JSValue {
    return _ret_f(sin(_math_arg(args, 0)));
}

def js_math_sinh(args: list[JSValue]) -> JSValue {
    return _ret_f(sinh(_math_arg(args, 0)));
}

def js_math_sqrt(args: list[JSValue]) -> JSValue {
    return _ret_f(sqrt(_math_arg(args, 0)));
}

def js_math_tan(args: list[JSValue]) -> JSValue {
    return _ret_f(tan(_math_arg(args, 0)));
}

def js_math_tanh(args: list[JSValue]) -> JSValue {
    return _ret_f(tanh(_math_arg(args, 0)));
}

def js_math_trunc(args: list[JSValue]) -> JSValue {
    return _ret_f(trunc(_math_arg(args, 0)));
}
