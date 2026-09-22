"""cmath module cross-backend equivalence fixture.

The SAME `import from cmath { ... }` binds CPython's `cmath` on the sv
(Python) backend and the bundled `na_stdlib/cmath.jac` Mechanism-B module
on the na (native LLVM) backend — a pure-Jac port of CPython's
cmathmodule.c algorithms over the `_math_native` libm floor. Complex
results are decomposed into `<key>_r`/`<key>_i` float keys so the harness's
1e-9 float tolerance applies; `inf`/`nan` components are pinned through
predicates. Error paths store "<ClassName>: <str(e)>" with a WRONG-TYPE
fallback so a differently-typed raise surfaces as a value mismatch.
"""

import from cmath {
    acos,
    acosh,
    asin,
    asinh,
    atan,
    atanh,
    cos,
    cosh,
    e,
    exp,
    inf,
    infj,
    isclose,
    isfinite,
    isinf,
    isnan,
    log,
    log10,
    nanj,
    phase,
    pi,
    polar,
    rect,
    sin,
    sinh,
    sqrt,
    tan,
    tanh,
    tau
}

import cmath;


def _fill_py(r: dict[str, any]) {
    sq = sqrt(complex(-1.0, 0.0));
    ex = exp(complex(1.0, 1.0));
    lg = log(complex(e, 0.0));
    l10 = log10(complex(100.0, 0.0));
    asn = asin(complex(0.5, 0.0));
    acs = acos(complex(2.0, 0.0));
    atn = atan(complex(0.0, 2.0));
    sh = sinh(complex(1.0, 1.0));
    ch = cosh(complex(1.0, 1.0));
    th = tanh(complex(1.0, 1.0));
    sn = sin(complex(1.0, 1.0));
    cs = cos(complex(1.0, 1.0));
    tn = tan(complex(1.0, 1.0));
    ash = asinh(complex(1.0, 1.0));
    ach = acosh(complex(2.0, 0.0));
    ath = atanh(complex(0.5, 0.0));
    lb = log(complex(8.0, 0.0), complex(2.0, 0.0));
    si = sqrt(infj);
    (pr, pphi) = polar(complex(3.0, 4.0));
    rc = rect(2.0, pi / 2.0);
    r["sqrt_neg_r"] = sq.real;
    r["sqrt_neg_i"] = sq.imag;
    r["exp_r"] = ex.real;
    r["exp_i"] = ex.imag;
    r["log_r"] = lg.real;
    r["log_i"] = lg.imag;
    r["log10_r"] = l10.real;
    r["log10_i"] = l10.imag;
    r["asin_r"] = asn.real;
    r["asin_i"] = asn.imag;
    r["acos_r"] = acs.real;
    r["acos_i"] = acs.imag;
    r["atan_r"] = atn.real;
    r["atan_i"] = atn.imag;
    r["sinh_r"] = sh.real;
    r["sinh_i"] = sh.imag;
    r["cosh_r"] = ch.real;
    r["cosh_i"] = ch.imag;
    r["tanh_r"] = th.real;
    r["tanh_i"] = th.imag;
    r["sin_r"] = sn.real;
    r["sin_i"] = sn.imag;
    r["cos_r"] = cs.real;
    r["cos_i"] = cs.imag;
    r["tan_r"] = tn.real;
    r["tan_i"] = tn.imag;
    r["asinh_r"] = ash.real;
    r["asinh_i"] = ash.imag;
    r["acosh_r"] = ach.real;
    r["acosh_i"] = ach.imag;
    r["atanh_r"] = ath.real;
    r["atanh_i"] = ath.imag;
    r["logb_r"] = lb.real;
    r["logb_i"] = lb.imag;
    r["sqrt_infj_r"] = 1 if si.real == inf else 0;
    r["sqrt_infj_i"] = 1 if si.imag == inf else 0;
    r["attr_call_i"] = sqrt(complex(-1.0, 0.0)).imag;
    r["attr_binop_r"] = (complex(1.0, 2.0) + complex(3.0, 4.0)).real;
    pw = complex(0.0, 1.0) ** 2;
    r["pow_int_r"] = pw.real;
    r["pow_int_i"] = pw.imag;
    pwf = complex(0.0, 1.0) ** 2.0;
    r["pow_float_r"] = pwf.real;
    r["pow_float_i"] = pwf.imag;
    r["phase_neg"] = phase(complex(-1.0, 0.0));
    r["phase_pos"] = phase(complex(1.0, 0.0));
    r["polar_r"] = pr;
    r["polar_phi"] = pphi;
    r["rect_r"] = rc.real;
    r["rect_i"] = rc.imag;
    r["isfinite_t"] = 1 if isfinite(complex(1.0, 2.0)) else 0;
    r["isfinite_f"] = 1 if isfinite(infj) else 0;
    r["isinf_t"] = 1 if isinf(infj) else 0;
    r["isinf_f"] = 1 if isinf(complex(1.0, 0.0)) else 0;
    r["isnan_t"] = 1 if isnan(nanj) else 0;
    r["isnan_f"] = 1 if isnan(complex(1.0, 0.0)) else 0;
    r["isclose_t"] = 1 if isclose(complex(1.0, 0.0), complex(1.0, 1e-10)) else 0;
    r["isclose_f"] = 1 if isclose(complex(1.0, 0.0), complex(1.0, 0.1)) else 0;
    r["pi"] = pi;
    r["e"] = e;
    r["tau"] = tau;
    r["attr_pi"] = cmath.pi;
    r["attr_infj_i"] = 1 if cmath.infj.imag == inf else 0;
    r["err_exp_over"] = "no-raise";
    try {
        exp(complex(1000.0, 0.0));
    } except OverflowError as exc {
        r["err_exp_over"] = "OverflowError: " + str(exc);
    } except Exception as exc {
        r["err_exp_over"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_log_zero"] = "no-raise";
    try {
        log(complex(0.0, 0.0));
    } except ValueError as exc {
        r["err_log_zero"] = "ValueError: " + str(exc);
    } except Exception as exc {
        r["err_log_zero"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_atanh_one"] = "no-raise";
    try {
        atanh(complex(1.0, 0.0));
    } except ValueError as exc {
        r["err_atanh_one"] = "ValueError: " + str(exc);
    } except Exception as exc {
        r["err_atanh_one"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_log_base0"] = "no-raise";
    try {
        log(complex(2.0, 0.0), complex(1.0, 0.0));
    } except ValueError as exc {
        r["err_log_base0"] = "ValueError: " + str(exc);
    } except Exception as exc {
        r["err_log_base0"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_rect_infphi"] = "no-raise";
    try {
        rect(1.0, infj.imag);
    } except ValueError as exc {
        r["err_rect_infphi"] = "ValueError: " + str(exc);
    } except Exception as exc {
        r["err_rect_infphi"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_isclose_neg"] = "no-raise";
    try {
        isclose(complex(1.0, 0.0), complex(1.0, 0.0), rel_tol=-1.0);
    } except ValueError as exc {
        r["err_isclose_neg"] = "ValueError: " + str(exc);
    } except Exception as exc {
        r["err_isclose_neg"] = "WRONG-TYPE: " + str(exc);
    }
}

# Mirrors _fill_py for the native lane. A shared body cannot serve both lanes:
# pinned functions emit as FFI shims on the Python side and unpinned helpers
# are not pulled into the native closure, so each lane needs its own body.
def _fill_na(r: dict[str, any]) {
    sq = sqrt(complex(-1.0, 0.0));
    ex = exp(complex(1.0, 1.0));
    lg = log(complex(e, 0.0));
    l10 = log10(complex(100.0, 0.0));
    asn = asin(complex(0.5, 0.0));
    acs = acos(complex(2.0, 0.0));
    atn = atan(complex(0.0, 2.0));
    sh = sinh(complex(1.0, 1.0));
    ch = cosh(complex(1.0, 1.0));
    th = tanh(complex(1.0, 1.0));
    sn = sin(complex(1.0, 1.0));
    cs = cos(complex(1.0, 1.0));
    tn = tan(complex(1.0, 1.0));
    ash = asinh(complex(1.0, 1.0));
    ach = acosh(complex(2.0, 0.0));
    ath = atanh(complex(0.5, 0.0));
    lb = log(complex(8.0, 0.0), complex(2.0, 0.0));
    si = sqrt(infj);
    (pr, pphi) = polar(complex(3.0, 4.0));
    rc = rect(2.0, pi / 2.0);
    r["sqrt_neg_r"] = sq.real;
    r["sqrt_neg_i"] = sq.imag;
    r["exp_r"] = ex.real;
    r["exp_i"] = ex.imag;
    r["log_r"] = lg.real;
    r["log_i"] = lg.imag;
    r["log10_r"] = l10.real;
    r["log10_i"] = l10.imag;
    r["asin_r"] = asn.real;
    r["asin_i"] = asn.imag;
    r["acos_r"] = acs.real;
    r["acos_i"] = acs.imag;
    r["atan_r"] = atn.real;
    r["atan_i"] = atn.imag;
    r["sinh_r"] = sh.real;
    r["sinh_i"] = sh.imag;
    r["cosh_r"] = ch.real;
    r["cosh_i"] = ch.imag;
    r["tanh_r"] = th.real;
    r["tanh_i"] = th.imag;
    r["sin_r"] = sn.real;
    r["sin_i"] = sn.imag;
    r["cos_r"] = cs.real;
    r["cos_i"] = cs.imag;
    r["tan_r"] = tn.real;
    r["tan_i"] = tn.imag;
    r["asinh_r"] = ash.real;
    r["asinh_i"] = ash.imag;
    r["acosh_r"] = ach.real;
    r["acosh_i"] = ach.imag;
    r["atanh_r"] = ath.real;
    r["atanh_i"] = ath.imag;
    r["logb_r"] = lb.real;
    r["logb_i"] = lb.imag;
    r["sqrt_infj_r"] = 1 if si.real == inf else 0;
    r["sqrt_infj_i"] = 1 if si.imag == inf else 0;
    r["attr_call_i"] = sqrt(complex(-1.0, 0.0)).imag;
    r["attr_binop_r"] = (complex(1.0, 2.0) + complex(3.0, 4.0)).real;
    pw = complex(0.0, 1.0) ** 2;
    r["pow_int_r"] = pw.real;
    r["pow_int_i"] = pw.imag;
    pwf = complex(0.0, 1.0) ** 2.0;
    r["pow_float_r"] = pwf.real;
    r["pow_float_i"] = pwf.imag;
    r["phase_neg"] = phase(complex(-1.0, 0.0));
    r["phase_pos"] = phase(complex(1.0, 0.0));
    r["polar_r"] = pr;
    r["polar_phi"] = pphi;
    r["rect_r"] = rc.real;
    r["rect_i"] = rc.imag;
    r["isfinite_t"] = 1 if isfinite(complex(1.0, 2.0)) else 0;
    r["isfinite_f"] = 1 if isfinite(infj) else 0;
    r["isinf_t"] = 1 if isinf(infj) else 0;
    r["isinf_f"] = 1 if isinf(complex(1.0, 0.0)) else 0;
    r["isnan_t"] = 1 if isnan(nanj) else 0;
    r["isnan_f"] = 1 if isnan(complex(1.0, 0.0)) else 0;
    r["isclose_t"] = 1 if isclose(complex(1.0, 0.0), complex(1.0, 1e-10)) else 0;
    r["isclose_f"] = 1 if isclose(complex(1.0, 0.0), complex(1.0, 0.1)) else 0;
    r["pi"] = pi;
    r["e"] = e;
    r["tau"] = tau;
    r["attr_pi"] = cmath.pi;
    r["attr_infj_i"] = 1 if cmath.infj.imag == inf else 0;
    r["err_exp_over"] = "no-raise";
    try {
        exp(complex(1000.0, 0.0));
    } except OverflowError as exc {
        r["err_exp_over"] = "OverflowError: " + str(exc);
    } except Exception as exc {
        r["err_exp_over"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_log_zero"] = "no-raise";
    try {
        log(complex(0.0, 0.0));
    } except ValueError as exc {
        r["err_log_zero"] = "ValueError: " + str(exc);
    } except Exception as exc {
        r["err_log_zero"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_atanh_one"] = "no-raise";
    try {
        atanh(complex(1.0, 0.0));
    } except ValueError as exc {
        r["err_atanh_one"] = "ValueError: " + str(exc);
    } except Exception as exc {
        r["err_atanh_one"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_log_base0"] = "no-raise";
    try {
        log(complex(2.0, 0.0), complex(1.0, 0.0));
    } except ValueError as exc {
        r["err_log_base0"] = "ValueError: " + str(exc);
    } except Exception as exc {
        r["err_log_base0"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_rect_infphi"] = "no-raise";
    try {
        rect(1.0, infj.imag);
    } except ValueError as exc {
        r["err_rect_infphi"] = "ValueError: " + str(exc);
    } except Exception as exc {
        r["err_rect_infphi"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_isclose_neg"] = "no-raise";
    try {
        isclose(complex(1.0, 0.0), complex(1.0, 0.0), rel_tol=-1.0);
    } except ValueError as exc {
        r["err_isclose_neg"] = "ValueError: " + str(exc);
    } except Exception as exc {
        r["err_isclose_neg"] = "WRONG-TYPE: " + str(exc);
    }
}

def cmath_py -> dict[str, any] {
    r: dict[str, any] = {};
    _fill_py(r);
    return r;
}

def cmath_cl -> dict[str, any] {
    return {};
}

def cmath_na -> dict[str, any] {
    r: dict[str, any] = {};
    _fill_na(r);
    return r;
}
