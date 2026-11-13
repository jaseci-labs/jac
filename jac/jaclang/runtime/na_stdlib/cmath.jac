import from math { isfinite as _isf, isinf as _isi, isnan as _isn }

def _scale_up(value: float) -> float;


def _scale_down(value: float) -> float;

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

def _special_type(d: float) -> int;

def _sv_entry(
    table: list[list[tuple[float, float]]], z: complex
) -> tuple[float, float];

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

def _raise_err(err: int);

def _c_sqrt(z: complex) -> tuple[float, float, int];

def _c_log(z: complex) -> tuple[float, float, int];

def _c_acos(z: complex) -> tuple[float, float, int];

def _c_acosh(z: complex) -> tuple[float, float, int];

def _c_asinh(z: complex) -> tuple[float, float, int];

def _c_atanh(z: complex) -> tuple[float, float, int];

def _c_cosh(z: complex) -> tuple[float, float, int];

def _c_sinh(z: complex) -> tuple[float, float, int];

def _c_exp(z: complex) -> tuple[float, float, int];

def _c_tanh(z: complex) -> tuple[float, float, int];

def _c_abs(re: float, im: float) -> tuple[float, int];

def _close(
    a: complex, b: complex, rel_tol: float = 1e-09, abs_tol: float = 0.0
) -> bool;

def _rectangular(r: float, phi: float) -> complex;

def:pub acos(z: complex) -> complex;

def:pub acosh(z: complex) -> complex;

def:pub asin(z: complex) -> complex;

def:pub asinh(z: complex) -> complex;

def:pub atan(z: complex) -> complex;

def:pub atanh(z: complex) -> complex;

def:pub cos(z: complex) -> complex;

def:pub cosh(z: complex) -> complex;

def:pub exp(z: complex) -> complex;

def:pub sin(z: complex) -> complex;

def:pub sinh(z: complex) -> complex;

def:pub sqrt(z: complex) -> complex;

def:pub tan(z: complex) -> complex;

def:pub tanh(z: complex) -> complex;

def:pub log(z: complex, base: (complex | None) = None) -> complex;

def:pub log10(z: complex) -> complex;

def:pub phase(z: complex) -> float;

def:pub polar(z: complex) -> tuple[float, float];

def:pub rect(r: float, phi: float) -> complex;

def:pub isfinite(z: complex) -> bool;

def:pub isinf(z: complex) -> bool;

def:pub isnan(z: complex) -> bool;

def:pub isclose(
    a: complex, b: complex, *, rel_tol: float = 1e-09, abs_tol: float = 0.0
) -> bool;
