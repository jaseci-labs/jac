"""Native math algorithms over retained Python numeric values.

Balanced integer products and adaptive-precision square roots avoid linear
chains of growing intermediate integers. Derived from CPython 3.14.6;
see ../LICENSE.cpython.
"""
import from jaclang.runtime.python.capi {
    jacpy_retain,
    jacpy_release,
    jacpy_int,
    jacpy_boolean,
    jacpy_index,
    jacpy_abs,
    jacpy_tuple_size,
    jacpy_tuple_item,
    jacpy_long_sign,
    jacpy_long_bits,
    jacpy_long_gcd,
    jacpy_long_shift,
    jacpy_integer_value,
    jacpy_uint,
    jacpy_add,
    jacpy_sub,
    jacpy_mul,
    jacpy_floordiv,
    jacpy_compare_bool,
    jacpy_is_none,
    jacpy_error_pending,
    object_error,
    required,
    boundary_failure
}

import from jaclang.runtime.python.modules.numeric {
    acos,
    acosh,
    asin,
    asinh,
    atan,
    atanh,
    cbrt,
    cos,
    cosh,
    erf,
    erfc,
    exp,
    exp2,
    expm1,
    fabs,
    tgamma,
    lgamma,
    log1p,
    sin,
    sinh,
    sqrt,
    tan,
    tanh,
    ceil,
    floor,
    log,
    log10,
    log2,
    nextafter,
    copysign,
    atan2,
    fmod,
    remainder,
    pow,
    fma,
    isfinite,
    isinf,
    isnan,
    infinity,
    nan,
    scaled
}
import from jaclang.runtime.python.capi {
    jacpy_number_as_double,
    jacpy_float,
    jacpy_clear_errno,
    jacpy_math_errno,
    jacpy_special_noargs,
    jacpy_long_from_double,
    jacpy_libm_parts,
    jacpy_float_bits,
    jacpy_float_from_bits,
    jacpy_is_long,
    jacpy_long_frexp,
    jacpy_long_double,
    jacpy_long_u64,
    jacpy_clear_error,
    repr_value,
    type_name
}

import from jaclang.runtime.python.capi {
    jacpy_iter,
    jacpy_iter_next,
    jacpy_sequence_tuple,
    jacpy_is_tuple,
    jacpy_is_exact_long,
    jacpy_is_exact_float,
    jacpy_is_bool,
    jacpy_long_fits_i64
}

def:priv bits(value: i64) -> int {
    n = value;
    result = 0;
    while n > 0 {
        result += 1;
        n >>= 1;
    }
    return result;
}

def:pub jacpy_math_gcd(arguments: u64, lcm: i64) -> u64 {
    result: u64 = 0;
    try {
        result = required(jacpy_int(1 if lcm != 0 else 0));
        for i in range(int(jacpy_tuple_size(arguments))) {
            argument: u64 = 0;
            indexed: u64 = 0;
            absolute: u64 = 0;
            divisor: u64 = 0;
            quotient: u64 = 0;
            try {
                argument = required(jacpy_tuple_item(arguments, i64(i)));
                indexed = required(jacpy_index(argument));
                absolute = required(jacpy_abs(indexed));
                divisor = required(jacpy_long_gcd(result, absolute));
                replacement: u64 = 0;
                if lcm == 0 {
                    replacement = jacpy_retain(divisor);
                } elif jacpy_long_sign(result) == 0 or jacpy_long_sign(absolute) == 0 {
                    replacement = required(jacpy_int(0));
                } else {
                    quotient = required(jacpy_floordiv(result, divisor));
                    replacement = required(jacpy_mul(quotient, absolute));
                }
                jacpy_release(result);
                result = replacement;
            } finally {
                jacpy_release(argument);
                jacpy_release(indexed);
                jacpy_release(absolute);
                jacpy_release(divisor);
                jacpy_release(quotient);
            }
        }
        return jacpy_retain(result);
    } except boundary_failure {
        return 0;
    } finally {
        jacpy_release(result);
    }
}

def:priv odd_product(start: i64, stop: i64) -> u64 {
    count = (stop - start) // 2;
    if count <= 64 and count * i64(bits(stop - 2)) <= 64 {
        product: u64 = 1;
        for i in range(int(start), int(stop), 2) {
            product *= u64(i);
        }
        return required(jacpy_uint(product));
    }
    middle = (start + count) | i64(1);
    left: u64 = 0;
    right: u64 = 0;
    try {
        left = odd_product(start, middle);
        right = odd_product(middle, stop);
        return required(jacpy_mul(left, right));
    } finally {
        jacpy_release(left);
        jacpy_release(right);
    }
}

def:pub jacpy_math_factorial(argument: u64) -> u64 {
    value: u64 = 0;
    inner: u64 = 0;
    outer: u64 = 0;
    try {
        value = required(jacpy_index(argument));
        if jacpy_long_sign(value) < 0 {
            object_error("ValueError", "factorial() not defined for negative values");
            return 0;
        }
        if jacpy_long_bits(value) > 63 {
            object_error(
                "OverflowError",
                "factorial() argument should not exceed 9223372036854775807"
            );
            return 0;
        }
        n = jacpy_integer_value(value);
        inner = required(jacpy_int(1));
        outer = jacpy_retain(inner);
        upper: i64 = 3;
        for i in range(bits(n) - 2, -1, -1) {
            v = n >> i64(i);
            if v <= 2 {
                continue;
            }
            lower = upper;
            upper = (v + 1) | i64(1);
            partial = odd_product(lower, upper);
            try {
                replacement = required(jacpy_mul(inner, partial));
                jacpy_release(inner);
                inner = replacement;
                replacement = required(jacpy_mul(outer, inner));
                jacpy_release(outer);
                outer = replacement;
            } finally {
                jacpy_release(partial);
            }
        }
        remaining = n;
        ones: i64 = 0;
        while remaining != 0 {
            ones += remaining & i64(1);
            remaining >>= i64(1);
        }
        return required(jacpy_long_shift(outer, n - ones, 1));
    } except boundary_failure {
        return 0;
    } finally {
        jacpy_release(value);
        jacpy_release(inner);
        jacpy_release(outer);
    }
}

def:pub jacpy_math_isqrt(argument: u64) -> u64 {
    n: u64 = 0;
    approximation: u64 = 0;
    square: u64 = 0;
    try {
        n = required(jacpy_index(argument));
        sign = jacpy_long_sign(n);
        if sign < 0 {
            object_error("ValueError", "isqrt() argument must be nonnegative");
            return 0;
        }
        if sign == 0 {
            return required(jacpy_int(0));
        }
        c = (jacpy_long_bits(n) - 1) // 2;
        approximation = required(jacpy_int(1));
        d: i64 = 0;
        for s in range(bits(c) - 1, -1, -1) {
            e = d;
            d = c >> i64(s);
            shifted: u64 = 0;
            quotient: u64 = 0;
            prefix: u64 = 0;
            try {
                shifted = required(jacpy_long_shift(n, 2 * c - e - d + 1, 0));
                quotient = required(jacpy_floordiv(shifted, approximation));
                prefix = required(jacpy_long_shift(approximation, d - e - 1, 1));
                replacement = required(jacpy_add(prefix, quotient));
                jacpy_release(approximation);
                approximation = replacement;
            } finally {
                jacpy_release(shifted);
                jacpy_release(quotient);
                jacpy_release(prefix);
            }
        }
        square = required(jacpy_mul(approximation, approximation));
        too_large = jacpy_compare_bool(square, n, 4);
        if too_large < 0 {
            return 0;
        }
        if too_large != 0 {
            one = required(jacpy_int(1));
            try {
                return required(jacpy_sub(approximation, one));
            } finally {
                jacpy_release(one);
            }
        }
        return jacpy_retain(approximation);
    } except boundary_failure {
        return 0;
    } finally {
        jacpy_release(n);
        jacpy_release(approximation);
        jacpy_release(square);
    }
}

# Balanced recursive products keep operand sizes similar for long multiplication.
def:priv perm_comb(n: u64, k: i64, combination: bool) -> u64 {
    if k == 0 {
        return required(jacpy_int(1));
    }
    if k == 1 {
        return jacpy_retain(n);
    }
    middle = k // 2;
    left: u64 = 0;
    right: u64 = 0;
    offset: u64 = 0;
    remaining: u64 = 0;
    product: u64 = 0;
    denominator: u64 = 0;
    count: u64 = 0;
    try {
        left = perm_comb(n, middle, combination);
        offset = required(jacpy_int(middle));
        remaining = required(jacpy_sub(n, offset));
        right = perm_comb(remaining, k - middle, combination);
        product = required(jacpy_mul(left, right));
        if not combination {
            return jacpy_retain(product);
        }
        count = required(jacpy_int(k));
        denominator = perm_comb(count, middle, True);
        return required(jacpy_floordiv(product, denominator));
    } finally {
        jacpy_release(left);
        jacpy_release(right);
        jacpy_release(offset);
        jacpy_release(remaining);
        jacpy_release(product);
        jacpy_release(denominator);
        jacpy_release(count);
    }
}

def:pub jacpy_math_comb(n_arg: u64, k_arg: u64, combination: i64) -> u64 {
    if combination == 0 and (k_arg == 0 or jacpy_is_none(k_arg) != 0) {
        return jacpy_math_factorial(n_arg);
    }
    n: u64 = 0;
    k: u64 = 0;
    difference: u64 = 0;
    try {
        n = required(jacpy_index(n_arg));
        k = required(jacpy_index(k_arg));
        if jacpy_long_sign(n) < 0 {
            object_error("ValueError", "n must be a non-negative integer");
            return 0;
        }
        if jacpy_long_sign(k) < 0 {
            object_error("ValueError", "k must be a non-negative integer");
            return 0;
        }
        comparison = jacpy_compare_bool(k, n, 4);
        if comparison < 0 {
            return 0;
        }
        if comparison != 0 {
            return required(jacpy_int(0));
        }
        if combination != 0 {
            difference = required(jacpy_sub(n, k));
            comparison = jacpy_compare_bool(difference, k, 0);
            if comparison < 0 {
                return 0;
            }
            if comparison != 0 {
                jacpy_release(k);
                k = jacpy_retain(difference);
            }
        }
        if jacpy_long_bits(k) > 63 {
            object_error(
                "OverflowError",
                ("min(n - k, k)" if combination != 0 else "k")
                    + " must not exceed 9223372036854775807"
            );
            return 0;
        }
        count = jacpy_integer_value(k);
        if jacpy_error_pending() != 0 {
            return 0;
        }
        return perm_comb(n, count, combination != 0);
    } except boundary_failure {
        return 0;
    } finally {
        jacpy_release(n);
        jacpy_release(k);
        jacpy_release(difference);
    }
}

def:priv input_float(value: u64) -> float {
    result = jacpy_number_as_double(value);
    if jacpy_error_pending() != 0 {
        raise boundary_failure();
    }
    return result;
}

def:priv float_repr(value: float) -> str {
    object = required(jacpy_float(value));
    try {
        return repr_value(object);
    } finally {
        jacpy_release(object);
    }
}

def:priv domain(operation: i64, value: float) {
    message = "math domain error";
    if operation == 0 or operation == 2 {
        message = "expected a number in range from -1 up to 1, got "
            + float_repr(value);
    } elif operation == 1 {
        message = "expected argument value not less than 1, got " + float_repr(value);
    } elif operation == 5 {
        message = "expected a number between -1 and 1, got " + float_repr(value);
    } elif operation == 7 or operation == 18 or operation == 21 {
        message = "expected a finite input, got " + float_repr(value);
    } elif operation == 15 or operation == 16 {
        message = "expected a noninteger or positive integer, got " + float_repr(value);
    } elif operation == 17 {
        message = "expected argument value > -1, got " + float_repr(value);
    } elif operation == 20 {
        message = "expected a nonnegative input, got " + float_repr(value);
    }
    object_error("ValueError", message);
}

def:priv logarithm(value: u64, base: int) -> float {
    if jacpy_is_long(value) != 0 {
        if jacpy_long_sign(value) <= 0 {
            object_error("ValueError", "expected a positive input");
            raise boundary_failure();
        }
        x = jacpy_long_double(value);
        if jacpy_error_pending() != 0 {
            jacpy_clear_error();
            parts = required(jacpy_long_frexp(value));
            fraction: u64 = 0;
            exponent: u64 = 0;
            try {
                fraction = required(jacpy_tuple_item(parts, 0));
                exponent = required(jacpy_tuple_item(parts, 1));
                x = input_float(fraction);
                power = float(jacpy_integer_value(exponent));
                if base == 2 {
                    return log2(x) + power;
                }
                if base == 10 {
                    return log10(x) + power * log10(2.0);
                }
                return log(x) + power * log(2.0);
            } finally {
                jacpy_release(parts);
                jacpy_release(fraction);
                jacpy_release(exponent);
            }
        }
        if base == 2 {
            return log2(x);
        }
        if base == 10 {
            return log10(x);
        }
        return log(x);
    }
    x = input_float(value);
    if x <= 0.0 {
        object_error("ValueError", "expected a positive input, got " + float_repr(x));
        raise boundary_failure();
    }
    if base == 2 {
        return log2(x);
    }
    if base == 10 {
        return log10(x);
    }
    return log(x);
}

def:pub jacpy_math_log(value: u64, base: u64) -> u64 {
    try {
        numerator = logarithm(value, 0);
        if base == 0 {
            return required(jacpy_float(numerator));
        }
        denominator = logarithm(base, 0);
        if denominator == 0.0 {
            object_error("ZeroDivisionError", "division by zero");
            return 0;
        }
        return required(jacpy_float(numerator / denominator));
    } except boundary_failure {
        return 0;
    }
}

# Operation IDs are shared with the native method declarations in bindings/math.jac.
def:pub jacpy_math_unary(operation: i64, value: u64) -> u64 {
    try {
        if operation >= 28 and operation <= 30 {
            name = "__ceil__"
                if operation == 28
                else "__floor__" if operation == 29 else "__trunc__";
            result_object = jacpy_special_noargs(value, name);
            if result_object != 0 or jacpy_error_pending() != 0 {
                return result_object;
            }
            if operation == 30 {
                object_error(
                    "TypeError",
                    "type " + type_name(value) + " doesn't define __trunc__ method"
                );
                return 0;
            }
        }
        if operation == 31 {
            return required(jacpy_float(logarithm(value, 10)));
        }
        if operation == 32 {
            return required(jacpy_float(logarithm(value, 2)));
        }
        x = input_float(value);
        if operation == 25 {
            return required(jacpy_boolean(1 if isfinite(x) else 0));
        }
        if operation == 26 {
            return required(jacpy_boolean(1 if isinf(x) else 0));
        }
        if operation == 27 {
            return required(jacpy_boolean(1 if isnan(x) else 0));
        }
        if operation == 28 {
            return required(jacpy_long_from_double(ceil(x)));
        }
        if operation == 29 {
            return required(jacpy_long_from_double(floor(x)));
        }
        if operation == 33 {
            if isnan(x) {
                return required(jacpy_float(x));
            }
            x = fabs(x);
            if isinf(x) {
                return required(jacpy_float(x));
            }
            following = nextafter(x, infinity);
            if isinf(following) {
                return required(jacpy_float(x - nextafter(x, -infinity)));
            }
            return required(jacpy_float(following - x));
        }
        jacpy_clear_errno();
        result: float = 0.0;
        if operation == 0 {
            result = acos(x);
        } elif operation == 1 {
            result = acosh(x);
        } elif operation == 2 {
            result = asin(x);
        } elif operation == 3 {
            result = asinh(x);
        } elif operation == 4 {
            result = atan(x);
        } elif operation == 5 {
            result = atanh(x);
        } elif operation == 6 {
            result = cbrt(x);
        } elif operation == 7 {
            result = cos(x);
        } elif operation == 8 {
            result = cosh(x);
        } elif operation == 9 {
            result = erf(x);
        } elif operation == 10 {
            result = erfc(x);
        } elif operation == 11 {
            result = exp(x);
        } elif operation == 12 {
            result = exp2(x);
        } elif operation == 13 {
            result = expm1(x);
        } elif operation == 14 {
            result = fabs(x);
        } elif operation == 15 {
            result = tgamma(x);
        } elif operation == 16 {
            result = lgamma(x);
        } elif operation == 17 {
            result = log1p(x);
        } elif operation == 18 {
            result = sin(x);
        } elif operation == 19 {
            result = sinh(x);
        } elif operation == 20 {
            result = sqrt(x);
        } elif operation == 21 {
            result = tan(x);
        } elif operation == 22 {
            result = tanh(x);
        } elif operation == 23 {
            return required(jacpy_float(x * 57.2957795130823208768));
        } elif operation == 24 {
            return required(jacpy_float(x * 0.0174532925199432957692));
        }
        error = jacpy_math_errno();
        overflow = operation == 8
            or operation == 11
            or operation == 12
            or operation == 13
            or operation == 15
            or operation == 16
            or operation == 19;
        if (isnan(result) and not isnan(x))
            or error == 1
            or (isinf(result) and isfinite(x) and not overflow) {
            domain(operation, x);
            return 0;
        }
        if (isinf(result) and isfinite(x)) or (error == 2 and fabs(result) >= 1.0) {
            if (operation == 15 or operation == 16) and x <= 0.0 and x == floor(x) {
                domain(operation, x);
            } else {
                object_error("OverflowError", "math range error");
            }
            return 0;
        }
        return required(jacpy_float(result));
    } except boundary_failure {
        return 0;
    }
}

def:pub jacpy_math_binary(operation: i64, a: u64, b: u64) -> u64 {
    try {
        x = input_float(a);
        y = input_float(b);
        jacpy_clear_errno();
        result: float = 0.0;
        if operation == 0 {
            result = atan2(x, y);
        } elif operation == 1 {
            result = copysign(x, y);
        } elif operation == 2 {
            result = fmod(x, y);
        } elif operation == 3 {
            result = remainder(x, y);
        } else {
            result = pow(x, y);
        }
        error = jacpy_math_errno();
        if isnan(result) {
            if not isnan(x) and not isnan(y) {
                object_error("ValueError", "math domain error");
                return 0;
            }
            error = 0;
        } elif isinf(result) {
            if isfinite(x) and isfinite(y) {
                object_error(
                    "ValueError" if operation == 4 and x == 0.0 else "OverflowError",
                    "math domain error"
                        if operation == 4 and x == 0.0
                        else "math range error"
                );
                return 0;
            }
            error = 0;
        }
        if error == 1 {
            object_error("ValueError", "math domain error");
            return 0;
        }
        if error == 2 and fabs(result) >= 1.0 {
            object_error("OverflowError", "math range error");
            return 0;
        }
        return required(jacpy_float(result));
    } except boundary_failure {
        return 0;
    }
}

def:pub jacpy_math_parts(operation: i64, value: u64) -> u64 {
    try {
        return required(jacpy_libm_parts(input_float(value), operation));
    } except boundary_failure {
        return 0;
    }
}

def:pub jacpy_math_ldexp(value: u64, exponent: u64) -> u64 {
    try {
        x = input_float(value);
        if jacpy_is_long(exponent) == 0 {
            object_error("TypeError", "Expected an int as second argument to ldexp.");
            return 0;
        }
        if x == 0.0 or not isfinite(x) {
            return required(jacpy_float(x));
        }
        sign = jacpy_long_sign(exponent);
        if jacpy_long_bits(exponent) > 31 {
            if sign > 0 {
                object_error("OverflowError", "math range error");
                return 0;
            }
            return required(jacpy_float(copysign(0.0, x)));
        }
        result = scaled(x, int(jacpy_integer_value(exponent)));
        if isinf(result) {
            object_error("OverflowError", "math range error");
            return 0;
        }
        return required(jacpy_float(result));
    } except boundary_failure {
        return 0;
    }
}

def:pub jacpy_math_fma(a: u64, b: u64, c: u64) -> u64 {
    try {
        x = input_float(a);
        y = input_float(b);
        z = input_float(c);
        result = fma(x, y, z);
        if isnan(result) and not isnan(x) and not isnan(y) and not isnan(z) {
            object_error("ValueError", "invalid operation in fma");
            return 0;
        }
        if isinf(result) and isfinite(x) and isfinite(y) and isfinite(z) {
            object_error("OverflowError", "overflow in fma");
            return 0;
        }
        return required(jacpy_float(result));
    } except boundary_failure {
        return 0;
    }
}

def:pub jacpy_math_isclose(a: u64, b: u64, rel: u64, abs_tol: u64) -> u64 {
    try {
        x = input_float(a);
        y = input_float(b);
        relative = input_float(rel) if rel != 0 else 1e-9;
        absolute = input_float(abs_tol) if abs_tol != 0 else 0.0;
        if relative < 0.0 or absolute < 0.0 {
            object_error("ValueError", "tolerances must be non-negative");
            return 0;
        }
        if x == y {
            return required(jacpy_boolean(1));
        }
        if isinf(x) or isinf(y) {
            return required(jacpy_boolean(0));
        }
        difference = fabs(y - x);
        return required(
            jacpy_boolean(
                1
                    if difference <= fabs(relative * x)
                        or difference <= fabs(relative * y)
                        or difference <= absolute
                    else 0
            )
        );
    } except boundary_failure {
        return 0;
    }
}

def:pub jacpy_math_nextafter(a: u64, b: u64, steps: u64) -> u64 {
    count_object: u64 = 0;
    try {
        x = input_float(a);
        y = input_float(b);
        count: u64 = 1;
        if steps == 0 or jacpy_is_none(steps) != 0 {
            return required(jacpy_float(nextafter(x, y)));
        }
        if steps != 0 {
            count_object = required(jacpy_index(steps));
            if jacpy_long_sign(count_object) < 0 {
                object_error("ValueError", "steps must be a non-negative integer");
                return 0;
            }
            count = u64(18446744073709551615)
                if jacpy_long_bits(count_object) > 64
                else jacpy_long_u64(count_object);
        }
        if count == 0 {
            return required(jacpy_float(x));
        }
        if x == y {
            return required(jacpy_float(y));
        }
        if isnan(x) {
            return required(jacpy_float(x));
        }
        if isnan(y) {
            return required(jacpy_float(y));
        }
        sign: u64 = 9223372036854775808;
        first = jacpy_float_bits(x);
        last = jacpy_float_bits(y);
        first_magnitude = first & (sign - u64(1));
        last_magnitude = last & (sign - u64(1));
        if (first & sign) != (last & sign) {
            distance = first_magnitude + last_magnitude;
            if count >= distance {
                return required(jacpy_float(y));
            }
            if count <= first_magnitude {
                return required(
                    jacpy_float(
                        jacpy_float_from_bits(
                            (first & sign) | (first_magnitude - count)
                        )
                    )
                );
            }
            return required(
                jacpy_float(
                    jacpy_float_from_bits((last & sign) | (count - first_magnitude))
                )
            );
        }
        distance = first_magnitude - last_magnitude
            if first_magnitude > last_magnitude
            else last_magnitude - first_magnitude;
        if count >= distance {
            return required(jacpy_float(y));
        }
        result_bits = first - count
            if first_magnitude > last_magnitude
            else first + count;
        return required(jacpy_float(jacpy_float_from_bits(result_bits)));
    } except boundary_failure {
        return 0;
    } finally {
        jacpy_release(count_object);
    }
}

def:pub jacpy_math_fsum(iterable: u64) -> u64 {
    iterator: u64 = 0;
    try {
        iterator = required(jacpy_iter(iterable));
        partials: list[float] = [];
        special: float = 0.0;
        infinities: float = 0.0;
        low: float = 0.0;
        while True {
            item = jacpy_iter_next(iterator);
            if item == 0 {
                break;
            }
            x: float = 0.0;
            try {
                x = input_float(item);
            } finally {
                jacpy_release(item);
            }
            original = x;
            count = 0;
            for j in range(len(partials)) {
                y = partials[j];
                if fabs(x) < fabs(y) {
                    temporary = x;
                    x = y;
                    y = temporary;
                }
                high = x + y;
                rounded = high - x;
                low = y - rounded;
                if low != 0.0 {
                    partials[count] = low;
                    count += 1;
                }
                x = high;
            }
            while len(partials) > count {
                partials.pop();
            }
            if x != 0.0 {
                if not isfinite(x) {
                    if isfinite(original) {
                        object_error("OverflowError", "intermediate overflow in fsum");
                        return 0;
                    }
                    if isinf(original) {
                        infinities += original;
                    }
                    special += original;
                    partials.clear();
                } else {
                    partials.append(x);
                }
            }
        }
        if jacpy_error_pending() != 0 {
            return 0;
        }
        if special != 0.0 {
            if isnan(infinities) {
                object_error("ValueError", "-inf + inf in fsum");
                return 0;
            }
            return required(jacpy_float(special));
        }
        high: float = 0.0;
        if partials {
            high = partials.pop();
            while partials {
                x = high;
                y = partials.pop();
                high = x + y;
                rounded = high - x;
                low = y - rounded;
                if low != 0.0 {
                    break;
                }
            }
            if partials
                and (
                    (low < 0.0 and partials[-1] < 0.0)
                    or (low > 0.0 and partials[-1] > 0.0)
                ) {
                y = low * 2.0;
                x = high + y;
                rounded = x - high;
                if y == rounded {
                    high = x;
                }
            }
        }
        return required(jacpy_float(high));
    } except boundary_failure {
        return 0;
    } finally {
        jacpy_release(iterator);
    }
}

# Error-free transforms used by both norm and dot-product accumulation.
def:priv double_sum(a: float, b: float) -> tuple[float, float] {
    high = a + b;
    rounded = high - a;
    return (high, (a - (high - rounded)) + (b - rounded));
}

def:priv fast_sum(a: float, b: float) -> tuple[float, float] {
    high = a + b;
    return (high, (a - high) + b);
}

def:priv double_product(a: float, b: float) -> tuple[float, float] {
    high = a * b;
    return (high, fma(a, b, -high));
}

def:priv triple_product(
    a: float, b: float, total: tuple[float, float, float]
) -> tuple[float, float, float] {
    product = double_product(a, b);
    high = double_sum(total[0], product[0]);
    first = double_sum(total[1], product[1]);
    second = double_sum(first[0], high[1]);
    return (high[0], second[0], total[2] + first[1] + second[1]);
}

def:priv triple_value(total: tuple[float, float, float]) -> float {
    last = double_sum(total[1], total[0]);
    return total[2] + last[1] + last[0];
}

def:priv norm(values: list[float], largest: float, found_nan: bool) -> float {
    if isinf(largest) {
        return largest;
    }
    if found_nan {
        return nan;
    }
    if largest == 0.0 or len(values) <= 1 {
        return largest;
    }
    parts = required(jacpy_libm_parts(largest, 0));
    exponent: u64 = 0;
    scale: float = 0.0;
    try {
        exponent = required(jacpy_tuple_item(parts, 1));
        power = int(jacpy_integer_value(exponent));
        if power < -1023 {
            for i in range(len(values)) {
                values[i] /= 2.2250738585072014e-308;
            }
            return 2.2250738585072014e-308
                * norm(values, largest / 2.2250738585072014e-308, found_nan);
        }
        scale = scaled(1.0, -power);
    } finally {
        jacpy_release(parts);
        jacpy_release(exponent);
    }
    total: float = 1.0;
    fraction1: float = 0.0;
    fraction2: float = 0.0;
    for value in values {
        x = value * scale;
        product = double_product(x, x);
        addition = fast_sum(total, product[0]);
        total = addition[0];
        fraction1 += product[1];
        fraction2 += addition[1];
    }
    result = sqrt(total - 1.0 + (fraction1 + fraction2));
    correction = double_product(-result, result);
    addition = fast_sum(total, correction[0]);
    total = addition[0];
    fraction1 += correction[1];
    fraction2 += addition[1];
    residual = total - 1.0 + (fraction1 + fraction2);
    result += residual / (2.0 * result);
    return result / scale;
}

def:pub jacpy_math_hypot(arguments: u64) -> u64 {
    try {
        values: list[float] = [];
        largest: float = 0.0;
        found_nan = False;
        for i in range(int(jacpy_tuple_size(arguments))) {
            item = required(jacpy_tuple_item(arguments, i64(i)));
            x: float = 0.0;
            try {
                x = fabs(input_float(item));
            } finally {
                jacpy_release(item);
            }
            values.append(x);
            found_nan = found_nan or isnan(x);
            if x > largest {
                largest = x;
            }
        }
        return required(jacpy_float(norm(values, largest, found_nan)));
    } except boundary_failure {
        return 0;
    }
}

def:pub jacpy_math_dist(a: u64, b: u64) -> u64 {
    left: u64 = 0;
    right: u64 = 0;
    try {
        left = required(
            jacpy_retain(a) if jacpy_is_tuple(a) != 0 else jacpy_sequence_tuple(a)
        );
        right = required(
            jacpy_retain(b) if jacpy_is_tuple(b) != 0 else jacpy_sequence_tuple(b)
        );
        count = jacpy_tuple_size(left);
        if count != jacpy_tuple_size(right) {
            object_error(
                "ValueError", "both points must have the same number of dimensions"
            );
            return 0;
        }
        values: list[float] = [];
        largest: float = 0.0;
        found_nan = False;
        for i in range(int(count)) {
            first = required(jacpy_tuple_item(left, i64(i)));
            second: u64 = 0;
            distance: float = 0.0;
            try {
                x = input_float(first);
                second = required(jacpy_tuple_item(right, i64(i)));
                distance = fabs(x - input_float(second));
            } finally {
                jacpy_release(first);
                jacpy_release(second);
            }
            values.append(distance);
            found_nan = found_nan or isnan(distance);
            if distance > largest {
                largest = distance;
            }
        }
        return required(jacpy_float(norm(values, largest, found_nan)));
    } except boundary_failure {
        return 0;
    } finally {
        jacpy_release(left);
        jacpy_release(right);
    }
}

def:pub jacpy_math_prod(iterable: u64, start: u64) -> u64 {
    iterator: u64 = 0;
    result: u64 = 0;
    try {
        result = required(jacpy_int(1) if start == 0 else jacpy_retain(start));
        iterator = required(jacpy_iter(iterable));
        while True {
            value = jacpy_iter_next(iterator);
            if value == 0 {
                break;
            }
            try {
                replacement = required(jacpy_mul(result, value));
                jacpy_release(result);
                result = replacement;
            } finally {
                jacpy_release(value);
            }
        }
        if jacpy_error_pending() != 0 {
            return 0;
        }
        return jacpy_retain(result);
    } except boundary_failure {
        return 0;
    } finally {
        jacpy_release(iterator);
        jacpy_release(result);
    }
}

def:pub jacpy_math_sumprod(a: u64, b: u64) -> u64 {
    left: u64 = 0;
    right: u64 = 0;
    result: u64 = 0;
    try {
        left = required(jacpy_iter(a));
        right = required(jacpy_iter(b));
        result = required(jacpy_int(0));
        float_enabled = True;
        float_used = False;
        integer_prefix = True;
        total: tuple[float, float, float] = (0.0, 0.0, 0.0);
        while True {
            first = jacpy_iter_next(left);
            second: u64 = 0;
            term: u64 = 0;
            try {
                if first == 0 and jacpy_error_pending() != 0 {
                    return 0;
                }
                second = jacpy_iter_next(right);
                if second == 0 and jacpy_error_pending() != 0 {
                    return 0;
                }
                if (first == 0) != (second == 0) {
                    object_error("ValueError", "Inputs are not the same length");
                    return 0;
                }
                finished = first == 0;
                if not finished
                    and integer_prefix
                    and jacpy_is_exact_long(first) != 0
                    and jacpy_is_exact_long(second) != 0 {
                    term = required(jacpy_mul(first, second));
                    replacement = required(jacpy_add(result, term));
                    if jacpy_long_fits_i64(first) != 0
                        and jacpy_long_fits_i64(second) != 0
                        and jacpy_long_fits_i64(term) != 0
                        and jacpy_long_fits_i64(replacement) != 0 {
                        jacpy_release(result);
                        result = replacement;
                        continue;
                    }
                    jacpy_release(replacement);
                    jacpy_release(term);
                    term = u64(0);
                }
                integer_prefix = False;
                if float_enabled {
                    eligible = False;
                    if not finished {
                        first_float = jacpy_is_exact_float(first) != 0;
                        second_float = jacpy_is_exact_float(second) != 0;
                        eligible = (first_float and second_float)
                            or (
                                first_float
                                and (
                                    jacpy_is_exact_long(second) != 0
                                    or jacpy_is_bool(second) != 0
                                )
                            )
                            or (
                                second_float
                                and (
                                    jacpy_is_exact_long(first) != 0
                                    or jacpy_is_bool(first) != 0
                                )
                            );
                    }
                    if eligible {
                        x = jacpy_number_as_double(first);
                        conversion_failed = jacpy_error_pending() != 0;
                        y: float = 0.0;
                        if not conversion_failed {
                            y = jacpy_number_as_double(second);
                            conversion_failed = jacpy_error_pending() != 0;
                        }
                        if conversion_failed {
                            jacpy_clear_error();
                        } else {
                            updated = triple_product(x, y, total);
                            if isfinite(updated[0]) {
                                total = updated;
                                float_used = True;
                                continue;
                            }
                        }
                    }
                    float_enabled = False;
                    if float_used {
                        term = required(jacpy_float(triple_value(total)));
                        replacement = required(jacpy_add(result, term));
                        jacpy_release(result);
                        result = replacement;
                        jacpy_release(term);
                        term = u64(0);
                    }
                }
                if finished {
                    return jacpy_retain(result);
                }
                term = required(jacpy_mul(first, second));
                replacement = required(jacpy_add(result, term));
                jacpy_release(result);
                result = replacement;
            } finally {
                jacpy_release(first);
                jacpy_release(second);
                jacpy_release(term);
            }
        }
    } except boundary_failure {
        return 0;
    } finally {
        jacpy_release(left);
        jacpy_release(right);
        jacpy_release(result);
    }
    return 0;
}
