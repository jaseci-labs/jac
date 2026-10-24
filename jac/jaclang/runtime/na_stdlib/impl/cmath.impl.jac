impl _scale_up(value: float) -> float {
    return value * 9007199254740992.0;
}

impl _scale_down(value: float) -> float {
    return value * 7.450580596923828125e-9;
}

impl _special_type(d: float) -> int {
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

impl _sv_entry(
    table: list[list[tuple[float, float]]], z: complex
) -> tuple[float, float] {
    return table[_special_type(z.real)][_special_type(z.imag)];
}

impl _raise_err(err: int) {
    if err == _EDOM {
        raise ValueError("math domain error");
    }
    if err == _ERANGE {
        raise OverflowError("math range error");
    }
}

impl _c_sqrt(z: complex) -> tuple[float, float, int] {
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

impl _c_log(z: complex) -> tuple[float, float, int] {
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

impl _c_acos(z: complex) -> tuple[float, float, int] {
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

impl _c_acosh(z: complex) -> tuple[float, float, int] {
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

impl _c_asinh(z: complex) -> tuple[float, float, int] {
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

impl _c_atanh(z: complex) -> tuple[float, float, int] {
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

impl _c_cosh(z: complex) -> tuple[float, float, int] {
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

impl _c_sinh(z: complex) -> tuple[float, float, int] {
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

impl _c_exp(z: complex) -> tuple[float, float, int] {
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

impl _c_tanh(z: complex) -> tuple[float, float, int] {
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

impl _c_abs(re: float, im: float) -> tuple[float, int] {
    r = m_hypot(re, im);
    if _isi(r) and _isf(re) and _isf(im) {
        return (r, _ERANGE);
    }
    return (r, 0);
}

impl _close(
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

impl _rectangular(r: float, phi: float) -> complex {
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

impl acos(z: complex) -> complex {
    (re, im, err) = _c_acos(z);
    _raise_err(err);
    return complex(re, im);
}

impl acosh(z: complex) -> complex {
    (re, im, err) = _c_acosh(z);
    _raise_err(err);
    return complex(re, im);
}

impl asin(z: complex) -> complex {
    (re, im, err) = _c_asinh(complex(-z.imag, z.real));
    _raise_err(err);
    return complex(im, -re);
}

impl asinh(z: complex) -> complex {
    (re, im, err) = _c_asinh(z);
    _raise_err(err);
    return complex(re, im);
}

impl atan(z: complex) -> complex {
    (re, im, err) = _c_atanh(complex(-z.imag, z.real));
    _raise_err(err);
    return complex(im, -re);
}

impl atanh(z: complex) -> complex {
    (re, im, err) = _c_atanh(z);
    _raise_err(err);
    return complex(re, im);
}

impl cos(z: complex) -> complex {
    (re, im, err) = _c_cosh(complex(-z.imag, z.real));
    _raise_err(err);
    return complex(re, im);
}

impl cosh(z: complex) -> complex {
    (re, im, err) = _c_cosh(z);
    _raise_err(err);
    return complex(re, im);
}

impl exp(z: complex) -> complex {
    (re, im, err) = _c_exp(z);
    _raise_err(err);
    return complex(re, im);
}

impl sin(z: complex) -> complex {
    (re, im, err) = _c_sinh(complex(-z.imag, z.real));
    _raise_err(err);
    return complex(im, -re);
}

impl sinh(z: complex) -> complex {
    (re, im, err) = _c_sinh(z);
    _raise_err(err);
    return complex(re, im);
}

impl sqrt(z: complex) -> complex {
    (re, im, err) = _c_sqrt(z);
    _raise_err(err);
    return complex(re, im);
}

impl tan(z: complex) -> complex {
    (re, im, err) = _c_tanh(complex(-z.imag, z.real));
    _raise_err(err);
    return complex(im, -re);
}

impl tanh(z: complex) -> complex {
    (re, im, err) = _c_tanh(z);
    _raise_err(err);
    return complex(re, im);
}

impl log(z: complex, base: (complex | None) = None) -> complex {
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

impl log10(z: complex) -> complex {
    (re, im, err) = _c_log(z);
    _raise_err(err);
    return complex(re / _M_LN10, im / _M_LN10);
}

impl phase(z: complex) -> float {
    return m_atan2(z.imag, z.real);
}

impl polar(z: complex) -> tuple[float, float] {
    (radius, err) = _c_abs(z.real, z.imag);
    _raise_err(err);
    return (radius, m_atan2(z.imag, z.real));
}

impl rect(r: float, phi: float) -> complex {
    return _rectangular(r, phi);
}

impl isfinite(z: complex) -> bool {
    return _isf(z.real) and _isf(z.imag);
}

impl isinf(z: complex) -> bool {
    return _isi(z.real) or _isi(z.imag);
}

impl isnan(z: complex) -> bool {
    return _isn(z.real) or _isn(z.imag);
}

impl isclose(
    a: complex, b: complex, *, rel_tol: float = 1e-09, abs_tol: float = 0.0
) -> bool {
    return _close(a, b, rel_tol, abs_tol);
}
