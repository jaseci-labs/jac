import from _math_native {
    m_asinh,
    m_atan2,
    m_copysign,
    m_cos,
    m_cosh,
    m_exp,
    m_fabs,
    m_hypot,
    m_log,
    m_log1p,
    m_sin,
    m_sinh,
    m_sqrt,
    m_tan,
    m_tanh
}

import from math { isfinite as _isf, isinf as _isi, isnan as _isn }

def _scale_up(value: float) -> float {
    return value * 9007199254740992.0;
}


def _scale_down(value: float) -> float {
    return value * 7.450580596923828125e-9;
}

glob:pub pi: float = 3.141592653589793,
     e: float = 2.718281828459045,
     tau: float = 6.283185307179586,
     inf: float = float("inf"),
     nan: float = float("nan"),
     infj: complex = complex(0.0, float("inf")),
     nanj: complex = complex(0.0, float("nan"));

glob _DBL_MAX: float = 1.7976931348623157e308,
     _DBL_MIN: float = 2.2250738585072014e-308,
     _DBL_MANT_DIG: int = 53,
     _CM_LARGE_DOUBLE: float = _DBL_MAX / 4.0,
     _CM_SQRT_LARGE_DOUBLE: float = 6.703904478183408e153,
     _CM_LOG_LARGE_DOUBLE: float = 708.3964185322641,
     _CM_SQRT_DBL_MIN: float = 1.4916681462400413e-154,
     _M_LN2: float = 0.6931471805599453094,
     _M_LN10: float = 2.302585092994045684,
     _EDOM: int = 1,
     _ERANGE: int = 2;

def _special_type(d: float) -> int {
    if _isf(d) {
        if d != 0.0 {
            return 4 if m_copysign(1.0, d) == 1.0 else 1;
        }
        return 3 if m_copysign(1.0, d) == 1.0 else 2;
    }
    if _isn(d) {
        return 6;
    }
    return 5 if m_copysign(1.0, d) == 1.0 else 0;
}

def _sv_entry(
    table: list[list[tuple[float, float]]], z: complex
) -> tuple[float, float] {
    return table[_special_type(z.real)][_special_type(z.imag)];
}

glob _INF: float = inf,
     _NAN: float = nan,
     _PI: float = pi,
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

def _raise_err(err: int) {
    if err == _EDOM {
        raise ValueError("math domain error");
    }
    if err == _ERANGE {
        raise OverflowError("math range error");
    }
}

def _c_sqrt(z: complex) -> tuple[float, float, int] {
    if not (_isf(z.real) and _isf(z.imag)) {
        (re, im) = _sv_entry(_SQRT_SV, z);
        return (re, im, 0);
    }
    if z.real == 0.0 and z.imag == 0.0 {
        return (0.0, z.imag, 0);
    }
    ax = m_fabs(z.real);
    ay = m_fabs(z.imag);
    if ax < _DBL_MIN and ay < _DBL_MIN {
        ax = _scale_up(ax);
        ay_up = _scale_up(ay);
        s = _scale_down(m_sqrt(ax + m_hypot(ax, ay_up)));
    } else {
        ax = ax / 8.0;
        s = 2.0 * m_sqrt(ax + m_hypot(ax, ay / 8.0));
    }
    d = ay / (2.0 * s);
    if z.real >= 0.0 {
        return (s, m_copysign(d, z.imag), 0);
    }
    return (d, m_copysign(s, z.imag), 0);
}

def _c_log(z: complex) -> tuple[float, float, int] {
    if not (_isf(z.real) and _isf(z.imag)) {
        (re, im) = _sv_entry(_LOG_SV, z);
        return (re, im, 0);
    }
    ax = m_fabs(z.real);
    ay = m_fabs(z.imag);
    if ax > _CM_LARGE_DOUBLE or ay > _CM_LARGE_DOUBLE {
        re = m_log(m_hypot(ax / 2.0, ay / 2.0)) + _M_LN2;
    } elif ax < _DBL_MIN and ay < _DBL_MIN {
        if ax > 0.0 or ay > 0.0 {
            re = m_log(m_hypot(_scale_up(ax), _scale_up(ay))) - _DBL_MANT_DIG * _M_LN2;
        } else {
            return (-_INF, m_atan2(z.imag, z.real), _EDOM);
        }
    } else {
        h = m_hypot(ax, ay);
        if 0.71 <= h and h <= 1.73 {
            am = ax if ax > ay else ay;
            an = ay if ax > ay else ax;
            re = m_log1p((am - 1.0) * (am + 1.0) + an * an) / 2.0;
        } else {
            re = m_log(h);
        }
    }
    return (re, m_atan2(z.imag, z.real), 0);
}

def _c_acos(z: complex) -> tuple[float, float, int] {
    if not (_isf(z.real) and _isf(z.imag)) {
        (re, im) = _sv_entry(_ACOS_SV, z);
        return (re, im, 0);
    }
    if m_fabs(z.real) > _CM_LARGE_DOUBLE or m_fabs(z.imag) > _CM_LARGE_DOUBLE {
        re = m_atan2(m_fabs(z.imag), z.real);
        im = -m_copysign(
            m_log(m_hypot(z.real / 2.0, z.imag / 2.0)) + _M_LN2 * 2.0, z.imag,
        );
    } else {
        (s1r, s1i, _e1) = _c_sqrt(complex(1.0 - z.real, -z.imag));
        (s2r, s2i, _e2) = _c_sqrt(complex(1.0 + z.real, z.imag));
        re = 2.0 * m_atan2(s1r, s2r);
        im = m_asinh(s2r * s1i - s2i * s1r);
    }
    return (re, im, 0);
}

def _c_acosh(z: complex) -> tuple[float, float, int] {
    if not (_isf(z.real) and _isf(z.imag)) {
        (re, im) = _sv_entry(_ACOSH_SV, z);
        return (re, im, 0);
    }
    if m_fabs(z.real) > _CM_LARGE_DOUBLE or m_fabs(z.imag) > _CM_LARGE_DOUBLE {
        re = m_log(m_hypot(z.real / 2.0, z.imag / 2.0)) + _M_LN2 * 2.0;
        im = m_atan2(z.imag, z.real);
    } else {
        (s1r, s1i, _e1) = _c_sqrt(complex(z.real - 1.0, z.imag));
        (s2r, s2i, _e2) = _c_sqrt(complex(z.real + 1.0, z.imag));
        re = m_asinh(s1r * s2r + s1i * s2i);
        im = 2.0 * m_atan2(s1i, s2r);
    }
    return (re, im, 0);
}

def _c_asinh(z: complex) -> tuple[float, float, int] {
    if not (_isf(z.real) and _isf(z.imag)) {
        (re, im) = _sv_entry(_ASINH_SV, z);
        return (re, im, 0);
    }
    if m_fabs(z.real) > _CM_LARGE_DOUBLE or m_fabs(z.imag) > _CM_LARGE_DOUBLE {
        if z.imag >= 0.0 {
            re = m_copysign(
                m_log(m_hypot(z.real / 2.0, z.imag / 2.0)) + _M_LN2 * 2.0, z.real,
            );
        } else {
            re = -m_copysign(
                m_log(m_hypot(z.real / 2.0, z.imag / 2.0)) + _M_LN2 * 2.0, -z.real,
            );
        }
        im = m_atan2(z.imag, m_fabs(z.real));
    } else {
        (s1r, s1i, _e1) = _c_sqrt(complex(1.0 + z.imag, -z.real));
        (s2r, s2i, _e2) = _c_sqrt(complex(1.0 - z.imag, z.real));
        re = m_asinh(s1r * s2i - s2r * s1i);
        im = m_atan2(z.imag, s1r * s2r - s1i * s2i);
    }
    return (re, im, 0);
}

def _c_atanh(z: complex) -> tuple[float, float, int] {
    if not (_isf(z.real) and _isf(z.imag)) {
        (re, im) = _sv_entry(_ATANH_SV, z);
        return (re, im, 0);
    }

    negate = z.real < 0.0;
    zz = complex(-z.real, -z.imag) if negate else z;
    ay = m_fabs(zz.imag);
    if zz.real > _CM_SQRT_LARGE_DOUBLE or ay > _CM_SQRT_LARGE_DOUBLE {
        h = m_hypot(zz.real / 2.0, zz.imag / 2.0);
        re = zz.real / 4.0 / h / h;
        im = m_copysign(_PI / 2.0, zz.imag);
        err = 0;
    } elif zz.real == 1.0 and ay < _CM_SQRT_DBL_MIN {
        if ay == 0.0 {
            re = _INF;
            im = zz.imag;
            err = _EDOM;
        } else {
            re = -m_log(m_sqrt(ay) / m_sqrt(m_hypot(ay, 2.0)));
            im = m_copysign(m_atan2(2.0, -ay) / 2, zz.imag);
            err = 0;
        }
    } else {
        re = m_log1p(4.0 * zz.real / ((1.0 - zz.real) * (1.0 - zz.real) + ay * ay))
            / 4.0;
        im = -m_atan2(-2.0 * zz.imag, (1.0 - zz.real) * (1.0 + zz.real) - ay * ay)
            / 2.0;
        err = 0;
    }
    if negate {
        return (-re, -im, err);
    }
    return (re, im, err);
}

def _c_cosh(z: complex) -> tuple[float, float, int] {
    if not (_isf(z.real) and _isf(z.imag)) {
        if (_isi(z.real) and _isf(z.imag) and z.imag != 0.0) {
            if z.real > 0 {
                re = m_copysign(_INF, m_cos(z.imag));
                im = m_copysign(_INF, m_sin(z.imag));
            } else {
                re = m_copysign(_INF, m_cos(z.imag));
                im = -m_copysign(_INF, m_sin(z.imag));
            }
        } else {
            (re, im) = _sv_entry(_COSH_SV, z);
        }

        if _isi(z.imag) and not _isn(z.real) {
            return (re, im, _EDOM);
        }
        return (re, im, 0);
    }
    if m_fabs(z.real) > _CM_LOG_LARGE_DOUBLE {
        x_minus_one = z.real - m_copysign(1.0, z.real);
        re = m_cos(z.imag) * m_cosh(x_minus_one) * e;
        im = m_sin(z.imag) * m_sinh(x_minus_one) * e;
    } else {
        re = m_cos(z.imag) * m_cosh(z.real);
        im = m_sin(z.imag) * m_sinh(z.real);
    }
    if _isi(re) or _isi(im) {
        return (re, im, _ERANGE);
    }
    return (re, im, 0);
}

def _c_sinh(z: complex) -> tuple[float, float, int] {
    if not (_isf(z.real) and _isf(z.imag)) {
        if (_isi(z.real) and _isf(z.imag) and z.imag != 0.0) {
            if z.real > 0 {
                re = m_copysign(_INF, m_cos(z.imag));
                im = m_copysign(_INF, m_sin(z.imag));
            } else {
                re = -m_copysign(_INF, m_cos(z.imag));
                im = m_copysign(_INF, m_sin(z.imag));
            }
        } else {
            (re, im) = _sv_entry(_SINH_SV, z);
        }

        if _isi(z.imag) and not _isn(z.real) {
            return (re, im, _EDOM);
        }
        return (re, im, 0);
    }
    if m_fabs(z.real) > _CM_LOG_LARGE_DOUBLE {
        x_minus_one = z.real - m_copysign(1.0, z.real);
        re = m_cos(z.imag) * m_sinh(x_minus_one) * e;
        im = m_sin(z.imag) * m_cosh(x_minus_one) * e;
    } else {
        re = m_cos(z.imag) * m_sinh(z.real);
        im = m_sin(z.imag) * m_cosh(z.real);
    }
    if _isi(re) or _isi(im) {
        return (re, im, _ERANGE);
    }
    return (re, im, 0);
}

def _c_exp(z: complex) -> tuple[float, float, int] {
    if not (_isf(z.real) and _isf(z.imag)) {
        if (_isi(z.real) and _isf(z.imag) and z.imag != 0.0) {
            if z.real > 0 {
                re = m_copysign(_INF, m_cos(z.imag));
                im = m_copysign(_INF, m_sin(z.imag));
            } else {
                re = m_copysign(0.0, m_cos(z.imag));
                im = m_copysign(0.0, m_sin(z.imag));
            }
        } else {
            (re, im) = _sv_entry(_EXP_SV, z);
        }

        if _isi(z.imag) and (_isf(z.real) or (_isi(z.real) and z.real > 0)) {
            return (re, im, _EDOM);
        }
        return (re, im, 0);
    }
    if z.real > _CM_LOG_LARGE_DOUBLE {
        l = m_exp(z.real - 1.0);
        re = l * m_cos(z.imag) * e;
        im = l * m_sin(z.imag) * e;
    } else {
        l = m_exp(z.real);
        re = l * m_cos(z.imag);
        im = l * m_sin(z.imag);
    }
    if _isi(re) or _isi(im) {
        return (re, im, _ERANGE);
    }
    return (re, im, 0);
}

def _c_tanh(z: complex) -> tuple[float, float, int] {
    if not (_isf(z.real) and _isf(z.imag)) {
        if (_isi(z.real) and _isf(z.imag) and z.imag != 0.0) {
            if z.real > 0 {
                re = 1.0;
            } else {
                re = -1.0;
            }
            im = m_copysign(0.0, 2.0 * m_sin(z.imag) * m_cos(z.imag));
        } else {
            (re, im) = _sv_entry(_TANH_SV, z);
        }

        if _isi(z.imag) and _isf(z.real) {
            return (re, im, _EDOM);
        }
        return (re, im, 0);
    }

    if m_fabs(z.real) > _CM_LOG_LARGE_DOUBLE {
        re = m_copysign(1.0, z.real);
        im = 4.0 * m_sin(z.imag) * m_cos(z.imag) * m_exp(-2.0 * m_fabs(z.real));
        return (re, im, 0);
    }
    tx = m_tanh(z.real);
    ty = m_tan(z.imag);
    cx = 1.0 / m_cosh(z.real);
    txty = tx * ty;
    denom = 1.0 + txty * txty;
    re = tx * (1.0 + ty * ty) / denom;
    im = (ty / denom) * cx * cx;
    return (re, im, 0);
}

def _c_abs(re: float, im: float) -> tuple[float, int] {
    r = m_hypot(re, im);
    if _isi(r) and _isf(re) and _isf(im) {
        return (r, _ERANGE);
    }
    return (r, 0);
}

def _close(
    a: complex, b: complex, rel_tol: float = 1e-09, abs_tol: float = 0.0
) -> bool {
    if rel_tol < 0.0 or abs_tol < 0.0 {
        raise ValueError("tolerances must be non-negative");
    }
    if a.real == b.real and a.imag == b.imag {
        return True;
    }

    if (_isi(a.real) or _isi(a.imag) or _isi(b.real) or _isi(b.imag)) {
        return False;
    }

    (diff, _) = _c_abs(a.real - b.real, a.imag - b.imag);
    (abs_a, _) = _c_abs(a.real, a.imag);
    (abs_b, _) = _c_abs(b.real, b.imag);
    return (diff <= rel_tol * abs_b or diff <= rel_tol * abs_a or diff <= abs_tol);
}

def _rectangular(r: float, phi: float) -> complex {
    if not (_isf(r) and _isf(phi)) {
        if _isi(r) and _isf(phi) and phi != 0.0 {
            if r > 0 {
                re = m_copysign(_INF, m_cos(phi));
                im = m_copysign(_INF, m_sin(phi));
            } else {
                re = -m_copysign(_INF, m_cos(phi));
                im = -m_copysign(_INF, m_sin(phi));
            }
        } else {
            (re, im) = _sv_entry(_RECT_SV, complex(r, phi));
        }

        if r != 0.0 and not _isn(r) and _isi(phi) {
            raise ValueError("math domain error");
        }
    } elif phi == 0.0 {
        re = r;
        im = r * phi;
    } else {
        re = r * m_cos(phi);
        im = r * m_sin(phi);
    }
    return complex(re, im);
}

def:pub acos(z: complex) -> complex {
    (re, im, err) = _c_acos(z);
    _raise_err(err);
    return complex(re, im);
}

def:pub acosh(z: complex) -> complex {
    (re, im, err) = _c_acosh(z);
    _raise_err(err);
    return complex(re, im);
}

def:pub asin(z: complex) -> complex {
    (re, im, err) = _c_asinh(complex(-z.imag, z.real));
    _raise_err(err);
    return complex(im, -re);
}

def:pub asinh(z: complex) -> complex {
    (re, im, err) = _c_asinh(z);
    _raise_err(err);
    return complex(re, im);
}

def:pub atan(z: complex) -> complex {
    (re, im, err) = _c_atanh(complex(-z.imag, z.real));
    _raise_err(err);
    return complex(im, -re);
}

def:pub atanh(z: complex) -> complex {
    (re, im, err) = _c_atanh(z);
    _raise_err(err);
    return complex(re, im);
}

def:pub cos(z: complex) -> complex {
    (re, im, err) = _c_cosh(complex(-z.imag, z.real));
    _raise_err(err);
    return complex(re, im);
}

def:pub cosh(z: complex) -> complex {
    (re, im, err) = _c_cosh(z);
    _raise_err(err);
    return complex(re, im);
}

def:pub exp(z: complex) -> complex {
    (re, im, err) = _c_exp(z);
    _raise_err(err);
    return complex(re, im);
}

def:pub sin(z: complex) -> complex {
    (re, im, err) = _c_sinh(complex(-z.imag, z.real));
    _raise_err(err);
    return complex(im, -re);
}

def:pub sinh(z: complex) -> complex {
    (re, im, err) = _c_sinh(z);
    _raise_err(err);
    return complex(re, im);
}

def:pub sqrt(z: complex) -> complex {
    (re, im, err) = _c_sqrt(z);
    _raise_err(err);
    return complex(re, im);
}

def:pub tan(z: complex) -> complex {
    (re, im, err) = _c_tanh(complex(-z.imag, z.real));
    _raise_err(err);
    return complex(im, -re);
}

def:pub tanh(z: complex) -> complex {
    (re, im, err) = _c_tanh(z);
    _raise_err(err);
    return complex(re, im);
}

def:pub log(z: complex, base: (complex | None) = None) -> complex {
    (re, im, err) = _c_log(z);
    _raise_err(err);
    if base is None {
        return complex(re, im);
    }
    (br, bi, berr) = _c_log(base);
    _raise_err(berr);
    if br == 0.0 and bi == 0.0 {
        raise ValueError("math domain error");
    }
    return complex(re, im) / complex(br, bi);
}

def:pub log10(z: complex) -> complex {
    (re, im, err) = _c_log(z);
    _raise_err(err);
    return complex(re / _M_LN10, im / _M_LN10);
}

def:pub phase(z: complex) -> float {
    return m_atan2(z.imag, z.real);
}

def:pub polar(z: complex) -> tuple[float, float] {
    (radius, err) = _c_abs(z.real, z.imag);
    _raise_err(err);
    return (radius, m_atan2(z.imag, z.real));
}

def:pub rect(r: float, phi: float) -> complex {
    return _rectangular(r, phi);
}

def:pub isfinite(z: complex) -> bool {
    return _isf(z.real) and _isf(z.imag);
}

def:pub isinf(z: complex) -> bool {
    return _isi(z.real) or _isi(z.imag);
}

def:pub isnan(z: complex) -> bool {
    return _isn(z.real) or _isn(z.imag);
}

def:pub isclose(
    a: complex, b: complex, *, rel_tol: float = 1e-09, abs_tol: float = 0.0
) -> bool {
    return _close(a, b, rel_tol, abs_tol);
}
