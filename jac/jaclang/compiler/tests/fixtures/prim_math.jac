"""math module cross-backend equivalence fixture (issue #6404, v1).

Exercises every math endpoint the native backend lowers (Mechanism A → libm).
sv (Python) and na (LLVM) must agree within ULP tolerance. The ES/JS backend
opts out (returns {}) — this roadmap targets sv↔na congruence.
"""

import math;

def math_py() -> dict {
    return {
        # constants
        "pi": math.pi, "e": math.e, "tau": math.tau,
        # roots / powers
        "sqrt": math.sqrt(16.0), "cbrt": math.cbrt(27.0),
        "pow": math.pow(2.0, 10.0),
        # trig
        "sin": math.sin(1.0), "cos": math.cos(1.0), "tan": math.tan(1.0),
        "asin": math.asin(0.5), "acos": math.acos(0.5), "atan": math.atan(2.0),
        "atan2": math.atan2(1.0, 2.0), "hypot": math.hypot(3.0, 4.0),
        # hyperbolic
        "sinh": math.sinh(1.0), "cosh": math.cosh(1.0), "tanh": math.tanh(1.0),
        "asinh": math.asinh(1.0), "acosh": math.acosh(2.0), "atanh": math.atanh(0.5),
        # exp / log
        "exp": math.exp(2.0), "expm1": math.expm1(0.5),
        "log": math.log(math.e), "log2": math.log2(8.0), "log10": math.log10(1000.0),
        "log1p": math.log1p(0.5), "logb": math.log(81.0, 3.0),
        # rounding (-> int)
        "floor": math.floor(2.7), "ceil": math.ceil(2.1), "trunc": math.trunc(-2.7),
        # misc real
        "fabs": math.fabs(-3.5), "fmod": math.fmod(7.0, 3.0),
        "copysign": math.copysign(3.0, -1.0), "remainder": math.remainder(7.0, 3.0),
        "degrees": math.degrees(math.pi), "radians": math.radians(180.0),
        # special
        "gamma": math.gamma(5.0), "lgamma": math.lgamma(5.0),
        "erf": math.erf(1.0), "erfc": math.erfc(1.0),
        # predicates
        "isnan_nan": math.isnan(math.nan), "isnan_one": math.isnan(1.0),
        "isinf_inf": math.isinf(math.inf), "isinf_one": math.isinf(1.0),
        "isfin_one": math.isfinite(1.0), "isfin_inf": math.isfinite(math.inf),
    };
}

cl def math_cl() -> dict {
    return {};
}

na {
    def math_na() -> dict[str, any] {
        floor_v: int = math.floor(2.7);
        ceil_v: int = math.ceil(2.1);
        trunc_v: int = math.trunc(-2.7);
        isnan_nan: int = math.isnan(math.nan);
        isnan_one: int = math.isnan(1.0);
        isinf_inf: int = math.isinf(math.inf);
        isinf_one: int = math.isinf(1.0);
        isfin_one: int = math.isfinite(1.0);
        isfin_inf: int = math.isfinite(math.inf);
        return {
            "pi": math.pi, "e": math.e, "tau": math.tau,
            "sqrt": math.sqrt(16.0), "cbrt": math.cbrt(27.0),
            "pow": math.pow(2.0, 10.0),
            "sin": math.sin(1.0), "cos": math.cos(1.0), "tan": math.tan(1.0),
            "asin": math.asin(0.5), "acos": math.acos(0.5), "atan": math.atan(2.0),
            "atan2": math.atan2(1.0, 2.0), "hypot": math.hypot(3.0, 4.0),
            "sinh": math.sinh(1.0), "cosh": math.cosh(1.0), "tanh": math.tanh(1.0),
            "asinh": math.asinh(1.0), "acosh": math.acosh(2.0), "atanh": math.atanh(0.5),
            "exp": math.exp(2.0), "expm1": math.expm1(0.5),
            "log": math.log(math.e), "log2": math.log2(8.0), "log10": math.log10(1000.0),
            "log1p": math.log1p(0.5), "logb": math.log(81.0, 3.0),
            "floor": floor_v, "ceil": ceil_v, "trunc": trunc_v,
            "fabs": math.fabs(-3.5), "fmod": math.fmod(7.0, 3.0),
            "copysign": math.copysign(3.0, -1.0), "remainder": math.remainder(7.0, 3.0),
            "degrees": math.degrees(math.pi), "radians": math.radians(180.0),
            "gamma": math.gamma(5.0), "lgamma": math.lgamma(5.0),
            "erf": math.erf(1.0), "erfc": math.erfc(1.0),
            "isnan_nan": isnan_nan, "isnan_one": isnan_one,
            "isinf_inf": isinf_inf, "isinf_one": isinf_one,
            "isfin_one": isfin_one, "isfin_inf": isfin_inf,
        };
    }
}
