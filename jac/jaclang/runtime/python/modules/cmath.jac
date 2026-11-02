"""Native complex transcendental algorithms and IEEE special-value rules.

Recovered algorithms are checked against pinned CPython 3.14.6, with real
transcendentals supplied by libm. See ../LICENSE.cpython.
"""

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
    table: list[list[tuple[float, float]]], z: tuple[float, float]
) -> tuple[float, float] {
    cell: tuple[float, float] = table[_special_type(z[0])][_special_type(z[1])];
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
        object_error(PyExc_ValueError, "math domain error");
        raise boundary_failure();
    }
    if err == _ERANGE {
        object_error(PyExc_OverflowError, "math range error");
        raise boundary_failure();
    }
}

# ---------------- core algorithms (c_* functions) ----------------

def:priv _c_sqrt(zr: float, zi: float) -> tuple[float, float, int] {
    if not (isfinite(zr) and isfinite(zi)) {
        (re, im) = _sv_entry(_SQRT_SV, (zr, zi));
        return (re, im, 0);
    }
    if zr == 0.0 and zi == 0.0 {
        return (0.0, zi, 0);
    }
    ax = fabs(zr);
    ay = fabs(zi);
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
    if zr >= 0.0 {
        return (s, copysign(d, zi), 0);
    }
    return (d, copysign(s, zi), 0);
}

def:priv _c_log(zr: float, zi: float) -> tuple[float, float, int] {
    if not (isfinite(zr) and isfinite(zi)) {
        (re, im) = _sv_entry(_LOG_SV, (zr, zi));
        return (re, im, 0);
    }
    ax = fabs(zr);
    ay = fabs(zi);
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
            return (-_INF, atan2(zi, zr), _EDOM);
        }
    } else {
        h = hypot(ax, ay);
        if 0.71 <= h and h <= 1.73 {
            am = ax if ax > ay else ay;
            an = ay if ax > ay else ax;
            re = _Py_log1p((am - 1.0) * (am + 1.0) + an * an) / 2.0;
        } else {
            re = log(h);
        }
    }
    return (re, atan2(zi, zr), 0);
}

def:priv _c_acos(zr: float, zi: float) -> tuple[float, float, int] {
    if not (isfinite(zr) and isfinite(zi)) {
        (re, im) = _sv_entry(_ACOS_SV, (zr, zi));
        return (re, im, 0);
    }
    if fabs(zr) > _CM_LARGE_DOUBLE or fabs(zi) > _CM_LARGE_DOUBLE {
        # avoid unnecessary overflow for large arguments
        re = atan2(fabs(zi), zr);
        im = -copysign(log(hypot(zr / 2.0, zi / 2.0)) + _M_LN2 * 2.0, zi,);
    } else {
        s1 = _c_sqrt(1.0 - zr, -zi);
        s2 = _c_sqrt(1.0 + zr, zi);
        re = 2.0 * atan2(s1[0], s2[0]);
        im = asinh(s2[0] * s1[1] - s2[1] * s1[0]);
    }
    return (re, im, 0);
}

def:priv _c_acosh(zr: float, zi: float) -> tuple[float, float, int] {
    if not (isfinite(zr) and isfinite(zi)) {
        (re, im) = _sv_entry(_ACOSH_SV, (zr, zi));
        return (re, im, 0);
    }
    if fabs(zr) > _CM_LARGE_DOUBLE or fabs(zi) > _CM_LARGE_DOUBLE {
        # avoid unnecessary overflow for large arguments
        re = log(hypot(zr / 2.0, zi / 2.0)) + _M_LN2 * 2.0;
        im = atan2(zi, zr);
    } else {
        s1 = _c_sqrt(zr - 1.0, zi);
        s2 = _c_sqrt(zr + 1.0, zi);
        re = asinh(s1[0] * s2[0] + s1[1] * s2[1]);
        im = 2.0 * atan2(s1[1], s2[0]);
    }
    return (re, im, 0);
}

def:priv _c_asinh(zr: float, zi: float) -> tuple[float, float, int] {
    if not (isfinite(zr) and isfinite(zi)) {
        (re, im) = _sv_entry(_ASINH_SV, (zr, zi));
        return (re, im, 0);
    }
    if fabs(zr) > _CM_LARGE_DOUBLE or fabs(zi) > _CM_LARGE_DOUBLE {
        if zi >= 0.0 {
            re = copysign(log(hypot(zr / 2.0, zi / 2.0)) + _M_LN2 * 2.0, zr,);
        } else {
            re = -copysign(log(hypot(zr / 2.0, zi / 2.0)) + _M_LN2 * 2.0, -zr,);
        }
        im = atan2(zi, fabs(zr));
    } else {
        s1 = _c_sqrt(1.0 + zi, -zr);
        s2 = _c_sqrt(1.0 - zi, zr);
        re = asinh(s1[0] * s2[1] - s2[0] * s1[1]);
        im = atan2(zi, s1[0] * s2[0] - s1[1] * s2[1]);
    }
    return (re, im, 0);
}

def:priv _c_atanh(zr: float, zi: float) -> tuple[float, float, int] {
    if not (isfinite(zr) and isfinite(zi)) {
        (re, im) = _sv_entry(_ATANH_SV, (zr, zi));
        return (re, im, 0);
    }
    # Reduce to case where zr >= 0., using atanh(z) = -atanh(-z).
    negate = zr < 0.0;
    zzr = -zr if negate else zr;
    zzi = -zi if negate else zi;
    ay = fabs(zzi);
    if zzr > _CM_SQRT_LARGE_DOUBLE or ay > _CM_SQRT_LARGE_DOUBLE {
        # abs(z) large: atanh(z) ~ 1/z +/- i*pi/2 (+/- depending on sign of imag)
        h = hypot(zzr / 2.0, zzi / 2.0);  # safe from overflow
        re = zzr / 4.0 / h / h;
        im = copysign(_PI / 2.0, zzi);
        err = 0;
    } elif zzr == 1.0 and ay < _CM_SQRT_DBL_MIN {
        # C99 standard says: atanh(1+/-0.) should be inf +/- 0i
        if ay == 0.0 {
            re = _INF;
            im = zzi;
            err = _EDOM;
        } else {
            re = -log(sqrt(ay) / sqrt(hypot(ay, 2.0)));
            im = copysign(atan2(2.0, -ay) / 2, zzi);
            err = 0;
        }
    } else {
        re = _Py_log1p(4.0 * zzr / ((1.0 - zzr) * (1.0 - zzr) + ay * ay)) / 4.0;
        im = -atan2(-2.0 * zzi, (1.0 - zzr) * (1.0 + zzr) - ay * ay) / 2.0;
        err = 0;
    }
    if negate {
        return (-re, -im, err);  # float negation only
    }
    return (re, im, err);
}

def:priv _c_cosh(zr: float, zi: float) -> tuple[float, float, int] {
    # special treatment for cosh(+/-inf + iy) if y is not a NaN
    if not (isfinite(zr) and isfinite(zi)) {
        if (isinf(zr) and isfinite(zi) and zi != 0.0) {
            if zr > 0 {
                re = copysign(_INF, cos(zi));
                im = copysign(_INF, sin(zi));
            } else {
                re = copysign(_INF, cos(zi));
                im = -copysign(_INF, sin(zi));
            }
        } else {
            (re, im) = _sv_entry(_COSH_SV, (zr, zi));
        }
        # errno = EDOM if y is +/- infinity and x is not a NaN
        if isinf(zi) and not isnan(zr) {
            return (re, im, _EDOM);
        }
        return (re, im, 0);
    }
    if fabs(zr) > _CM_LOG_LARGE_DOUBLE {
        # deal correctly with cases where cosh(zr) overflows but
        # cosh(z) does not
        x_minus_one = zr - copysign(1.0, zr);
        re = cos(zi) * cosh(x_minus_one) * e;
        im = sin(zi) * sinh(x_minus_one) * e;
    } else {
        re = cos(zi) * cosh(zr);
        im = sin(zi) * sinh(zr);
    }
    if isinf(re) or isinf(im) {
        return (re, im, _ERANGE);
    }
    return (re, im, 0);
}

def:priv _c_sinh(zr: float, zi: float) -> tuple[float, float, int] {
    # special treatment for sinh(+/-inf + iy) if y is finite and nonzero
    if not (isfinite(zr) and isfinite(zi)) {
        if (isinf(zr) and isfinite(zi) and zi != 0.0) {
            if zr > 0 {
                re = copysign(_INF, cos(zi));
                im = copysign(_INF, sin(zi));
            } else {
                re = -copysign(_INF, cos(zi));
                im = copysign(_INF, sin(zi));
            }
        } else {
            (re, im) = _sv_entry(_SINH_SV, (zr, zi));
        }
        # errno = EDOM if y is +/- infinity and x is not a NaN
        if isinf(zi) and not isnan(zr) {
            return (re, im, _EDOM);
        }
        return (re, im, 0);
    }
    if fabs(zr) > _CM_LOG_LARGE_DOUBLE {
        x_minus_one = zr - copysign(1.0, zr);
        re = cos(zi) * sinh(x_minus_one) * e;
        im = sin(zi) * cosh(x_minus_one) * e;
    } else {
        re = cos(zi) * sinh(zr);
        im = sin(zi) * cosh(zr);
    }
    if isinf(re) or isinf(im) {
        return (re, im, _ERANGE);
    }
    return (re, im, 0);
}

def:priv _c_exp(zr: float, zi: float) -> tuple[float, float, int] {
    if not (isfinite(zr) and isfinite(zi)) {
        if (isinf(zr) and isfinite(zi) and zi != 0.0) {
            if zr > 0 {
                re = copysign(_INF, cos(zi));
                im = copysign(_INF, sin(zi));
            } else {
                re = copysign(0.0, cos(zi));
                im = copysign(0.0, sin(zi));
            }
        } else {
            (re, im) = _sv_entry(_EXP_SV, (zr, zi));
        }
        # errno = EDOM if y is +/- infinity and x is not a NaN/-infinity
        if isinf(zi) and (isfinite(zr) or (isinf(zr) and zr > 0)) {
            return (re, im, _EDOM);
        }
        return (re, im, 0);
    }
    if zr > _CM_LOG_LARGE_DOUBLE {
        l = exp(zr - 1.0);
        re = l * cos(zi) * e;
        im = l * sin(zi) * e;
    } else {
        l = exp(zr);
        re = l * cos(zi);
        im = l * sin(zi);
    }
    if isinf(re) or isinf(im) {
        return (re, im, _ERANGE);
    }
    return (re, im, 0);
}

def:priv _c_tanh(zr: float, zi: float) -> tuple[float, float, int] {
    # tanh(x+iy) = (tanh(x)(1+tan(y)^2) + i tan(y)(1-tanh(x))^2) /
    #              (1+tan(y)^2 tanh(x)^2)
    # special treatment for tanh(+/-inf + iy) if y is finite and nonzero
    if not (isfinite(zr) and isfinite(zi)) {
        if (isinf(zr) and isfinite(zi) and zi != 0.0) {
            if zr > 0 {
                re = 1.0;
            } else {
                re = -1.0;
            }
            im = copysign(0.0, 2.0 * sin(zi) * cos(zi));
        } else {
            (re, im) = _sv_entry(_TANH_SV, (zr, zi));
        }
        # errno = EDOM if zi is +/- infinity and zr is finite
        if isinf(zi) and isfinite(zr) {
            return (re, im, _EDOM);
        }
        return (re, im, 0);
    }
    # danger of overflow in 2.*zi!
    if fabs(zr) > _CM_LOG_LARGE_DOUBLE {
        re = copysign(1.0, zr);
        im = 4.0 * sin(zi) * cos(zi) * exp(-2.0 * fabs(zr));
        return (re, im, 0);
    }
    tx = tanh(zr);
    ty = tan(zi);
    cx = 1.0 / cosh(zr);
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
    a: tuple[float, float],
    b: tuple[float, float],
    rel_tol: float = 1e-09,
    abs_tol: float = 0.0
) -> bool {
    if rel_tol < 0.0 or abs_tol < 0.0 {
        object_error(PyExc_ValueError, "tolerances must be non-negative");
        raise boundary_failure();
    }
    if a[0] == b[0] and a[1] == b[1] {
        # short circuit exact equality -- needed to catch two infinities of
        # the same sign
        return True;
    }
    # catches opposite infinities, or one infinity and one finite number
    if (isinf(a[0]) or isinf(a[1]) or isinf(b[0]) or isinf(b[1])) {
        return False;
    }
    # the "weak" test from the Boost library
    (diff, _) = _c_abs(a[0] - b[0], a[1] - b[1]);
    (abs_a, _) = _c_abs(a[0], a[1]);
    (abs_b, _) = _c_abs(b[0], b[1]);
    return (diff <= rel_tol * abs_b or diff <= rel_tol * abs_a or diff <= abs_tol);
}

def:priv rectangular(r: float, phi: float) -> tuple[float, float] {
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
            (re, im) = _sv_entry(_RECT_SV, (r, phi));
        }
        # errno = EDOM if r is a nonzero number and phi is infinite
        if r != 0.0 and not isnan(r) and isinf(phi) {
            object_error(PyExc_ValueError, "math domain error");
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
    return (re, im);
}

def:priv complex_slow(value: ptr[PyObject]) -> tuple[float, float] {
    c = PyComplex_AsCComplex(value);
    return (c.real, c.imag);
}

def:priv complex_of(value: ptr[PyObject]) -> tuple[float, float] {
    if object_type(value) == ptr[PyTypeObject](addressof(PyComplex_Type)) {
        record = ptr[PyComplexObject](value).view(1);
        return (record[0].cval.real, record[0].cval.imag);
    }
    return complex_slow(value);
}

def:priv input_complex(value: ptr[PyObject]) -> tuple[float, float] {
    c = complex_of(value);
    if c[0] == -1.0 and PyErr_Occurred() {
        raise boundary_failure();
    }
    return c;
}

def:priv input_float(value: ptr[PyObject]) -> float {
    result = PyFloat_AsDouble(value);
    if jacpy_error_pending() != 0 {
        raise boundary_failure();
    }
    return result;
}

def:priv unary(operation: int, zr: float, zi: float) -> tuple[float, float, int] {
    if operation == 0 {
        return _c_acos(zr, zi);
    }
    if operation == 1 {
        return _c_acosh(zr, zi);
    }
    if operation == 2 {
        result = _c_asinh(-zi, zr);
        return (result[1], -result[0], result[2]);
    }
    if operation == 3 {
        return _c_asinh(zr, zi);
    }
    if operation == 4 {
        result = _c_atanh(-zi, zr);
        return (result[1], -result[0], result[2]);
    }
    if operation == 5 {
        return _c_atanh(zr, zi);
    }
    if operation == 6 {
        return _c_cosh(-zi, zr);
    }
    if operation == 7 {
        return _c_cosh(zr, zi);
    }
    if operation == 8 {
        return _c_exp(zr, zi);
    }
    if operation == 9 {
        result = _c_sinh(-zi, zr);
        return (result[1], -result[0], result[2]);
    }
    if operation == 10 {
        return _c_sinh(zr, zi);
    }
    if operation == 11 {
        return _c_sqrt(zr, zi);
    }
    if operation == 12 {
        result = _c_tanh(-zi, zr);
        return (result[1], -result[0], result[2]);
    }
    if operation == 13 {
        return _c_tanh(zr, zi);
    }
    result = _c_log(zr, zi);
    return (result[0] / _M_LN10, result[1] / _M_LN10, result[2]);
}

def:priv set_errno_error(error: i64) -> ptr[PyObject] {
    if error == _EDOM {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("math domain error"));
    } else {
        PyErr_SetString(PyExc_OverflowError, ptr[u8]("math range error"));
    }
    return NULL;
}

def:pub jacpy_cmath_unary(operation: int, zr: float, zi: float) -> ptr[PyObject] {
    if operation == 15 {
        jacpy_clear_errno();
        angle_value = atan2(zi, zr);
        error = i64(jacpy_math_errno());
        if error == _EDOM or error == _ERANGE {
            return set_errno_error(error);
        }
        return PyFloat_FromDouble(angle_value);
    }
    if operation == 16 {
        (radius, abs_error) = _c_abs(zr, zi);
        if abs_error != 0 {
            return set_errno_error(i64(abs_error));
        }
        radius_object = PyFloat_FromDouble(radius);
        if radius_object == NULL {
            return NULL;
        }
        angle = PyFloat_FromDouble(atan2(zi, zr));
        if angle == NULL {
            jacpy_release(radius_object);
            return NULL;
        }
        result_tuple = PyTuple_New(2);
        if result_tuple == NULL {
            jacpy_release(radius_object);
            jacpy_release(angle);
            return NULL;
        }
        PyTuple_SetItem(result_tuple, 0, radius_object);
        PyTuple_SetItem(result_tuple, 1, angle);
        return result_tuple;
    }
    if operation == 17 {
        return PyBool_FromLong(i64(isfinite(zr) and isfinite(zi)));
    }
    if operation == 18 {
        return PyBool_FromLong(i64(isinf(zr) or isinf(zi)));
    }
    if operation == 19 {
        return PyBool_FromLong(i64(isnan(zr) or isnan(zi)));
    }
    result = unary(int(operation), zr, zi);
    if result[2] == _EDOM or result[2] == _ERANGE {
        return set_errno_error(i64(result[2]));
    }
    return PyComplex_FromDoubles(result[0], result[1]);
}

def:pub jacpy_cmath_call(operation: int, value: ptr[PyObject]) -> ptr[PyObject] {
    if object_type(value) == ptr[PyTypeObject](addressof(PyComplex_Type)) {
        record = ptr[PyComplexObject](value).view(1);
        return jacpy_cmath_unary(operation, record[0].cval.real, record[0].cval.imag);
    }
    c = complex_slow(value);
    if PyErr_Occurred() {
        return NULL;
    }
    return jacpy_cmath_unary(operation, c[0], c[1]);
}

def convert_Py_complex(
    value: ptr[PyObject], fname: str, label: str
) -> tuple[float, float] {
    return complex_of(value);
}

def convert_Py_complex_protected(
    value: ptr[PyObject], fname: str, label: str
) -> tuple[float, float] {
    return complex_of(value);
}

def return_Py_complex_protected(result: tuple[float, float, int]) -> ptr[PyObject] {
    if result[2] == _EDOM or result[2] == _ERANGE {
        return set_errno_error(result[2]);
    }
    return PyComplex_FromDoubles(result[0], result[1]);
}

def:priv as_result(result: tuple[float, float, int]) -> tuple[float, float, int] {
    return (result[0], result[1], i64(result[2]));
}

def:priv swapped(result: tuple[float, float, int]) -> tuple[float, float, int] {
    return (result[1], -result[0], i64(result[2]));
}

def cmath_acos_impl(
    module: ptr[PyObject], z: tuple[float, float]
) -> tuple[float, float, int] {
    return as_result(_c_acos(z[0], z[1]));
}

def cmath_acosh_impl(
    module: ptr[PyObject], z: tuple[float, float]
) -> tuple[float, float, int] {
    return as_result(_c_acosh(z[0], z[1]));
}

def cmath_asin_impl(
    module: ptr[PyObject], z: tuple[float, float]
) -> tuple[float, float, int] {
    return swapped(_c_asinh(-z[1], z[0]));
}

def cmath_asinh_impl(
    module: ptr[PyObject], z: tuple[float, float]
) -> tuple[float, float, int] {
    return as_result(_c_asinh(z[0], z[1]));
}

def cmath_atan_impl(
    module: ptr[PyObject], z: tuple[float, float]
) -> tuple[float, float, int] {
    return swapped(_c_atanh(-z[1], z[0]));
}

def cmath_atanh_impl(
    module: ptr[PyObject], z: tuple[float, float]
) -> tuple[float, float, int] {
    return as_result(_c_atanh(z[0], z[1]));
}

def cmath_cos_impl(
    module: ptr[PyObject], z: tuple[float, float]
) -> tuple[float, float, int] {
    return as_result(_c_cosh(-z[1], z[0]));
}

def cmath_cosh_impl(
    module: ptr[PyObject], z: tuple[float, float]
) -> tuple[float, float, int] {
    return as_result(_c_cosh(z[0], z[1]));
}

def cmath_exp_impl(
    module: ptr[PyObject], z: tuple[float, float]
) -> tuple[float, float, int] {
    return as_result(_c_exp(z[0], z[1]));
}

def cmath_sin_impl(
    module: ptr[PyObject], z: tuple[float, float]
) -> tuple[float, float, int] {
    return swapped(_c_sinh(-z[1], z[0]));
}

def cmath_sinh_impl(
    module: ptr[PyObject], z: tuple[float, float]
) -> tuple[float, float, int] {
    return as_result(_c_sinh(z[0], z[1]));
}

def cmath_sqrt_impl(
    module: ptr[PyObject], z: tuple[float, float]
) -> tuple[float, float, int] {
    return as_result(_c_sqrt(z[0], z[1]));
}

def cmath_tan_impl(
    module: ptr[PyObject], z: tuple[float, float]
) -> tuple[float, float, int] {
    return swapped(_c_tanh(-z[1], z[0]));
}

def cmath_tanh_impl(
    module: ptr[PyObject], z: tuple[float, float]
) -> tuple[float, float, int] {
    return as_result(_c_tanh(z[0], z[1]));
}

def cmath_log10_impl(
    module: ptr[PyObject], z: tuple[float, float]
) -> tuple[float, float, int] {
    result = _c_log(z[0], z[1]);
    return (result[0] / _M_LN10, result[1] / _M_LN10, i64(result[2]));
}

def cmath_log_impl(
    module: ptr[PyObject], z: tuple[float, float], base: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        result = _c_log(z[0], z[1]);
        if base != 0 {
            base_value = input_complex(base);
            divisor = _c_log(base_value[0], base_value[1]);
            _check_errno(divisor[2]);
            numerator = required(PyComplex_FromDoubles(result[0], result[1]));
            denominator: ptr[PyObject] = NULL;
            try {
                denominator = required(PyComplex_FromDoubles(divisor[0], divisor[1]));
                quotient = PyNumber_TrueDivide(numerator, denominator);
                if quotient == 0
                    and PyErr_ExceptionMatches(PyExc_ZeroDivisionError) != 0 {
                    _check_errno(_EDOM);
                }
                return required(quotient);
            } finally {
                jacpy_release(numerator);
                jacpy_release(denominator);
            }
        }
        _check_errno(result[2]);
        return PyComplex_FromDoubles(result[0], result[1]);
    } except boundary_failure {
        return NULL;
    }
}

def cmath_phase_impl(module: ptr[PyObject], z: tuple[float, float]) -> ptr[PyObject] {
    return jacpy_cmath_unary(15, z[0], z[1]);
}

def cmath_polar_impl(module: ptr[PyObject], z: tuple[float, float]) -> ptr[PyObject] {
    return jacpy_cmath_unary(16, z[0], z[1]);
}

def cmath_isfinite_impl(
    module: ptr[PyObject], z: tuple[float, float]
) -> ptr[PyObject] {
    return jacpy_cmath_unary(17, z[0], z[1]);
}

def cmath_isinf_impl(module: ptr[PyObject], z: tuple[float, float]) -> ptr[PyObject] {
    return jacpy_cmath_unary(18, z[0], z[1]);
}

def cmath_isnan_impl(module: ptr[PyObject], z: tuple[float, float]) -> ptr[PyObject] {
    return jacpy_cmath_unary(19, z[0], z[1]);
}

def cmath_rect_impl(module: ptr[PyObject], r: f64, phi: f64) -> ptr[PyObject] {
    try {
        result = rectangular(r, phi);
        return PyComplex_FromDoubles(result[0], result[1]);
    } except boundary_failure {
        return NULL;
    }
}

# cmath.isclose returns clinic's bool: -1 with the error set on failure.
def cmath_isclose_impl(
    module: ptr[PyObject],
    a: tuple[float, float],
    b: tuple[float, float],
    rel_tol: f64,
    abs_tol: f64
) -> i32 {
    try {
        return i32(close(a, b, rel_tol, abs_tol));
    } except boundary_failure {
        return i32(-1);
    }
}
