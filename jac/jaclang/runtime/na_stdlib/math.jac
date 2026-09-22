import from _math_native {
    m_acos,
    m_acosh,
    m_asin,
    m_asinh,
    m_atan,
    m_atanh,
    m_atan2,
    m_cbrt,
    m_ceil,
    m_copysign,
    m_cos,
    m_cosh,
    m_erf,
    m_erfc,
    m_exp,
    m_exp2,
    m_expm1,
    m_fabs,
    m_floor,
    m_fma,
    m_fmod,
    m_log,
    m_log2,
    m_log10,
    m_log1p,
    m_pow,
    m_remainder,
    m_sin,
    m_sinh,
    m_sqrt,
    m_tan,
    m_tanh,
    m_trunc
}
import from _math_fused { fmadd }

glob:pub pi: float = 3.141592653589793,
     e: float = 2.718281828459045,
     tau: float = 6.283185307179586,
     inf: float = float("inf"),
     nan: float = float("nan");

def:pub isnan(x: float) -> bool {
    return x != x;
}


def:pub isinf(x: float) -> bool {
    return m_fabs(x) > 1.7976931348623157e308;
}


def:pub isfinite(x: float) -> bool {
    return m_fabs(x) <= 1.7976931348623157e308;
}

def _domain_error(x: float, r: float, can_overflow: bool) -> bool {
    if isnan(r) {
        return not isnan(x);
    }
    return not can_overflow and isinf(r) and isfinite(x);
}


def _range_error(x: float, r: float) -> bool {
    return isinf(r) and isfinite(x);
}


def _got(prefix: str, x: float) -> str {
    return prefix + str(x);
}

def:pub acos(x: float) -> float {
    r = m_acos(x);
    if _domain_error(x, r, False) {
        raise ValueError(_got("expected a number in range from -1 up to 1, got ", x));
    }
    return r;
}


def:pub acosh(x: float) -> float {
    r = m_acosh(x);
    if _domain_error(x, r, False) {
        raise ValueError(_got("expected argument value not less than 1, got ", x));
    }
    return r;
}


def:pub asin(x: float) -> float {
    r = m_asin(x);
    if _domain_error(x, r, False) {
        raise ValueError(_got("expected a number in range from -1 up to 1, got ", x));
    }
    return r;
}


def:pub asinh(x: float) -> float {
    r = m_asinh(x);
    if _domain_error(x, r, False) {
        raise ValueError("math domain error");
    }
    return r;
}


def:pub atan(x: float) -> float {
    r = m_atan(x);
    if _domain_error(x, r, False) {
        raise ValueError("math domain error");
    }
    return r;
}


def:pub atanh(x: float) -> float {
    r = m_atanh(x);
    if _domain_error(x, r, False) {
        raise ValueError(_got("expected a number between -1 and 1, got ", x));
    }
    return r;
}


def:pub cbrt(x: float) -> float {
    r = m_cbrt(x);
    if _domain_error(x, r, False) {
        raise ValueError("math domain error");
    }
    return r;
}


def:pub cos(x: float) -> float {
    r = m_cos(x);
    if _domain_error(x, r, False) {
        raise ValueError(_got("expected a finite input, got ", x));
    }
    return r;
}


def:pub cosh(x: float) -> float {
    r = m_cosh(x);
    if _domain_error(x, r, True) {
        raise ValueError("math domain error");
    }
    if _range_error(x, r) {
        raise OverflowError("math range error");
    }
    return r;
}


def:pub erf(x: float) -> float {
    r = m_erf(x);
    if _domain_error(x, r, False) {
        raise ValueError("math domain error");
    }
    return r;
}


def:pub erfc(x: float) -> float {
    r = m_erfc(x);
    if _domain_error(x, r, False) {
        raise ValueError("math domain error");
    }
    return r;
}


def:pub exp(x: float) -> float {
    r = m_exp(x);
    if _domain_error(x, r, True) {
        raise ValueError("math domain error");
    }
    if _range_error(x, r) {
        raise OverflowError("math range error");
    }
    return r;
}


def:pub exp2(x: float) -> float {
    r = m_exp2(x);
    if _domain_error(x, r, True) {
        raise ValueError("math domain error");
    }
    if _range_error(x, r) {
        raise OverflowError("math range error");
    }
    return r;
}


def:pub expm1(x: float) -> float {
    r = m_expm1(x);
    if _domain_error(x, r, True) {
        raise ValueError("math domain error");
    }
    if _range_error(x, r) {
        raise OverflowError("math range error");
    }
    return r;
}


def:pub fabs(x: float) -> float {
    return m_fabs(x);
}


glob _LANCZOS_NUM: list[float] = [
         23531376880.410759688572007674451636754734846804940,
         42919803642.649098768957899047001988850926355848959,
         35711959237.355668049440185451547166705960488635843,
         17921034426.037209699919755754458931112671403265390,
         6039542586.3520280050642916443072979210699388420708,
         1439720407.3117216736632230727949123939715485786772,
         248874557.86205415651146038641322942321632125127801,
         31426415.585400194380614231628318205362874684987640,
         2876370.6289353724412254090516208496135991145378768,
         186056.26539522349504029498971604569928220784236328,
         8071.6720023658162106380029022722506138218516325024,
         210.82427775157934587250973392071336271166969580291,
         2.5066282746310002701649081771338373386264310793408
     ],
     _LANCZOS_DEN: list[float] = [
         0.0,
         39916800.0,
         120543840.0,
         150917976.0,
         105258076.0,
         45995730.0,
         13339535.0,
         2637558.0,
         357423.0,
         32670.0,
         1925.0,
         66.0,
         1.0
     ],
     _GAMMA_INTEGRAL: list[float] = [
         1.0,
         1.0,
         2.0,
         6.0,
         24.0,
         120.0,
         720.0,
         5040.0,
         40320.0,
         362880.0,
         3628800.0,
         39916800.0,
         479001600.0,
         6227020800.0,
         87178291200.0,
         1307674368000.0,
         20922789888000.0,
         355687428096000.0,
         6402373705728000.0,
         121645100408832000.0,
         2432902008176640000.0,
         51090942171709440000.0,
         1124000727777607680000.0
     ];

def _sinpi(x: float) -> float {
    y = m_fmod(m_fabs(x), 2.0);
    t = 2.0 * y;
    n = int(m_trunc(t));
    if t - float(n) >= 0.5 {
        n += 1;
    }
    r: float = 0.0;
    if n == 0 {
        r = m_sin(3.141592653589793 * y);
    } elif n == 1 {
        r = m_cos(3.141592653589793 * (y - 0.5));
    } elif n == 2 {
        r = m_sin(3.141592653589793 * (1.0 - y));
    } elif n == 3 {
        r = -m_cos(3.141592653589793 * (y - 1.5));
    } else {
        r = m_sin(3.141592653589793 * (y - 2.0));
    }
    return m_copysign(1.0, x) * r;
}


def _lanczos_sum(x: float) -> float {
    num: float = 0.0;
    den: float = 0.0;
    if x < 5.0 {
        i = 12;
        while i >= 0 {
            num = fmadd(num, x, _LANCZOS_NUM[i]);
            den = fmadd(den, x, _LANCZOS_DEN[i]);
            i -= 1;
        }
    } else {
        for i in range(13) {
            num = num / x + _LANCZOS_NUM[i];
            den = den / x + _LANCZOS_DEN[i];
        }
    }
    return num / den;
}


def _gamma_domain(x: float) -> str {
    return _got("expected a noninteger or positive integer, got ", x);
}


def:pub gamma(x: float) -> float {
    if not isfinite(x) {
        if isnan(x) or x > 0.0 {
            return x;
        }
        raise ValueError(_gamma_domain(x));
    }
    if x == 0.0 {
        raise ValueError(_gamma_domain(x));
    }
    if x == m_floor(x) {
        if x < 0.0 {
            raise ValueError(_gamma_domain(x));
        }
        if x <= 23.0 {
            return _GAMMA_INTEGRAL[int(x) - 1];
        }
    }
    absx = m_fabs(x);
    if absx < 1e-20 {
        tiny = 1.0 / x;
        if isinf(tiny) {
            raise OverflowError("math range error");
        }
        return tiny;
    }
    if absx > 200.0 {
        if x < 0.0 {
            return 0.0 / _sinpi(x);
        }
        raise OverflowError("math range error");
    }
    y = absx + 5.524680040776729583740234375;
    z: float = 0.0;
    if absx > 5.524680040776729583740234375 {
        q = y - absx;
        z = q - 5.524680040776729583740234375;
    } else {
        q = y - 5.524680040776729583740234375;
        z = q - absx;
    }
    z = z * 6.024680040776729583740234375 / y;
    r: float = 0.0;
    if x < 0.0 {
        r = -3.141592653589793 / _sinpi(absx) / absx * m_exp(y) / _lanczos_sum(absx);
        r = fmadd(-z, r, r);
        if absx < 140.0 {
            r /= m_pow(y, absx - 0.5);
        } else {
            sqrtpow = m_pow(y, absx / 2.0 - 0.25);
            r /= sqrtpow;
            r /= sqrtpow;
        }
    } else {
        r = _lanczos_sum(absx) / m_exp(y);
        r = fmadd(z, r, r);
        if absx < 140.0 {
            r *= m_pow(y, absx - 0.5);
        } else {
            sqrtpow = m_pow(y, absx / 2.0 - 0.25);
            r *= sqrtpow;
            r *= sqrtpow;
        }
    }
    if isinf(r) {
        raise OverflowError("math range error");
    }
    return r;
}


def:pub lgamma(x: float) -> float {
    if not isfinite(x) {
        if isnan(x) {
            return x;
        }
        return inf;
    }
    if x == m_floor(x) and x <= 2.0 {
        if x <= 0.0 {
            raise ValueError(_gamma_domain(x));
        }
        return 0.0;
    }
    absx = m_fabs(x);
    if absx < 1e-20 {
        return -m_log(absx);
    }
    r = m_log(_lanczos_sum(absx)) - 6.024680040776729583740234375;
    r = fmadd(absx - 0.5, m_log(absx + 6.024680040776729583740234375 - 0.5) - 1.0, r);
    if x < 0.0 {
        r = 1.1447298858494002 - m_log(m_fabs(_sinpi(absx))) - m_log(absx) - r;
    }
    if isinf(r) {
        raise OverflowError("math range error");
    }
    return r;
}


def:pub log1p(x: float) -> float {
    r = m_log1p(x);
    if _domain_error(x, r, False) {
        raise ValueError(_got("expected argument value > -1, got ", x));
    }
    return r;
}


def:pub sin(x: float) -> float {
    r = m_sin(x);
    if _domain_error(x, r, False) {
        raise ValueError(_got("expected a finite input, got ", x));
    }
    return r;
}


def:pub sinh(x: float) -> float {
    r = m_sinh(x);
    if _domain_error(x, r, True) {
        raise ValueError("math domain error");
    }
    if _range_error(x, r) {
        raise OverflowError("math range error");
    }
    return r;
}


def:pub sqrt(x: float) -> float {
    r = m_sqrt(x);
    if _domain_error(x, r, False) {
        raise ValueError(_got("expected a nonnegative input, got ", x));
    }
    return r;
}


def:pub tan(x: float) -> float {
    r = m_tan(x);
    if _domain_error(x, r, False) {
        raise ValueError(_got("expected a finite input, got ", x));
    }
    return r;
}


def:pub tanh(x: float) -> float {
    r = m_tanh(x);
    if _domain_error(x, r, False) {
        raise ValueError("math domain error");
    }
    return r;
}

def _float_to_int(r: float) -> int {
    if isnan(r) {
        raise ValueError("cannot convert float NaN to integer");
    }
    if isinf(r) {
        raise OverflowError("cannot convert float infinity to integer");
    }
    if r >= 9223372036854775808.0 or r < -9223372036854775808.0 {
        raise OverflowError("cannot convert float to integer");
    }
    return int(r);
}


def:pub ceil[T](x: T) -> int {
    if isinstance(x, int) {
        xi: int = x;
        return xi;
    }
    return _float_to_int(m_ceil(float(x)));
}


def:pub floor[T](x: T) -> int {
    if isinstance(x, int) {
        xi: int = x;
        return xi;
    }
    return _float_to_int(m_floor(float(x)));
}


def:pub trunc[T](x: T) -> int {
    if isinstance(x, int) {
        xi: int = x;
        return xi;
    }
    return _float_to_int(m_trunc(float(x)));
}

def _binary_domain_error(x: float, y: float, r: float) -> bool {
    return isnan(r) and not isnan(x) and not isnan(y);
}


def _binary_range_error(x: float, y: float, r: float) -> bool {
    return isinf(r) and isfinite(x) and isfinite(y);
}


def:pub atan2(y: float, x: float) -> float {
    r = m_atan2(y, x);
    if _binary_domain_error(y, x, r) {
        raise ValueError("math domain error");
    }
    if _binary_range_error(y, x, r) {
        raise OverflowError("math range error");
    }
    return r;
}


def:pub copysign(x: float, y: float) -> float {
    return m_copysign(x, y);
}


def:pub fmod(x: float, y: float) -> float {
    r = m_fmod(x, y);
    if _binary_domain_error(x, y, r) {
        raise ValueError("math domain error");
    }
    if _binary_range_error(x, y, r) {
        raise OverflowError("math range error");
    }
    return r;
}


def:pub remainder(x: float, y: float) -> float {
    r = m_remainder(x, y);
    if _binary_domain_error(x, y, r) {
        raise ValueError("math domain error");
    }
    if _binary_range_error(x, y, r) {
        raise OverflowError("math range error");
    }
    return r;
}


def:pub pow(x: float, y: float) -> float {
    r = m_pow(x, y);
    if _binary_domain_error(x, y, r) {
        raise ValueError("math domain error");
    }
    if _binary_range_error(x, y, r) {
        if x == 0.0 {
            raise ValueError("math domain error");
        }
        raise OverflowError("math range error");
    }
    return r;
}


def:pub fma(x: float, y: float, z: float) -> float {
    r = m_fma(x, y, z);
    if isnan(r) and not isnan(x) and not isnan(y) and not isnan(z) {
        raise ValueError("invalid operation in fma");
    }
    if isinf(r) and isfinite(x) and isfinite(y) and isfinite(z) {
        raise OverflowError("overflow in fma");
    }
    return r;
}

def:pub degrees(x: float) -> float {
    return x * 57.2957795130823208768;
}


def:pub radians(x: float) -> float {
    return x * 0.0174532925199432957692;
}


def:pub log(x: float, base: float | None = None) -> float {
    if x <= 0.0 {
        raise ValueError(_got("expected a positive input, got ", x));
    }
    num = m_log(x);
    if base is None {
        return num;
    }
    if base <= 0.0 {
        raise ValueError(_got("expected a positive input, got ", base));
    }
    den = m_log(base);
    if den == 0.0 {
        raise ZeroDivisionError("division by zero");
    }
    return num / den;
}


def:pub log2(x: float) -> float {
    if x <= 0.0 {
        raise ValueError(_got("expected a positive input, got ", x));
    }
    return m_log2(x);
}


def:pub log10(x: float) -> float {
    if x <= 0.0 {
        raise ValueError(_got("expected a positive input, got ", x));
    }
    return m_log10(x);
}

def:pub factorial(n: int) -> int {
    if n < 0 {
        raise ValueError("factorial() not defined for negative values");
    }
    if n > 20 {
        raise OverflowError("factorial() result too large");
    }
    r: int = 1;
    for i in range(2, n + 1) {
        r *= i;
    }
    return r;
}


def:pub isqrt(n: int) -> int {
    if n < 0 {
        raise ValueError("isqrt() argument must be nonnegative");
    }
    r = int(m_sqrt(float(n)));
    if r > 3037000499 {
        r = 3037000499;
    }
    while r * r > n {
        r -= 1;
    }
    while r < 3037000499 and (r + 1) * (r + 1) <= n {
        r += 1;
    }
    return r;
}


def _gcd(a: int, b: int) -> int {
    x: int = a;
    if x < 0 {
        x = -x;
    }
    y: int = b;
    if y < 0 {
        y = -y;
    }
    while y != 0 {
        t = y;
        y = x % y;
        x = t;
    }
    return x;
}


def:pub gcd(*integers: int) -> int {
    r: int = 0;
    for v in integers {
        r = _gcd(r, v);
    }
    return r;
}


def:pub lcm(*integers: int) -> int {
    r: int = 1;
    for v in integers {
        a = v if v >= 0 else -v;
        if r == 0 or a == 0 {
            r = 0;
            continue;
        }
        q = r // _gcd(r, a);
        if a > 9223372036854775807 // q {
            raise OverflowError("lcm() result too large");
        }
        r = q * a;
    }
    return r;
}


def:pub comb(n: int, k: int) -> int {
    if n < 0 {
        raise ValueError("n must be a non-negative integer");
    }
    if k < 0 {
        raise ValueError("k must be a non-negative integer");
    }
    if k > n {
        return 0;
    }
    kk = k;
    if n - k < kk {
        kk = n - k;
    }
    r: int = 1;
    for i in range(kk) {
        g = _gcd(r, i + 1);
        rp = r // g;
        c = (i + 1) // g;
        m = (n - i) // c;
        if m != 0 and rp > 9223372036854775807 // m {
            raise OverflowError("comb() result too large");
        }
        r = rp * m;
    }
    return r;
}


def:pub perm(n: int, k: int | None = None) -> int {
    if n < 0 {
        raise ValueError("n must be a non-negative integer");
    }
    if k is None {
        return factorial(n);
    }
    if k < 0 {
        raise ValueError("k must be a non-negative integer");
    }
    if k > n {
        return 0;
    }
    r: int = 1;
    for i in range(k) {
        f = n - i;
        if r > 9223372036854775807 // f {
            raise OverflowError("perm() result too large");
        }
        r *= f;
    }
    return r;
}

def:pub frexp(x: float) -> tuple[(float, int)] {
    if x == 0.0 or not isfinite(x) {
        return (x, 0);
    }
    b = __float_bits(x);
    mag = b & 9223372036854775807;
    expo = mag >> 52;
    if expo == 0 {
        (f2, e2) = frexp(x * 18446744073709551616.0);
        return (f2, e2 - 64);
    }
    mant = mag & 4503599627370495;
    nb = (b & (1 << 63)) | 4602678819172646912 | mant;
    return (__bits_float(nb), expo - 1022);
}


def:pub modf(x: float) -> tuple[(float, float)] {
    if isnan(x) {
        return (x, x);
    }
    if isinf(x) {
        return (m_copysign(0.0, x), x);
    }
    ip = m_trunc(x);
    fp = x - ip;
    if fp == 0.0 {
        fp = m_copysign(0.0, x);
    }
    return (fp, ip);
}


def:pub ldexp(x: float, i: int) -> float {
    if x == 0.0 or not isfinite(x) {
        return x;
    }

    if i > 2098 {
        raise OverflowError("math range error");
    }
    if i < -2098 {
        return m_copysign(0.0, x);
    }
    (mf, expo) = frexp(x);
    n = expo + i;
    b = __float_bits(mf);
    sgn = b & (1 << 63);
    mant = b & 4503599627370495;
    if n > 1024 {
        raise OverflowError("math range error");
    }
    if n >= -1021 {
        return __bits_float(sgn | ((n + 1022) << 52) | mant);
    }

    f = mant | 4503599627370496;
    s = -n - 1021;
    if s >= 54 {
        return __bits_float(sgn);
    }
    mant2 = f >> s;
    rem = f - (mant2 << s);
    half = 1 << (s - 1);
    if rem > half or (rem == half and (mant2 & 1) == 1) {
        mant2 += 1;
    }
    return __bits_float(sgn | mant2);
}


def:pub nextafter(x: float, y: float, *, steps: int = 1) -> float {
    if steps < 0 {
        raise ValueError("steps must be a non-negative integer");
    }
    count = steps;
    if count == 0 {
        return x;
    }
    if x == y {
        return y;
    }
    if isnan(x) {
        return x;
    }
    if isnan(y) {
        return y;
    }
    sgn_mask = 1 << 63;
    mag_mask = 9223372036854775807;
    first = __float_bits(x);
    last = __float_bits(y);
    fm = first & mag_mask;
    lm = last & mag_mask;
    fs = first & sgn_mask;
    ls = last & sgn_mask;
    if fs != ls {
        if count <= fm {
            return __bits_float(fs | (fm - count));
        }
        rem = count - fm;
        if rem >= lm {
            return y;
        }
        return __bits_float(ls | rem);
    }
    delta = fm - lm if fm > lm else lm - fm;
    if count >= delta {
        return y;
    }
    rb = first - count if fm > lm else first + count;
    return __bits_float(rb);
}


def:pub ulp(x: float) -> float {
    if isnan(x) {
        return x;
    }
    x = m_fabs(x);
    if isinf(x) {
        return x;
    }
    following = nextafter(x, inf);
    if isinf(following) {
        return x - nextafter(x, -inf);
    }
    return following - x;
}

def:pub fsum[C: Iterable](data: C) -> float {
    partials: list[float] = [];
    special: float = 0.0;
    infinities: float = 0.0;
    low: float = 0.0;
    for item in data {
        x = float(item);
        original = x;
        count = 0;
        for j in range(len(partials)) {
            y = partials[j];
            if m_fabs(x) < m_fabs(y) {
                tmp = x;
                x = y;
                y = tmp;
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
                    raise OverflowError("intermediate overflow in fsum");
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
    if special != 0.0 {
        if isnan(infinities) {
            raise ValueError("-inf + inf in fsum");
        }
        return special;
    }
    high: float = 0.0;
    if len(partials) > 0 {
        high = partials.pop();
        while len(partials) > 0 {
            x = high;
            y = partials.pop();
            high = x + y;
            rounded = high - x;
            low = y - rounded;
            if low != 0.0 {
                break;
            }
        }
        if len(partials) > 0
            and (
                (low < 0.0 and partials[-1] < 0.0) or (low > 0.0 and partials[-1] > 0.0)
            ) {
            y = low * 2.0;
            x = high + y;
            rounded = x - high;
            if y == rounded {
                high = x;
            }
        }
    }
    return high;
}

def _frexp_exponent(x: float) -> int {
    field = (__float_bits(x) >> 52) & 2047;
    if field == 0 {
        return _frexp_exponent(x * 18446744073709551616.0) - 64;
    }
    return field - 1022;
}


def _power_of_two(k: int) -> float {
    if k >= -1022 {
        return __bits_float((k + 1023) << 52);
    }
    return __bits_float(1 << (k + 1074));
}


def _vector_norm(vec: list[float], largest: float, found_nan: bool) -> float {
    if isinf(largest) {
        return largest;
    }
    if found_nan {
        return nan;
    }
    if largest == 0.0 or len(vec) <= 1 {
        return largest;
    }
    pre: float = 1.0;
    post: float = 1.0;
    top = largest;
    max_e = _frexp_exponent(top);
    if max_e < -1023 {
        pre = 4.49423283715579e307;
        post = 2.2250738585072014e-308;
        top = top * pre;
        max_e = _frexp_exponent(top);
    }
    scale = _power_of_two(-max_e);
    csum: float = 1.0;
    frac1: float = 0.0;
    frac2: float = 0.0;
    for value in vec {
        x = (m_fabs(value) * pre) * scale;
        hi = x * x;
        lo = m_fma(x, x, -hi);
        s = csum + hi;
        frac2 += (csum - s) + hi;
        csum = s;
        frac1 += lo;
    }
    h = m_sqrt(csum - 1.0 + (frac1 + frac2));
    hi = -h * h;
    lo = m_fma(-h, h, -hi);
    s = csum + hi;
    frac2 += (csum - s) + hi;
    csum = s;
    frac1 += lo;
    h += (csum - 1.0 + (frac1 + frac2)) / (2.0 * h);
    return post * (h / scale);
}


def:pub hypot(*coordinates: float) -> float {
    largest: float = 0.0;
    found_nan = False;
    for v in coordinates {
        x = m_fabs(v);
        found_nan = found_nan or isnan(x);
        if x > largest {
            largest = x;
        }
    }
    return _vector_norm(coordinates, largest, found_nan);
}


def:pub dist[P: Iterable, Q: Iterable](p: P, q: Q) -> float {
    diffs: list[float] = [];
    for v in p {
        diffs.append(float(v));
    }
    n = 0;
    largest: float = 0.0;
    found_nan = False;
    for w in q {
        if n >= len(diffs) {
            raise ValueError("both points must have the same number of dimensions");
        }
        d = m_fabs(diffs[n] - float(w));
        diffs[n] = d;
        found_nan = found_nan or isnan(d);
        if d > largest {
            largest = d;
        }
        n += 1;
    }
    if n != len(diffs) {
        raise ValueError("both points must have the same number of dimensions");
    }
    return _vector_norm(diffs, largest, found_nan);
}


def _imul_fits(a: int, b: int) -> bool {
    hi = 9223372036854775807;
    lo = -9223372036854775807 - 1;
    if a == 0 or b == 0 or a == 1 or b == 1 {
        return True;
    }
    if a == lo or b == lo {
        return False;
    }
    aa = a if a > 0 else -a;
    bb = b if b > 0 else -b;
    lim = hi // bb;

    if (a < 0) != (b < 0) and hi % bb == bb - 1 {
        lim += 1;
    }
    return aa <= lim;
}


def _iadd_fits(a: int, b: int) -> bool {
    hi = 9223372036854775807;
    lo = -9223372036854775807 - 1;
    return (b <= 0 or a <= hi - b) and (b >= 0 or a >= lo - b);
}


def:pub prod[C: Iterable](data: C, *, start: int | float = 1) -> (int | float) {
    ri: int = 1;
    rf: float = 1.0;
    isint = True;
    s = start;
    if isinstance(s, int) {
        si: int = s;
        ri = si;
    } else {
        rf = float(s);
        isint = False;
    }
    for v in data {
        if isint {
            if isinstance(v, int) {
                iv: int = v;
                if _imul_fits(ri, iv) {
                    ri *= iv;
                } else {
                    raise OverflowError("prod() result too large");
                }
            } else {
                rf = float(ri) * float(v);
                isint = False;
            }
        } else {
            rf *= float(v);
        }
    }
    if isint {
        return ri;
    }
    return rf;
}


def _tl_to_double(hi: float, lo: float, tiny: float) -> float {
    last_hi = lo + hi;
    z = last_hi - lo;
    last_lo = (lo - (last_hi - z)) + (hi - z);
    return tiny + last_lo + last_hi;
}


def:pub sumprod[P: Iterable, Q: Iterable](p: P, q: Q) -> (int | float) {
    p_flts: list[float] = [];
    p_ints: list[int] = [];
    p_int = True;
    for v in p {
        if isinstance(v, int) {
            vi: int = v;
            p_ints.append(vi);
        } else {
            p_int = False;
        }
        p_flts.append(float(v));
    }
    q_flts: list[float] = [];
    q_ints: list[int] = [];
    q_int = True;
    for w in q {
        if isinstance(w, int) {
            wi: int = w;
            q_ints.append(wi);
        } else {
            q_int = False;
        }
        q_flts.append(float(w));
    }
    if len(p_flts) != len(q_flts) {
        raise ValueError("Inputs are not the same length");
    }
    if p_int and q_int {
        total: int = 0;
        for i in range(len(p_ints)) {
            a = p_ints[i];
            b = q_ints[i];
            if not _imul_fits(a, b) {
                raise OverflowError("sumprod() result too large");
            }
            t = a * b;
            if not _iadd_fits(total, t) {
                raise OverflowError("sumprod() result too large");
            }
            total += t;
        }
        return total;
    }
    hi: float = 0.0;
    lo: float = 0.0;
    tiny: float = 0.0;
    in_use = False;
    general = False;
    acc: float = 0.0;
    for i in range(len(p_flts)) {
        x = p_flts[i];
        y = q_flts[i];
        if not general {
            ph = x * y;
            pl = m_fma(x, y, -ph);
            s_hi = hi + ph;
            s_z = s_hi - hi;
            s_lo = (hi - (s_hi - s_z)) + (ph - s_z);
            r1_hi = lo + pl;
            r1_z = r1_hi - lo;
            r1_lo = (lo - (r1_hi - r1_z)) + (pl - r1_z);
            r2_hi = r1_hi + s_lo;
            r2_z = r2_hi - r1_hi;
            r2_lo = (r1_hi - (r2_hi - r2_z)) + (s_lo - r2_z);
            if isfinite(s_hi) {
                hi = s_hi;
                lo = r2_hi;
                tiny = tiny + r1_lo + r2_lo;
                in_use = True;
                continue;
            }
            general = True;
            if in_use {
                acc = _tl_to_double(hi, lo, tiny);
            }
        }
        acc += x * y;
    }
    if general {
        return acc;
    }
    return _tl_to_double(hi, lo, tiny);
}


def:pub isclose(
    a: float, b: float, *, rel_tol: float = 1e-9, abs_tol: float = 0.0
) -> bool {
    if rel_tol < 0.0 or abs_tol < 0.0 {
        raise ValueError("tolerances must be non-negative");
    }
    if a == b {
        return True;
    }
    if isinf(a) or isinf(b) {
        return False;
    }
    diff = m_fabs(b - a);
    return diff <= abs_tol
        or diff <= m_fabs(rel_tol * a)
        or diff <= m_fabs(rel_tol * b);
}
