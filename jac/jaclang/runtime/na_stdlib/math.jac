glob:pub pi: float = 3.141592653589793,
     e: float = 2.718281828459045,
     tau: float = 6.283185307179586,
     inf: float = float("inf"),
     nan: float = float("nan");

def:pub isnan(x: float) -> bool;


def:pub isinf(x: float) -> bool;


def:pub isfinite(x: float) -> bool;

def _domain_error(x: float, r: float, can_overflow: bool) -> bool;


def _range_error(x: float, r: float) -> bool;


def _got(prefix: str, x: float) -> str;

def:pub acos(x: float) -> float;


def:pub acosh(x: float) -> float;


def:pub asin(x: float) -> float;


def:pub asinh(x: float) -> float;


def:pub atan(x: float) -> float;


def:pub atanh(x: float) -> float;


def:pub cbrt(x: float) -> float;


def:pub cos(x: float) -> float;


def:pub cosh(x: float) -> float;


def:pub erf(x: float) -> float;


def:pub erfc(x: float) -> float;


def:pub exp(x: float) -> float;


def:pub exp2(x: float) -> float;


def:pub expm1(x: float) -> float;


def:pub fabs(x: float) -> float;


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

def _sinpi(x: float) -> float;


def _lanczos_sum(x: float) -> float;


def _gamma_domain(x: float) -> str;


def:pub gamma(x: float) -> float;


def:pub lgamma(x: float) -> float;


def:pub log1p(x: float) -> float;


def:pub sin(x: float) -> float;


def:pub sinh(x: float) -> float;


def:pub sqrt(x: float) -> float;


def:pub tan(x: float) -> float;


def:pub tanh(x: float) -> float;

def _float_to_int(r: float) -> int;


def:pub ceil[T](x: T) -> int;


def:pub floor[T](x: T) -> int;


def:pub trunc[T](x: T) -> int;

def _binary_domain_error(x: float, y: float, r: float) -> bool;


def _binary_range_error(x: float, y: float, r: float) -> bool;


def:pub atan2(y: float, x: float) -> float;


def:pub copysign(x: float, y: float) -> float;


def:pub fmod(x: float, y: float) -> float;


def:pub remainder(x: float, y: float) -> float;


def:pub pow(x: float, y: float) -> float;


def:pub fma(x: float, y: float, z: float) -> float;

def:pub degrees(x: float) -> float;


def:pub radians(x: float) -> float;


def:pub log(x: float, base: float | None = None) -> float;


def:pub log2(x: float) -> float;


def:pub log10(x: float) -> float;

def:pub factorial(n: int) -> int;


def:pub isqrt(n: int) -> int;


def _gcd(a: int, b: int) -> int;


def:pub gcd(*integers: int) -> int;


def:pub lcm(*integers: int) -> int;


def:pub comb(n: int, k: int) -> int;


def:pub perm(n: int, k: int | None = None) -> int;

def:pub frexp(x: float) -> tuple[(float, int)];


def:pub modf(x: float) -> tuple[(float, float)];


def:pub ldexp(x: float, i: int) -> float;


def:pub nextafter(x: float, y: float, *, steps: int = 1) -> float;


def:pub ulp(x: float) -> float;

def:pub fsum[C: Iterable](data: C) -> float;

def _frexp_exponent(x: float) -> int;


def _power_of_two(k: int) -> float;


def _vector_norm(vec: list[float], largest: float, found_nan: bool) -> float;


def:pub hypot(*coordinates: float) -> float;


def:pub dist[P: Iterable, Q: Iterable](p: P, q: Q) -> float;


def _imul_fits(a: int, b: int) -> bool;


def _iadd_fits(a: int, b: int) -> bool;


def:pub prod[C: Iterable](data: C, *, start: int | float = 1) -> (int | float);


def _tl_to_double(hi: float, lo: float, tiny: float) -> float;


def:pub sumprod[P: Iterable, Q: Iterable](p: P, q: Q) -> (int | float);


def:pub isclose(
    a: float, b: float, *, rel_tol: float = 1e-9, abs_tol: float = 0.0
) -> bool;

impl ceil[T](x: T) -> int {
    if isinstance(x, int) {
        xi: int = x;
        return xi;
    }
    return _float_to_int(m_ceil(float(x)));
}


impl floor[T](x: T) -> int {
    if isinstance(x, int) {
        xi: int = x;
        return xi;
    }
    return _float_to_int(m_floor(float(x)));
}


impl trunc[T](x: T) -> int {
    if isinstance(x, int) {
        xi: int = x;
        return xi;
    }
    return _float_to_int(m_trunc(float(x)));
}


impl fsum[C: Iterable](data: C) -> float {
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


impl dist[P: Iterable, Q: Iterable](p: P, q: Q) -> float {
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


impl prod[C: Iterable](data: C, *, start: int | float = 1) -> (int | float) {
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


impl sumprod[P: Iterable, Q: Iterable](p: P, q: Q) -> (int | float) {
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
