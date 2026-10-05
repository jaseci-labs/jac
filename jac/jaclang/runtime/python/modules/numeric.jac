"""Platform floating-point primitives shared by native numeric modules.

Zig's compiler-rt also defines log, log2, log10, exp, exp2, sin, cos, tan and
fma. Those reach the platform libm through the jacpy_libm_* helpers in
bootstrap/python/object_api.c, which says why; the rest are plain C calls.
"""
import from c {
    def acos(value: f64) -> f64;  def acosh(value: f64) -> f64;  def asin(
        value: f64
    ) -> f64;  def atan(value: f64) -> f64;  def atanh(value: f64) -> f64;  def cbrt(
        value: f64
    ) -> f64;  def erf(value: f64) -> f64;  def erfc(value: f64) -> f64;  def expm1(
        value: f64
    ) -> f64;  def ceil(value: f64) -> f64;  def floor(value: f64) -> f64;  def round(
        value: f64
    ) -> f64;  def nextafter(x: f64, y: f64) -> f64;  def pow(x: f64, y: f64) -> f64;  def fmod(
        x: f64, y: f64
    ) -> f64;  def remainder(x: f64, y: f64) -> f64;  def fabs(value: f64) -> f64;  def sqrt(
        value: f64
    ) -> f64;  def log1p(value: f64) -> f64;  def sinh(value: f64) -> f64;  def cosh(
        value: f64
    ) -> f64;  def tanh(value: f64) -> f64;  def asinh(value: f64) -> f64;  def atan2(
        y: f64, x: f64
    ) -> f64;  def hypot(x: f64, y: f64) -> f64;  def copysign(x: f64, y: f64) -> f64;  def ldexp(
        value: f64, exponent: i32
    ) -> f64;
}
import from jaclang.runtime.python.cpython_api {
    jacpy_libm_cos,
    jacpy_libm_exp,
    jacpy_libm_exp2,
    jacpy_libm_fma,
    jacpy_libm_log,
    jacpy_libm_log10,
    jacpy_libm_log2,
    jacpy_libm_sin,
    jacpy_libm_tan
}

glob infinity: float = float("inf"),
     nan: float = float("nan");

def isfinite(value: float) -> bool {
    return value <= 1.7976931348623157e308 and value >= -1.7976931348623157e308;
}

def isinf(value: float) -> bool {
    return value == infinity or value == -infinity;
}

def isnan(value: float) -> bool {
    return value != value;
}

def scaled(value: float, exponent: int) -> float {
    return ldexp(value, i32(exponent));
}

def log(value: float) -> float {
    return jacpy_libm_log(value);
}

def log2(value: float) -> float {
    return jacpy_libm_log2(value);
}

def log10(value: float) -> float {
    return jacpy_libm_log10(value);
}

def exp(value: float) -> float {
    return jacpy_libm_exp(value);
}

def exp2(value: float) -> float {
    return jacpy_libm_exp2(value);
}

def sin(value: float) -> float {
    return jacpy_libm_sin(value);
}

def cos(value: float) -> float {
    return jacpy_libm_cos(value);
}

def tan(value: float) -> float {
    return jacpy_libm_tan(value);
}

def fma(x: float, y: float, z: float) -> float {
    return jacpy_libm_fma(x, y, z);
}
