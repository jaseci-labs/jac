"""Platform floating-point primitives shared by native numeric modules."""
import from c {
    def acos(value: f64) -> f64;  def acosh(value: f64) -> f64;  def asin(
        value: f64
    ) -> f64;  def atan(value: f64) -> f64;  def atanh(value: f64) -> f64;  def cbrt(
        value: f64
    ) -> f64;  def erf(value: f64) -> f64;  def erfc(value: f64) -> f64;  def exp2(
        value: f64
    ) -> f64;  def expm1(value: f64) -> f64;  def tgamma(value: f64) -> f64;  def lgamma(
        value: f64
    ) -> f64;  def ceil(value: f64) -> f64;  def floor(value: f64) -> f64;  def log2(
        value: f64
    ) -> f64;  def log10(value: f64) -> f64;  def nextafter(x: f64, y: f64) -> f64;  def pow(
        x: f64, y: f64
    ) -> f64;  def fmod(x: f64, y: f64) -> f64;  def remainder(x: f64, y: f64) -> f64;  def fma(
        x: f64, y: f64, z: f64
    ) -> f64;  def fabs(value: f64) -> f64;  def sqrt(value: f64) -> f64;  def log(
        value: f64
    ) -> f64;  def log1p(value: f64) -> f64;  def exp(value: f64) -> f64;  def sin(
        value: f64
    ) -> f64;  def cos(value: f64) -> f64;  def tan(value: f64) -> f64;  def sinh(
        value: f64
    ) -> f64;  def cosh(value: f64) -> f64;  def tanh(value: f64) -> f64;  def asinh(
        value: f64
    ) -> f64;  def atan2(y: f64, x: f64) -> f64;  def hypot(x: f64, y: f64) -> f64;  def copysign(
        x: f64, y: f64
    ) -> f64;  def ldexp(value: f64, exponent: i32) -> f64;
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
