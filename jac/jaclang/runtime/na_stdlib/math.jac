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
