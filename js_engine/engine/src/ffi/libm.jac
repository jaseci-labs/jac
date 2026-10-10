"""C libm + libc math FFI bindings for the Jac-native runtime.

Exposes the subset of libm needed to implement the full ES2023 Math object:
  - Rounding   : ceil, floor, round, trunc, fabs
  - Roots      : sqrt, cbrt, hypot (2-arg)
  - Exp/Log    : exp, expm1, pow, log, log2, log10, log1p
  - Trig       : sin, cos, tan, asin, acos, atan, atan2
  - Hyperbolic : sinh, cosh, tanh, asinh, acosh, atanh
  - Extrema    : fmax, fmin
  - Random     : drand48, srand48 (seeded with time(0) at import time)

Bun reference:
  bun/src/bun.js/bindings/JSMathObject.cpp  — Math.* dispatch table
  bun/src/bun.js/bindings/JSGlobalObject.cpp — Math object bootstrap
"""

# ── libm bindings ─────────────────────────────────────────────────────────────

import from "libm.so.6" {
    # Rounding
    def fabs(x: float) -> float;  def ceil(x: float) -> float;  def floor(
        x: float
    ) -> float;  def round(x: float) -> float;  def trunc(x: float) -> float;
    # Roots & power
    def sqrt(x: float) -> float;  def cbrt(x: float) -> float;  def pow(
        x: float, y: float
    ) -> float;
    # Exponential & logarithm
    def exp(x: float) -> float;  def expm1(x: float) -> float;  def log(
        x: float
    ) -> float;  def log2(x: float) -> float;  def log10(x: float) -> float;  def log1p(
        x: float
    ) -> float;
    # Trigonometric
    def sin(x: float) -> float;  def cos(x: float) -> float;  def tan(
        x: float
    ) -> float;  def asin(x: float) -> float;  def acos(x: float) -> float;  def atan(
        x: float
    ) -> float;  def atan2(y: float, x: float) -> float;
    # Hyperbolic
    def sinh(x: float) -> float;  def cosh(x: float) -> float;  def tanh(
        x: float
    ) -> float;  def asinh(x: float) -> float;  def acosh(x: float) -> float;  def atanh(
        x: float
    ) -> float;
    # 2-arg hypotenuse & extrema
    def hypot(x: float, y: float) -> float;  def fmax(x: float, y: float) -> float;  def fmin(
        x: float, y: float
    ) -> float;
    # Remainder (the ES Number::remainder: sign of the dividend, exact)
    def fmod(x: float, y: float) -> float;
}

# ── libc PRNG (for Math.random) ───────────────────────────────────────────────

import from engine.src.ffi.libc { time, srand48, drand48 }
