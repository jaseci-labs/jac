"""Native complex transcendental algorithms and IEEE special-value rules.

Recovered algorithms are checked against pinned CPython 3.14.6, with real
transcendentals supplied by libm. See ../LICENSE.cpython.
"""
import from jaclang.runtime.python.modules.numeric {
    asinh,
    atan2,
    copysign,
    cos,
    cosh,
    exp,
    fabs,
    hypot,
    isfinite,
    isinf,
    isnan,
    log,
    log1p,
    scaled,
    sin,
    sinh,
    sqrt,
    tan,
    tanh
}
import from jaclang.runtime.python.capi {
    boundary_failure,
    required,
    checked,
    object_error,
    object_tuple,
    jacpy_complex_value,
    jacpy_complex_real,
    jacpy_complex_imag,
    jacpy_complex,
    jacpy_number_as_double,
    jacpy_float,
    jacpy_boolean,
    jacpy_error_pending,
    jacpy_release,
    jacpy_truediv,
    jacpy_error_is,
    jacpy_clear_errno,
    jacpy_math_errno
}

obj complex_parts {
    has real: float,
        imag: float;
}

glob e: float = 2.718281828459045,
     _DBL_MAX: float = 1.7976931348623157e308,
     _DBL_MIN: float = 2.2250738585072014e-308,
     _DBL_MANT_DIG: int = 53,
     _CM_LARGE_DOUBLE: float = _DBL_MAX / 4.0,
     _CM_SQRT_LARGE_DOUBLE: float = 6.703904478183408e153,
     _CM_LOG_LARGE_DOUBLE: float = 708.3964185322641,
     _CM_SQRT_DBL_MIN: float = 1.4916681462400413e-154,
     _CM_SCALE_UP: int = 2 * (_DBL_MANT_DIG // 2) + 1,
     _CM_SCALE_DOWN: int = -((_CM_SCALE_UP + 1) // 2),
     _M_LN2: float = 0.6931471805599453094,
     _M_LN10: float = 2.302585092994045684,
     _EDOM: int = 1,
     _ERANGE: int = 2;

# ---------------- C limits (float.h / pycore_pymath.h) ----------------

# FLT_RADIX==2: CM_SCALE_UP = 2*(DBL_MANT_DIG/2)+1, CM_SCALE_DOWN = -(UP+1)/2

# errno codes lifted to ints: EDOM=1, ERANGE=2, none=0
# ---------------- special-value machinery ----------------

# special_type(d): ST_NINF, ST_NEG, ST_NZERO, ST_PZERO, ST_POS, ST_PINF,
# ST_NAN -- indexed 0..6, matching the C enum order.
def:priv _special_type(d: float) -> int {
    if isfinite(d) {
        if d != 0.0 {
            return 4 if copysign(1.0, d) == 1.0 else 1;
        }
        return 3 if copysign(1.0, d) == 1.0 else 2;
    }
    if isnan(d) {
        return 6;
    }
    return 5 if copysign(1.0, d) == 1.0 else 0;
}

# Finite-only cells are unreachable; special tables are consulted only
# when at least one component is non-finite.
def:priv _sv_entry(
    table: list[list[tuple[float, float]]], z: complex_parts
) -> tuple[float, float] {
    cell: tuple[float, float] = table[_special_type(z.real)][_special_type(z.imag)];
    return cell;
}

glob _INF: float = float("inf"),
     _NAN: float = float("nan"),
     _PI: float = 3.141592653589793,
     _P14: float = 0.25 * _PI,
     _P12: float = 0.5 * _PI,
     _P34: float = 0.75 * _PI,
     _ACOS_SV: list[list[tuple[float, float]]] = [
         [
             (_P34, _INF),
             (_PI, _INF),
             (_PI, _INF),
             (_PI, -_INF),
             (_PI, -_INF),
             (_P34, -_INF),
             (_NAN, _INF)
         ],
         [
             (_P12, _INF),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (_P12, -_INF),
             (_NAN, _NAN)
         ],
         [
             (_P12, _INF),
             (0.0, 0.0),
             (_P12, 0.0),
             (_P12, -0.0),
             (0.0, 0.0),
             (_P12, -_INF),
             (_P12, _NAN)
         ],
         [
             (_P12, _INF),
             (0.0, 0.0),
             (_P12, 0.0),
             (_P12, -0.0),
             (0.0, 0.0),
             (_P12, -_INF),
             (_P12, _NAN)
         ],
         [
             (_P12, _INF),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (_P12, -_INF),
             (_NAN, _NAN)
         ],
         [
             (_P14, _INF),
             (0.0, _INF),
             (0.0, _INF),
             (0.0, -_INF),
             (0.0, -_INF),
             (_P14, -_INF),
             (_NAN, _INF)
         ],
         [
             (_NAN, _INF),
             (_NAN, _NAN),
             (_NAN, _NAN),
             (_NAN, _NAN),
             (_NAN, _NAN),
             (_NAN, -_INF),
             (_NAN, _NAN)
         ],

     ],
     _ACOSH_SV: list[list[tuple[float, float]]] = [
         [
             (_INF, -_P34),
             (_INF, -_PI),
             (_INF, -_PI),
             (_INF, _PI),
             (_INF, _PI),
             (_INF, _P34),
             (_INF, _NAN)
         ],
         [
             (_INF, -_P12),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (_INF, _P12),
             (_NAN, _NAN)
         ],
         [
             (_INF, -_P12),
             (0.0, 0.0),
             (0.0, -_P12),
             (0.0, _P12),
             (0.0, 0.0),
             (_INF, _P12),
             (_NAN, _P12)
         ],
         [
             (_INF, -_P12),
             (0.0, 0.0),
             (0.0, -_P12),
             (0.0, _P12),
             (0.0, 0.0),
             (_INF, _P12),
             (_NAN, _P12)
         ],
         [
             (_INF, -_P12),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (_INF, _P12),
             (_NAN, _NAN)
         ],
         [
             (_INF, -_P14),
             (_INF, -0.0),
             (_INF, -0.0),
             (_INF, 0.0),
             (_INF, 0.0),
             (_INF, _P14),
             (_INF, _NAN)
         ],
         [
             (_INF, _NAN),
             (_NAN, _NAN),
             (_NAN, _NAN),
             (_NAN, _NAN),
             (_NAN, _NAN),
             (_INF, _NAN),
             (_NAN, _NAN)
         ],

     ],
     _ASINH_SV: list[list[tuple[float, float]]] = [
         [
             (-_INF, -_P14),
             (-_INF, -0.0),
             (-_INF, -0.0),
             (-_INF, 0.0),
             (-_INF, 0.0),
             (-_INF, _P14),
             (-_INF, _NAN)
         ],
         [
             (-_INF, -_P12),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (-_INF, _P12),
             (_NAN, _NAN)
         ],
         [
             (-_INF, -_P12),
             (0.0, 0.0),
             (-0.0, -0.0),
             (-0.0, 0.0),
             (0.0, 0.0),
             (-_INF, _P12),
             (_NAN, _NAN)
         ],
         [
             (_INF, -_P12),
             (0.0, 0.0),
             (0.0, -0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (_INF, _P12),
             (_NAN, _NAN)
         ],
         [
             (_INF, -_P12),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (_INF, _P12),
             (_NAN, _NAN)
         ],
         [
             (_INF, -_P14),
             (_INF, -0.0),
             (_INF, -0.0),
             (_INF, 0.0),
             (_INF, 0.0),
             (_INF, _P14),
             (_INF, _NAN)
         ],
         [
             (_INF, _NAN),
             (_NAN, _NAN),
             (_NAN, -0.0),
             (_NAN, 0.0),
             (_NAN, _NAN),
             (_INF, _NAN),
             (_NAN, _NAN)
         ],

     ],
     _ATANH_SV: list[list[tuple[float, float]]] = [
         [
             (-0.0, -_P12),
             (-0.0, -_P12),
             (-0.0, -_P12),
             (-0.0, _P12),
             (-0.0, _P12),
             (-0.0, _P12),
             (-0.0, _NAN)
         ],
         [
             (-0.0, -_P12),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (-0.0, _P12),
             (_NAN, _NAN)
         ],
         [
             (-0.0, -_P12),
             (0.0, 0.0),
             (-0.0, -0.0),
             (-0.0, 0.0),
             (0.0, 0.0),
             (-0.0, _P12),
             (-0.0, _NAN)
         ],
         [
             (0.0, -_P12),
             (0.0, 0.0),
             (0.0, -0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, _P12),
             (0.0, _NAN)
         ],
         [
             (0.0, -_P12),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, _P12),
             (_NAN, _NAN)
         ],
         [
             (0.0, -_P12),
             (0.0, -_P12),
             (0.0, -_P12),
             (0.0, _P12),
             (0.0, _P12),
             (0.0, _P12),
             (0.0, _NAN)
         ],
         [
             (0.0, -_P12),
             (_NAN, _NAN),
             (_NAN, _NAN),
             (_NAN, _NAN),
             (_NAN, _NAN),
             (0.0, _P12),
             (_NAN, _NAN)
         ],

     ],
     _COSH_SV: list[list[tuple[float, float]]] = [
         [
             (_INF, _NAN),
             (0.0, 0.0),
             (_INF, 0.0),
             (_INF, -0.0),
             (0.0, 0.0),
             (_INF, _NAN),
             (_INF, _NAN)
         ],
         [
             (_NAN, _NAN),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (_NAN, _NAN),
             (_NAN, _NAN)
         ],
         [
             (_NAN, 0.0),
             (0.0, 0.0),
             (1.0, 0.0),
             (1.0, -0.0),
             (0.0, 0.0),
             (_NAN, 0.0),
             (_NAN, 0.0)
         ],
         [
             (_NAN, 0.0),
             (0.0, 0.0),
             (1.0, -0.0),
             (1.0, 0.0),
             (0.0, 0.0),
             (_NAN, 0.0),
             (_NAN, 0.0)
         ],
         [
             (_NAN, _NAN),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (_NAN, _NAN),
             (_NAN, _NAN)
         ],
         [
             (_INF, _NAN),
             (0.0, 0.0),
             (_INF, -0.0),
             (_INF, 0.0),
             (0.0, 0.0),
             (_INF, _NAN),
             (_INF, _NAN)
         ],
         [
             (_NAN, _NAN),
             (_NAN, _NAN),
             (_NAN, 0.0),
             (_NAN, 0.0),
             (_NAN, _NAN),
             (_NAN, _NAN),
             (_NAN, _NAN)
         ],

     ],
     _EXP_SV: list[list[tuple[float, float]]] = [
         [
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, -0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0)
         ],
         [
             (_NAN, _NAN),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (_NAN, _NAN),
             (_NAN, _NAN)
         ],
         [
             (_NAN, _NAN),
             (0.0, 0.0),
             (1.0, -0.0),
             (1.0, 0.0),
             (0.0, 0.0),
             (_NAN, _NAN),
             (_NAN, _NAN)
         ],
         [
             (_NAN, _NAN),
             (0.0, 0.0),
             (1.0, -0.0),
             (1.0, 0.0),
             (0.0, 0.0),
             (_NAN, _NAN),
             (_NAN, _NAN)
         ],
         [
             (_NAN, _NAN),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (_NAN, _NAN),
             (_NAN, _NAN)
         ],
         [
             (_INF, _NAN),
             (0.0, 0.0),
             (_INF, -0.0),
             (_INF, 0.0),
             (0.0, 0.0),
             (_INF, _NAN),
             (_INF, _NAN)
         ],
         [
             (_NAN, _NAN),
             (_NAN, _NAN),
             (_NAN, -0.0),
             (_NAN, 0.0),
             (_NAN, _NAN),
             (_NAN, _NAN),
             (_NAN, _NAN)
         ],

     ],
     _LOG_SV: list[list[tuple[float, float]]] = [
         [
             (_INF, -_P34),
             (_INF, -_PI),
             (_INF, -_PI),
             (_INF, _PI),
             (_INF, _PI),
             (_INF, _P34),
             (_INF, _NAN)
         ],
         [
             (_INF, -_P12),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (_INF, _P12),
             (_NAN, _NAN)
         ],
         [
             (_INF, -_P12),
             (0.0, 0.0),
             (-_INF, -_PI),
             (-_INF, _PI),
             (0.0, 0.0),
             (_INF, _P12),
             (_NAN, _NAN)
         ],
         [
             (_INF, -_P12),
             (0.0, 0.0),
             (-_INF, -0.0),
             (-_INF, 0.0),
             (0.0, 0.0),
             (_INF, _P12),
             (_NAN, _NAN)
         ],
         [
             (_INF, -_P12),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (_INF, _P12),
             (_NAN, _NAN)
         ],
         [
             (_INF, -_P14),
             (_INF, -0.0),
             (_INF, -0.0),
             (_INF, 0.0),
             (_INF, 0.0),
             (_INF, _P14),
             (_INF, _NAN)
         ],
         [
             (_INF, _NAN),
             (_NAN, _NAN),
             (_NAN, _NAN),
             (_NAN, _NAN),
             (_NAN, _NAN),
             (_INF, _NAN),
             (_NAN, _NAN)
         ],

     ],
     _SQRT_SV: list[list[tuple[float, float]]] = [
         [
             (_INF, -_INF),
             (0.0, -_INF),
             (0.0, -_INF),
             (0.0, _INF),
             (0.0, _INF),
             (_INF, _INF),
             (_NAN, _INF)
         ],
         [
             (_INF, -_INF),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (_INF, _INF),
             (_NAN, _NAN)
         ],
         [
             (_INF, -_INF),
             (0.0, 0.0),
             (0.0, -0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (_INF, _INF),
             (_NAN, _NAN)
         ],
         [
             (_INF, -_INF),
             (0.0, 0.0),
             (0.0, -0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (_INF, _INF),
             (_NAN, _NAN)
         ],
         [
             (_INF, -_INF),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (_INF, _INF),
             (_NAN, _NAN)
         ],
         [
             (_INF, -_INF),
             (_INF, -0.0),
             (_INF, -0.0),
             (_INF, 0.0),
             (_INF, 0.0),
             (_INF, _INF),
             (_INF, _NAN)
         ],
         [
             (_INF, -_INF),
             (_NAN, _NAN),
             (_NAN, _NAN),
             (_NAN, _NAN),
             (_NAN, _NAN),
             (_INF, _INF),
             (_NAN, _NAN)
         ],

     ],
     _SINH_SV: list[list[tuple[float, float]]] = [
         [
             (_INF, _NAN),
             (0.0, 0.0),
             (-_INF, -0.0),
             (-_INF, 0.0),
             (0.0, 0.0),
             (_INF, _NAN),
             (_INF, _NAN)
         ],
         [
             (_NAN, _NAN),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (_NAN, _NAN),
             (_NAN, _NAN)
         ],
         [
             (0.0, _NAN),
             (0.0, 0.0),
             (-0.0, -0.0),
             (-0.0, 0.0),
             (0.0, 0.0),
             (0.0, _NAN),
             (0.0, _NAN)
         ],
         [
             (0.0, _NAN),
             (0.0, 0.0),
             (0.0, -0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, _NAN),
             (0.0, _NAN)
         ],
         [
             (_NAN, _NAN),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (_NAN, _NAN),
             (_NAN, _NAN)
         ],
         [
             (_INF, _NAN),
             (0.0, 0.0),
             (_INF, -0.0),
             (_INF, 0.0),
             (0.0, 0.0),
             (_INF, _NAN),
             (_INF, _NAN)
         ],
         [
             (_NAN, _NAN),
             (_NAN, _NAN),
             (_NAN, -0.0),
             (_NAN, 0.0),
             (_NAN, _NAN),
             (_NAN, _NAN),
             (_NAN, _NAN)
         ],

     ],
     _TANH_SV: list[list[tuple[float, float]]] = [
         [
             (-1.0, 0.0),
             (0.0, 0.0),
             (-1.0, -0.0),
             (-1.0, 0.0),
             (0.0, 0.0),
             (-1.0, 0.0),
             (-1.0, 0.0)
         ],
         [
             (_NAN, _NAN),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (_NAN, _NAN),
             (_NAN, _NAN)
         ],
         [
             (-0.0, _NAN),
             (0.0, 0.0),
             (-0.0, -0.0),
             (-0.0, 0.0),
             (0.0, 0.0),
             (-0.0, _NAN),
             (-0.0, _NAN)
         ],
         [
             (0.0, _NAN),
             (0.0, 0.0),
             (0.0, -0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, _NAN),
             (0.0, _NAN)
         ],
         [
             (_NAN, _NAN),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (_NAN, _NAN),
             (_NAN, _NAN)
         ],
         [
             (1.0, 0.0),
             (0.0, 0.0),
             (1.0, -0.0),
             (1.0, 0.0),
             (0.0, 0.0),
             (1.0, 0.0),
             (1.0, 0.0)
         ],
         [
             (_NAN, _NAN),
             (_NAN, _NAN),
             (_NAN, -0.0),
             (_NAN, 0.0),
             (_NAN, _NAN),
             (_NAN, _NAN),
             (_NAN, _NAN)
         ],

     ],
     _RECT_SV: list[list[tuple[float, float]]] = [
         [
             (_INF, _NAN),
             (0.0, 0.0),
             (-_INF, 0.0),
             (-_INF, -0.0),
             (0.0, 0.0),
             (_INF, _NAN),
             (_INF, _NAN)
         ],
         [
             (_NAN, _NAN),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (_NAN, _NAN),
             (_NAN, _NAN)
         ],
         [
             (0.0, 0.0),
             (0.0, 0.0),
             (-0.0, 0.0),
             (-0.0, -0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0)
         ],
         [
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, -0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0)
         ],
         [
             (_NAN, _NAN),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (0.0, 0.0),
             (_NAN, _NAN),
             (_NAN, _NAN)
         ],
         [
             (_INF, _NAN),
             (0.0, 0.0),
             (_INF, -0.0),
             (_INF, 0.0),
             (0.0, 0.0),
             (_INF, _NAN),
             (_INF, _NAN)
         ],
         [
             (_NAN, _NAN),
             (_NAN, _NAN),
             (_NAN, 0.0),
             (_NAN, 0.0),
             (_NAN, _NAN),
             (_NAN, _NAN),
             (_NAN, _NAN)
         ],

     ];

# acos_special_values

# acosh_special_values

# asinh_special_values

# atanh_special_values

# cosh_special_values

# exp_special_values

# log_special_values

# sqrt_special_values

# sinh_special_values

# tanh_special_values

# rect_special_values
# ---------------- errno glue (math_error) ----------------

def:priv _check_errno(err: int) {
    if err == _EDOM {
        object_error("ValueError", "math domain error");
        raise boundary_failure();
    }
    if err == _ERANGE {
        object_error("OverflowError", "math range error");
        raise boundary_failure();
    }
}

# ---------------- core algorithms (c_* functions) ----------------

def:priv _c_sqrt(z: complex_parts) -> tuple[float, float, int] {
    if not (isfinite(z.real) and isfinite(z.imag)) {
        (re, im) = _sv_entry(_SQRT_SV, z);
        return (re, im, 0);
    }
    if z.real == 0.0 and z.imag == 0.0 {
        return (0.0, z.imag, 0);
    }
    ax = fabs(z.real);
    ay = fabs(z.imag);
    if ax < _DBL_MIN and ay < _DBL_MIN {
        # catch cases where hypot(ax, ay) is subnormal
        ax = scaled(ax, _CM_SCALE_UP);
        ay_up = scaled(ay, _CM_SCALE_UP);
        s = scaled(sqrt(ax + hypot(ax, ay_up)), _CM_SCALE_DOWN);
    } else {
        ax = ax / 8.0;
        s = 2.0 * sqrt(ax + hypot(ax, ay / 8.0));
    }
    d = ay / (2.0 * s);
    if z.real >= 0.0 {
        return (s, copysign(d, z.imag), 0);
    }
    return (d, copysign(s, z.imag), 0);
}

def:priv _c_log(z: complex_parts) -> tuple[float, float, int] {
    if not (isfinite(z.real) and isfinite(z.imag)) {
        (re, im) = _sv_entry(_LOG_SV, z);
        return (re, im, 0);
    }
    ax = fabs(z.real);
    ay = fabs(z.imag);
    if ax > _CM_LARGE_DOUBLE or ay > _CM_LARGE_DOUBLE {
        re = log(hypot(ax / 2.0, ay / 2.0)) + _M_LN2;
    } elif ax < _DBL_MIN and ay < _DBL_MIN {
        if ax > 0.0 or ay > 0.0 {
            # catch cases where hypot(ax, ay) is subnormal
            re = (
                log(hypot(scaled(ax, _DBL_MANT_DIG), scaled(ay, _DBL_MANT_DIG),))
                - _DBL_MANT_DIG * _M_LN2
            );
        } else {
            # log(+/-0. +/- 0i)
            return (-_INF, atan2(z.imag, z.real), _EDOM);
        }
    } else {
        h = hypot(ax, ay);
        if 0.71 <= h and h <= 1.73 {
            am = ax if ax > ay else ay;
            an = ay if ax > ay else ax;
            re = log1p((am - 1.0) * (am + 1.0) + an * an) / 2.0;
        } else {
            re = log(h);
        }
    }
    return (re, atan2(z.imag, z.real), 0);
}

def:priv _c_acos(z: complex_parts) -> tuple[float, float, int] {
    if not (isfinite(z.real) and isfinite(z.imag)) {
        (re, im) = _sv_entry(_ACOS_SV, z);
        return (re, im, 0);
    }
    if fabs(z.real) > _CM_LARGE_DOUBLE or fabs(z.imag) > _CM_LARGE_DOUBLE {
        # avoid unnecessary overflow for large arguments
        re = atan2(fabs(z.imag), z.real);
        im = -copysign(log(hypot(z.real / 2.0, z.imag / 2.0)) + _M_LN2 * 2.0, z.imag,);
    } else {
        s1 = _c_sqrt(complex_parts(1.0 - z.real, -z.imag));
        s2 = _c_sqrt(complex_parts(1.0 + z.real, z.imag));
        re = 2.0 * atan2(s1[0], s2[0]);
        im = asinh(s2[0] * s1[1] - s2[1] * s1[0]);
    }
    return (re, im, 0);
}

def:priv _c_acosh(z: complex_parts) -> tuple[float, float, int] {
    if not (isfinite(z.real) and isfinite(z.imag)) {
        (re, im) = _sv_entry(_ACOSH_SV, z);
        return (re, im, 0);
    }
    if fabs(z.real) > _CM_LARGE_DOUBLE or fabs(z.imag) > _CM_LARGE_DOUBLE {
        # avoid unnecessary overflow for large arguments
        re = log(hypot(z.real / 2.0, z.imag / 2.0)) + _M_LN2 * 2.0;
        im = atan2(z.imag, z.real);
    } else {
        s1 = _c_sqrt(complex_parts(z.real - 1.0, z.imag));
        s2 = _c_sqrt(complex_parts(z.real + 1.0, z.imag));
        re = asinh(s1[0] * s2[0] + s1[1] * s2[1]);
        im = 2.0 * atan2(s1[1], s2[0]);
    }
    return (re, im, 0);
}

def:priv _c_asinh(z: complex_parts) -> tuple[float, float, int] {
    if not (isfinite(z.real) and isfinite(z.imag)) {
        (re, im) = _sv_entry(_ASINH_SV, z);
        return (re, im, 0);
    }
    if fabs(z.real) > _CM_LARGE_DOUBLE or fabs(z.imag) > _CM_LARGE_DOUBLE {
        if z.imag >= 0.0 {
            re = copysign(
                log(hypot(z.real / 2.0, z.imag / 2.0)) + _M_LN2 * 2.0, z.real,
            );
        } else {
            re = -copysign(
                log(hypot(z.real / 2.0, z.imag / 2.0)) + _M_LN2 * 2.0, -z.real,
            );
        }
        im = atan2(z.imag, fabs(z.real));
    } else {
        s1 = _c_sqrt(complex_parts(1.0 + z.imag, -z.real));
        s2 = _c_sqrt(complex_parts(1.0 - z.imag, z.real));
        re = asinh(s1[0] * s2[1] - s2[0] * s1[1]);
        im = atan2(z.imag, s1[0] * s2[0] - s1[1] * s2[1]);
    }
    return (re, im, 0);
}

def:priv _c_atanh(z: complex_parts) -> tuple[float, float, int] {
    if not (isfinite(z.real) and isfinite(z.imag)) {
        (re, im) = _sv_entry(_ATANH_SV, z);
        return (re, im, 0);
    }
    # Reduce to case where z.real >= 0., using atanh(z) = -atanh(-z).
    negate = z.real < 0.0;
    zz = complex_parts(-z.real, -z.imag) if negate else z;
    ay = fabs(zz.imag);
    if zz.real > _CM_SQRT_LARGE_DOUBLE or ay > _CM_SQRT_LARGE_DOUBLE {
        # abs(z) large: atanh(z) ~ 1/z +/- i*pi/2 (+/- depending on sign of imag)
        h = hypot(zz.real / 2.0, zz.imag / 2.0);  # safe from overflow
        re = zz.real / 4.0 / h / h;
        im = copysign(_PI / 2.0, zz.imag);
        err = 0;
    } elif zz.real == 1.0 and ay < _CM_SQRT_DBL_MIN {
        # C99 standard says: atanh(1+/-0.) should be inf +/- 0i
        if ay == 0.0 {
            re = _INF;
            im = zz.imag;
            err = _EDOM;
        } else {
            re = -log(sqrt(ay) / sqrt(hypot(ay, 2.0)));
            im = copysign(atan2(2.0, -ay) / 2, zz.imag);
            err = 0;
        }
    } else {
        re = log1p(4.0 * zz.real / ((1.0 - zz.real) * (1.0 - zz.real) + ay * ay)) / 4.0;
        im = -atan2(-2.0 * zz.imag, (1.0 - zz.real) * (1.0 + zz.real) - ay * ay) / 2.0;
        err = 0;
    }
    if negate {
        return (-re, -im, err);  # float negation only
    }
    return (re, im, err);
}

def:priv _c_cosh(z: complex_parts) -> tuple[float, float, int] {
    # special treatment for cosh(+/-inf + iy) if y is not a NaN
    if not (isfinite(z.real) and isfinite(z.imag)) {
        if (isinf(z.real) and isfinite(z.imag) and z.imag != 0.0) {
            if z.real > 0 {
                re = copysign(_INF, cos(z.imag));
                im = copysign(_INF, sin(z.imag));
            } else {
                re = copysign(_INF, cos(z.imag));
                im = -copysign(_INF, sin(z.imag));
            }
        } else {
            (re, im) = _sv_entry(_COSH_SV, z);
        }
        # errno = EDOM if y is +/- infinity and x is not a NaN
        if isinf(z.imag) and not isnan(z.real) {
            return (re, im, _EDOM);
        }
        return (re, im, 0);
    }
    if fabs(z.real) > _CM_LOG_LARGE_DOUBLE {
        # deal correctly with cases where cosh(z.real) overflows but
        # cosh(z) does not
        x_minus_one = z.real - copysign(1.0, z.real);
        re = cos(z.imag) * cosh(x_minus_one) * e;
        im = sin(z.imag) * sinh(x_minus_one) * e;
    } else {
        re = cos(z.imag) * cosh(z.real);
        im = sin(z.imag) * sinh(z.real);
    }
    if isinf(re) or isinf(im) {
        return (re, im, _ERANGE);
    }
    return (re, im, 0);
}

def:priv _c_sinh(z: complex_parts) -> tuple[float, float, int] {
    # special treatment for sinh(+/-inf + iy) if y is finite and nonzero
    if not (isfinite(z.real) and isfinite(z.imag)) {
        if (isinf(z.real) and isfinite(z.imag) and z.imag != 0.0) {
            if z.real > 0 {
                re = copysign(_INF, cos(z.imag));
                im = copysign(_INF, sin(z.imag));
            } else {
                re = -copysign(_INF, cos(z.imag));
                im = copysign(_INF, sin(z.imag));
            }
        } else {
            (re, im) = _sv_entry(_SINH_SV, z);
        }
        # errno = EDOM if y is +/- infinity and x is not a NaN
        if isinf(z.imag) and not isnan(z.real) {
            return (re, im, _EDOM);
        }
        return (re, im, 0);
    }
    if fabs(z.real) > _CM_LOG_LARGE_DOUBLE {
        x_minus_one = z.real - copysign(1.0, z.real);
        re = cos(z.imag) * sinh(x_minus_one) * e;
        im = sin(z.imag) * cosh(x_minus_one) * e;
    } else {
        re = cos(z.imag) * sinh(z.real);
        im = sin(z.imag) * cosh(z.real);
    }
    if isinf(re) or isinf(im) {
        return (re, im, _ERANGE);
    }
    return (re, im, 0);
}

def:priv _c_exp(z: complex_parts) -> tuple[float, float, int] {
    if not (isfinite(z.real) and isfinite(z.imag)) {
        if (isinf(z.real) and isfinite(z.imag) and z.imag != 0.0) {
            if z.real > 0 {
                re = copysign(_INF, cos(z.imag));
                im = copysign(_INF, sin(z.imag));
            } else {
                re = copysign(0.0, cos(z.imag));
                im = copysign(0.0, sin(z.imag));
            }
        } else {
            (re, im) = _sv_entry(_EXP_SV, z);
        }
        # errno = EDOM if y is +/- infinity and x is not a NaN/-infinity
        if isinf(z.imag) and (isfinite(z.real) or (isinf(z.real) and z.real > 0)) {
            return (re, im, _EDOM);
        }
        return (re, im, 0);
    }
    if z.real > _CM_LOG_LARGE_DOUBLE {
        l = exp(z.real - 1.0);
        re = l * cos(z.imag) * e;
        im = l * sin(z.imag) * e;
    } else {
        l = exp(z.real);
        re = l * cos(z.imag);
        im = l * sin(z.imag);
    }
    if isinf(re) or isinf(im) {
        return (re, im, _ERANGE);
    }
    return (re, im, 0);
}

def:priv _c_tanh(z: complex_parts) -> tuple[float, float, int] {
    # tanh(x+iy) = (tanh(x)(1+tan(y)^2) + i tan(y)(1-tanh(x))^2) /
    #              (1+tan(y)^2 tanh(x)^2)
    # special treatment for tanh(+/-inf + iy) if y is finite and nonzero
    if not (isfinite(z.real) and isfinite(z.imag)) {
        if (isinf(z.real) and isfinite(z.imag) and z.imag != 0.0) {
            if z.real > 0 {
                re = 1.0;
            } else {
                re = -1.0;
            }
            im = copysign(0.0, 2.0 * sin(z.imag) * cos(z.imag));
        } else {
            (re, im) = _sv_entry(_TANH_SV, z);
        }
        # errno = EDOM if z.imag is +/- infinity and z.real is finite
        if isinf(z.imag) and isfinite(z.real) {
            return (re, im, _EDOM);
        }
        return (re, im, 0);
    }
    # danger of overflow in 2.*z.imag!
    if fabs(z.real) > _CM_LOG_LARGE_DOUBLE {
        re = copysign(1.0, z.real);
        im = 4.0 * sin(z.imag) * cos(z.imag) * exp(-2.0 * fabs(z.real));
        return (re, im, 0);
    }
    tx = tanh(z.real);
    ty = tan(z.imag);
    cx = 1.0 / cosh(z.real);
    txty = tx * ty;
    denom = 1.0 + txty * txty;
    re = tx * (1.0 + ty * ty) / denom;
    im = (ty / denom) * cx * cx;
    return (re, im, 0);
}

# _Py_c_abs; ERANGE on overflow of finite operands.
def:priv _c_abs(re: float, im: float) -> tuple[float, int] {
    r = hypot(re, im);
    if isinf(r) and isfinite(re) and isfinite(im) {
        return (r, _ERANGE);
    }
    return (r, 0);
}

def:priv close(
    a: complex_parts, b: complex_parts, rel_tol: float = 1e-09, abs_tol: float = 0.0
) -> bool {
    if rel_tol < 0.0 or abs_tol < 0.0 {
        object_error("ValueError", "tolerances must be non-negative");
        raise boundary_failure();
    }
    if a.real == b.real and a.imag == b.imag {
        # short circuit exact equality -- needed to catch two infinities of
        # the same sign
        return True;
    }
    # catches opposite infinities, or one infinity and one finite number
    if (isinf(a.real) or isinf(a.imag) or isinf(b.real) or isinf(b.imag)) {
        return False;
    }
    # the "weak" test from the Boost library
    (diff, _) = _c_abs(a.real - b.real, a.imag - b.imag);
    (abs_a, _) = _c_abs(a.real, a.imag);
    (abs_b, _) = _c_abs(b.real, b.imag);
    return (diff <= rel_tol * abs_b or diff <= rel_tol * abs_a or diff <= abs_tol);
}

def:priv rectangular(r: float, phi: float) -> complex_parts {
    if not (isfinite(r) and isfinite(phi)) {
        if isinf(r) and isfinite(phi) and phi != 0.0 {
            # (+-INF +-INF i): signs come from cos(phi)/sin(phi)
            if r > 0 {
                re = copysign(_INF, cos(phi));
                im = copysign(_INF, sin(phi));
            } else {
                re = -copysign(_INF, cos(phi));
                im = -copysign(_INF, sin(phi));
            }
        } else {
            (re, im) = _sv_entry(_RECT_SV, complex_parts(r, phi));
        }
        # errno = EDOM if r is a nonzero number and phi is infinite
        if r != 0.0 and not isnan(r) and isinf(phi) {
            object_error("ValueError", "math domain error");
            raise boundary_failure();
        }
    } elif phi == 0.0 {
        # workaround for buggy results with phi=-0.0 on some platforms
        re = r;
        im = r * phi;
    } else {
        re = r * cos(phi);
        im = r * sin(phi);
    }
    return complex_parts(re, im);
}


def:priv input_complex(value: u64) -> complex_parts {
    handle = required(jacpy_complex_value(value));
    try {
        return complex_parts(jacpy_complex_real(handle), jacpy_complex_imag(handle));
    } finally {
        jacpy_release(handle);
    }
}

def:priv input_float(value: u64) -> float {
    result = jacpy_number_as_double(value);
    if jacpy_error_pending() != 0 {
        raise boundary_failure();
    }
    return result;
}

def:priv unary(operation: int, z: complex_parts) -> tuple[float, float, int] {
    if operation == 0 {
        return _c_acos(z);
    }
    if operation == 1 {
        return _c_acosh(z);
    }
    if operation == 2 {
        result = _c_asinh(complex_parts(-z.imag, z.real));
        return (result[1], -result[0], result[2]);
    }
    if operation == 3 {
        return _c_asinh(z);
    }
    if operation == 4 {
        result = _c_atanh(complex_parts(-z.imag, z.real));
        return (result[1], -result[0], result[2]);
    }
    if operation == 5 {
        return _c_atanh(z);
    }
    if operation == 6 {
        return _c_cosh(complex_parts(-z.imag, z.real));
    }
    if operation == 7 {
        return _c_cosh(z);
    }
    if operation == 8 {
        return _c_exp(z);
    }
    if operation == 9 {
        result = _c_sinh(complex_parts(-z.imag, z.real));
        return (result[1], -result[0], result[2]);
    }
    if operation == 10 {
        return _c_sinh(z);
    }
    if operation == 11 {
        return _c_sqrt(z);
    }
    if operation == 12 {
        result = _c_tanh(complex_parts(-z.imag, z.real));
        return (result[1], -result[0], result[2]);
    }
    if operation == 13 {
        return _c_tanh(z);
    }
    result = _c_log(z);
    return (result[0] / _M_LN10, result[1] / _M_LN10, result[2]);
}

def:pub jacpy_cmath_unary(operation: i64, value: u64) -> u64 {
    try {
        z = input_complex(value);
        if operation == 15 {
            jacpy_clear_errno();
            angle_value = atan2(z.imag, z.real);
            _check_errno(int(jacpy_math_errno()));
            return jacpy_float(angle_value);
        }
        if operation == 16 {
            (radius, error) = _c_abs(z.real, z.imag);
            _check_errno(error);
            angle: u64 = 0;
            radius_object = required(jacpy_float(radius));
            try {
                angle = required(jacpy_float(atan2(z.imag, z.real)));
                return object_tuple([radius_object, angle]);
            } finally {
                jacpy_release(radius_object);
                jacpy_release(angle);
            }
        }
        if operation == 17 {
            return jacpy_boolean(i64(isfinite(z.real) and isfinite(z.imag)));
        }
        if operation == 18 {
            return jacpy_boolean(i64(isinf(z.real) or isinf(z.imag)));
        }
        if operation == 19 {
            return jacpy_boolean(i64(isnan(z.real) or isnan(z.imag)));
        }
        result = unary(int(operation), z);
        _check_errno(result[2]);
        return jacpy_complex(result[0], result[1]);
    } except boundary_failure {
        return 0;
    }
}

def:pub jacpy_cmath_log(value: u64, base: u64) -> u64 {
    try {
        z = input_complex(value);
        result = _c_log(z);
        if base != 0 {
            divisor = _c_log(input_complex(base));
            _check_errno(divisor[2]);
            numerator = required(jacpy_complex(result[0], result[1]));
            denominator: u64 = 0;
            try {
                denominator = required(jacpy_complex(divisor[0], divisor[1]));
                quotient = jacpy_truediv(numerator, denominator);
                if quotient == 0 and jacpy_error_is("ZeroDivisionError") != 0 {
                    _check_errno(_EDOM);
                }
                return required(quotient);
            } finally {
                jacpy_release(numerator);
                jacpy_release(denominator);
            }
        }
        _check_errno(result[2]);
        return jacpy_complex(result[0], result[1]);
    } except boundary_failure {
        return 0;
    }
}

def:pub jacpy_cmath_rect(radius: u64, angle: u64) -> u64 {
    try {
        r = input_float(radius);
        phi = input_float(angle);
        result = rectangular(r, phi);
        return jacpy_complex(result.real, result.imag);
    } except boundary_failure {
        return 0;
    }
}

def:pub jacpy_cmath_isclose(
    left: u64, right: u64, relative: u64, absolute: u64
) -> u64 {
    try {
        a = input_complex(left);
        b = input_complex(right);
        relative_tolerance = input_float(relative) if relative != 0 else 1e-9;
        absolute_tolerance = input_float(absolute) if absolute != 0 else 0.0;
        return jacpy_boolean(i64(close(a, b, relative_tolerance, absolute_tolerance)));
    } except boundary_failure {
        return 0;
    }
}
