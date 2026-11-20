"""math module cross-backend equivalence fixture (issue #6404, Mechanism B).

The SAME `import from math { ... }` binds CPython's `math` on the sv
(Python) backend and the bundled `na_stdlib/math.jac` Mechanism-B module —
a pure-Jac surface over the `_math_native` libm FFI floor — on the na
(native LLVM) backend. Both must agree within ULP tolerance, including the
pinned exception type and message on the error paths: each is caught by the
expected class and stored as "<ClassName>: <str(e)>", with a WRONG-TYPE
fallback arm so a differently-typed raise shows up as a value mismatch
instead of an abort. The ES/JS backend opts out (returns {}) — this
roadmap targets sv↔na congruence.

Integer-result pins stay inside i64 range: CPython's bignum answers
(factorial(21), comb(67, 33), ...) overflow the native fixed-width int, so
they are intentionally absent. `inf`/`nan` constants are pinned through
predicates rather than by value — abs(inf - inf) is nan, which never
passes the float tolerance check even when both lanes agree.
"""

import from math {
    acos,
    acosh,
    asin,
    asinh,
    atan,
    atan2,
    atanh,
    cbrt,
    ceil,
    comb,
    copysign,
    cos,
    cosh,
    degrees,
    dist,
    e,
    erf,
    erfc,
    exp,
    exp2,
    expm1,
    fabs,
    factorial,
    floor,
    fma,
    fmod,
    frexp,
    fsum,
    gamma,
    gcd,
    hypot,
    inf,
    isclose,
    isfinite,
    isinf,
    isnan,
    isqrt,
    lcm,
    ldexp,
    lgamma,
    log,
    log10,
    log1p,
    log2,
    modf,
    nan,
    nextafter,
    perm,
    pi,
    pow,
    prod,
    radians,
    remainder,
    sin,
    sinh,
    sqrt,
    sumprod,
    tan,
    tanh,
    tau,
    trunc,
    ulp
}

import math;


def math_py -> dict[any, any] {
    fx = frexp(8.0);
    mf = modf(2.5);
    r: dict[any, any] = {
        # constants
        "pi": pi,
        "e": e,
        "tau": tau,
        "inf": 1 if (isinf(inf) and inf > 0.0) else 0,
        "nan": 1 if isnan(nan) else 0,
        # roots / powers
        "sqrt": sqrt(16.0),
        "attr_sqrt": math.sqrt(16.0),
        "attr_pi": math.pi,
        "cbrt": cbrt(27.0),
        "pow": pow(2.0, 10.0),
        # trig
        "sin": sin(1.0),
        "cos": cos(1.0),
        "tan": tan(1.0),
        "asin": asin(0.5),
        "acos": acos(0.5),
        "atan": atan(2.0),
        "atan2": atan2(1.0, 2.0),
        "hypot": hypot(3.0, 4.0),
        "hypot3": hypot(1.0, 2.0, 2.0),
        "hypot9": hypot(1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0),
        # hyperbolic
        "sinh": sinh(1.0),
        "cosh": cosh(1.0),
        "tanh": tanh(1.0),
        "asinh": asinh(1.0),
        "acosh": acosh(2.0),
        "atanh": atanh(0.5),
        # exp / log
        "exp": exp(2.0),
        "exp2": exp2(4.0),
        "expm1": expm1(0.5),
        "log": log(e),
        "log2": log2(8.0),
        "log10": log10(1000.0),
        "log1p": log1p(0.5),
        "logb": log(81.0, 3.0),
        # rounding (-> int)
        "floor": floor(2.7),
        "ceil": ceil(2.1),
        "trunc": trunc(-2.7),
        # integer results
        "factorial": factorial(10),
        "factorial_max_i64": factorial(20),
        "isqrt": isqrt(17),
        "isqrt_zero": isqrt(0),
        "gcd2": gcd(12, 18),
        "gcd3": gcd(12, 18, 24),
        "gcd9": gcd(12, 18, 24, 36, 48, 60, 72, 84, 90),
        "gcd0": gcd(),
        "gcd_neg": gcd(-12, 18),
        "lcm2": lcm(4, 6),
        "lcm3": lcm(4, 6, 8),
        "lcm0": lcm(),
        "comb": comb(10, 3),
        "perm1": perm(5),
        "perm2": perm(5, 2),
        "perm_kgt": perm(2, 5),
        # misc real
        "fabs": fabs(-3.5),
        "fmod": fmod(7.0, 3.0),
        "copysign": copysign(3.0, -1.0),
        "remainder": remainder(7.0, 3.0),
        "fma": fma(2.0, 3.0, 4.0),
        "degrees": degrees(pi),
        "radians": radians(180.0),
        # special
        "gamma": gamma(5.0),
        "lgamma": lgamma(5.0),
        "erf": erf(1.0),
        "erfc": erfc(1.0),
        # predicates
        "isnan_nan": isnan(nan),
        "isnan_one": isnan(1.0),
        "isinf_inf": isinf(inf),
        "isinf_one": isinf(1.0),
        "isfin_one": isfinite(1.0),
        "isfin_inf": isfinite(inf),
        # float-bit decomposition / recomposition
        "frexp_m": fx[0],
        "frexp_e": fx[1],
        "modf_f": mf[0],
        "modf_i": mf[1],
        "ldexp": ldexp(0.5, 4),
        "nextafter": nextafter(1.0, 2.0),
        "nextafter_steps": nextafter(1.0, 2.0, steps=3),
        "ulp": ulp(1.0),
        "ulp_zero": ulp(0.0),
        "isclose_t": isclose(1.0, 1.0000000001),
        "isclose_f": isclose(1.0, 1.1),
        "isclose_abs": isclose(1.0, 1.05, abs_tol=0.1),
        "isclose_rel": isclose(1.0, 1.1, rel_tol=0.1),
        # iterable arguments
        "prod": prod([2, 3, 4]),
        "prod_f": prod([1.5, 2.0]),
        "prod_start_f": prod([1, 2], start=0.5),
        "fsum": fsum([0.1, 0.2, 0.3]),
        "dist": dist([0.0, 0.0], [3.0, 4.0]),
        "sumprod": sumprod([1.0, 2.0], [3.0, 4.0]),

    };
    # error paths: pin "<ClassName>: <message>" per CPython 3.14
    r["err_sqrt_neg"] = "no-raise";
    try {
        sqrt(-1.0);
    } except ValueError as exc {
        r["err_sqrt_neg"] = "ValueError: " + str(exc);
    } except Exception as exc {
        r["err_sqrt_neg"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_log_zero"] = "no-raise";
    try {
        log(0.0);
    } except ValueError as exc {
        r["err_log_zero"] = "ValueError: " + str(exc);
    } except Exception as exc {
        r["err_log_zero"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_log_base0"] = "no-raise";
    try {
        log(4.0, 0.0);
    } except ValueError as exc {
        r["err_log_base0"] = "ValueError: " + str(exc);
    } except Exception as exc {
        r["err_log_base0"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_log_base1"] = "no-raise";
    try {
        log(4.0, 1.0);
    } except ZeroDivisionError as exc {
        r["err_log_base1"] = "ZeroDivisionError: " + str(exc);
    } except Exception as exc {
        r["err_log_base1"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_exp_over"] = "no-raise";
    try {
        exp(1000.0);
    } except OverflowError as exc {
        r["err_exp_over"] = "OverflowError: " + str(exc);
    } except Exception as exc {
        r["err_exp_over"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_gamma_zero"] = "no-raise";
    try {
        gamma(0.0);
    } except ValueError as exc {
        r["err_gamma_zero"] = "ValueError: " + str(exc);
    } except Exception as exc {
        r["err_gamma_zero"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_acos_dom"] = "no-raise";
    try {
        acos(2.0);
    } except ValueError as exc {
        r["err_acos_dom"] = "ValueError: " + str(exc);
    } except Exception as exc {
        r["err_acos_dom"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_factorial_neg"] = "no-raise";
    try {
        factorial(-1);
    } except ValueError as exc {
        r["err_factorial_neg"] = "ValueError: " + str(exc);
    } except Exception as exc {
        r["err_factorial_neg"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_isqrt_neg"] = "no-raise";
    try {
        isqrt(-1);
    } except ValueError as exc {
        r["err_isqrt_neg"] = "ValueError: " + str(exc);
    } except Exception as exc {
        r["err_isqrt_neg"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_comb_neg"] = "no-raise";
    try {
        comb(-1, 1);
    } except ValueError as exc {
        r["err_comb_neg"] = "ValueError: " + str(exc);
    } except Exception as exc {
        r["err_comb_neg"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_perm_negk"] = "no-raise";
    try {
        perm(5, -1);
    } except ValueError as exc {
        r["err_perm_negk"] = "ValueError: " + str(exc);
    } except Exception as exc {
        r["err_perm_negk"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_fmod_zero"] = "no-raise";
    try {
        fmod(1.0, 0.0);
    } except ValueError as exc {
        r["err_fmod_zero"] = "ValueError: " + str(exc);
    } except Exception as exc {
        r["err_fmod_zero"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_remainder_zero"] = "no-raise";
    try {
        remainder(1.0, 0.0);
    } except ValueError as exc {
        r["err_remainder_zero"] = "ValueError: " + str(exc);
    } except Exception as exc {
        r["err_remainder_zero"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_ldexp_over"] = "no-raise";
    try {
        ldexp(1.0, 99999);
    } except OverflowError as exc {
        r["err_ldexp_over"] = "OverflowError: " + str(exc);
    } except Exception as exc {
        r["err_ldexp_over"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_fsum_infs"] = "no-raise";
    try {
        fsum([inf, -inf]);
    } except ValueError as exc {
        r["err_fsum_infs"] = "ValueError: " + str(exc);
    } except Exception as exc {
        r["err_fsum_infs"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_isclose_tol"] = "no-raise";
    try {
        isclose(1.0, 1.0, rel_tol=-1.0);
    } except ValueError as exc {
        r["err_isclose_tol"] = "ValueError: " + str(exc);
    } except Exception as exc {
        r["err_isclose_tol"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_nextafter_steps"] = "no-raise";
    try {
        nextafter(1.0, 2.0, steps=-1);
    } except ValueError as exc {
        r["err_nextafter_steps"] = "ValueError: " + str(exc);
    } except Exception as exc {
        r["err_nextafter_steps"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_dist_len"] = "no-raise";
    try {
        dist([1.0, 2.0], [1.0, 2.0, 3.0]);
    } except ValueError as exc {
        r["err_dist_len"] = "ValueError: " + str(exc);
    } except Exception as exc {
        r["err_dist_len"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_sumprod_len"] = "no-raise";
    try {
        sumprod([1.0, 2.0], [1.0]);
    } except ValueError as exc {
        r["err_sumprod_len"] = "ValueError: " + str(exc);
    } except Exception as exc {
        r["err_sumprod_len"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_ceil_nan"] = "no-raise";
    try {
        ceil(nan);
    } except ValueError as exc {
        r["err_ceil_nan"] = "ValueError: " + str(exc);
    } except Exception as exc {
        r["err_ceil_nan"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_floor_inf"] = "no-raise";
    try {
        floor(inf);
    } except OverflowError as exc {
        r["err_floor_inf"] = "OverflowError: " + str(exc);
    } except Exception as exc {
        r["err_floor_inf"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_trunc_inf"] = "no-raise";
    try {
        trunc(inf);
    } except OverflowError as exc {
        r["err_trunc_inf"] = "OverflowError: " + str(exc);
    } except Exception as exc {
        r["err_trunc_inf"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_pow_zero_neg"] = "no-raise";
    try {
        pow(0.0, -1.0);
    } except ValueError as exc {
        r["err_pow_zero_neg"] = "ValueError: " + str(exc);
    } except Exception as exc {
        r["err_pow_zero_neg"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_fma_over"] = "no-raise";
    try {
        fma(1e308, 1e308, -1e308);
    } except OverflowError as exc {
        r["err_fma_over"] = "OverflowError: " + str(exc);
    } except Exception as exc {
        r["err_fma_over"] = "WRONG-TYPE: " + str(exc);
    }
    # result types are part of the contract: rounding returns int, not float
    r["floor_repr"] = str(floor(2.7));
    r["ceil_repr"] = str(ceil(-2.1));
    r["trunc_repr"] = str(trunc(-2.7));
    r["floor_expr_repr"] = str(floor(3.7) + 1);
    r["floor_int_exact"] = floor(9007199254740993);
    r["ceil_int_exact"] = ceil(-9007199254740993);
    # any iterable is accepted, not only list
    r["fsum_tuple"] = fsum((0.1, 0.2, 0.3));
    r["fsum_range"] = fsum(range(10));
    r["prod_range"] = prod(range(1, 8));
    r["prod_tuple"] = prod((1.5, 2.0));
    r["dist_tuple"] = dist((0.0, 0.0), (3.0, 4.0));
    r["dist_mixed"] = dist([1, 2, 3], (4.0, 6.0, 8.0));
    r["sumprod_range"] = sumprod((1, 2, 3), range(3));
    r["sumprod_mixed"] = sumprod([0.1, 0.2], (3, 4));
    # arity is not capped
    r["gcd_many"] = gcd(2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24);
    r["lcm_many"] = lcm(2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12);
    r["hypot_many"] = hypot(
        1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0
    );
    r["hypot_one"] = hypot(-3.5);
    r["gcd_none"] = gcd();
    r["lcm_none"] = lcm();
    # CPython's own Lanczos gamma/lgamma, away from the integer table
    r["gamma_frac"] = gamma(4.919272155929015);
    r["lgamma_neg"] = lgamma(-17.431905766684515);
    r["isqrt_max"] = isqrt(9223372036854775807);
    r["isqrt_edge"] = isqrt(9223372030926249000);
    return r;
}

def math_cl -> dict[any, any] {
    return {};
}


# --- native lane ----------------------------------------------------------
# Split into small helpers mutating one result dict: a single function
# carrying the whole case body exceeds what the na backend JITs reliably.
# These helpers intentionally mirror math_py: a shared body cannot serve both
# lanes (a pinned helper emits as an FFI shim on the Python side, and unpinned
# helpers are not pulled into the native closure), so each lane keeps its own
# pinned copy. Keep the bodies in sync -- key-set drift fails assert_full_parity.
def _core_na(r: dict[str, any]) {
    fx = frexp(8.0);
    mf = modf(2.5);
    # constants
    r["pi"] = pi;
    r["e"] = e;
    r["tau"] = tau;
    r["inf"] = 1 if (isinf(inf) and inf > 0.0) else 0;
    r["nan"] = 1 if isnan(nan) else 0;
    # roots / powers
    r["sqrt"] = sqrt(16.0);
    r["attr_sqrt"] = math.sqrt(16.0);
    r["attr_pi"] = math.pi;
    r["cbrt"] = cbrt(27.0);
    r["pow"] = pow(2.0, 10.0);
    # trig
    r["sin"] = sin(1.0);
    r["cos"] = cos(1.0);
    r["tan"] = tan(1.0);
    r["asin"] = asin(0.5);
    r["acos"] = acos(0.5);
    r["atan"] = atan(2.0);
    r["atan2"] = atan2(1.0, 2.0);
    r["hypot"] = hypot(3.0, 4.0);
    r["hypot3"] = hypot(1.0, 2.0, 2.0);
    r["hypot9"] = hypot(1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0);
    # hyperbolic
    r["sinh"] = sinh(1.0);
    r["cosh"] = cosh(1.0);
    r["tanh"] = tanh(1.0);
    r["asinh"] = asinh(1.0);
    r["acosh"] = acosh(2.0);
    r["atanh"] = atanh(0.5);
    # exp / log
    r["exp"] = exp(2.0);
    r["exp2"] = exp2(4.0);
    r["expm1"] = expm1(0.5);
    r["log"] = log(e);
    r["log2"] = log2(8.0);
    r["log10"] = log10(1000.0);
    r["log1p"] = log1p(0.5);
    r["logb"] = log(81.0, 3.0);
    # predicates
    r["isnan_nan"] = isnan(nan);
    r["isnan_one"] = isnan(1.0);
    r["isinf_inf"] = isinf(inf);
    r["isinf_one"] = isinf(1.0);
    r["isfin_one"] = isfinite(1.0);
    r["isfin_inf"] = isfinite(inf);
    # float-bit decomposition / recomposition
    r["frexp_m"] = fx[0];
    r["frexp_e"] = fx[1];
    r["modf_f"] = mf[0];
    r["modf_i"] = mf[1];
}

def _ints_na(r: dict[str, any]) {
    # rounding (-> int)
    r["floor"] = floor(2.7);
    r["ceil"] = ceil(2.1);
    r["trunc"] = trunc(-2.7);
    # integer results (all inside i64)
    r["factorial"] = factorial(10);
    r["factorial_max_i64"] = factorial(20);
    r["isqrt"] = isqrt(17);
    r["isqrt_zero"] = isqrt(0);
    r["gcd2"] = gcd(12, 18);
    r["gcd3"] = gcd(12, 18, 24);
    r["gcd9"] = gcd(12, 18, 24, 36, 48, 60, 72, 84, 90);
    r["gcd0"] = gcd();
    r["gcd_neg"] = gcd(-12, 18);
    r["lcm2"] = lcm(4, 6);
    r["lcm3"] = lcm(4, 6, 8);
    r["lcm0"] = lcm();
    r["comb"] = comb(10, 3);
    r["perm1"] = perm(5);
    r["perm2"] = perm(5, 2);
    r["perm_kgt"] = perm(2, 5);
}

def _misc_na(r: dict[str, any]) {
    # misc real
    r["fabs"] = fabs(-3.5);
    r["fmod"] = fmod(7.0, 3.0);
    r["copysign"] = copysign(3.0, -1.0);
    r["remainder"] = remainder(7.0, 3.0);
    r["fma"] = fma(2.0, 3.0, 4.0);
    r["degrees"] = degrees(pi);
    r["radians"] = radians(180.0);
    # special
    r["gamma"] = gamma(5.0);
    r["lgamma"] = lgamma(5.0);
    r["erf"] = erf(1.0);
    r["erfc"] = erfc(1.0);
    # float bits
    r["ldexp"] = ldexp(0.5, 4);
    r["nextafter"] = nextafter(1.0, 2.0);
    r["nextafter_steps"] = nextafter(1.0, 2.0, steps=3);
    r["ulp"] = ulp(1.0);
    r["ulp_zero"] = ulp(0.0);
    r["isclose_t"] = isclose(1.0, 1.0000000001);
    r["isclose_f"] = isclose(1.0, 1.1);
    r["isclose_abs"] = isclose(1.0, 1.05, abs_tol=0.1);
    r["isclose_rel"] = isclose(1.0, 1.1, rel_tol=0.1);
    # iterable arguments
    r["prod"] = prod([2, 3, 4]);
    r["prod_f"] = prod([1.5, 2.0]);
    r["prod_start_f"] = prod([1, 2], start=0.5);
    r["fsum"] = fsum([0.1, 0.2, 0.3]);
    r["dist"] = dist([0.0, 0.0], [3.0, 4.0]);
    r["sumprod"] = sumprod([1.0, 2.0], [3.0, 4.0]);
}

def _errs_a_na(r: dict[str, any]) {
    r["err_sqrt_neg"] = "no-raise";
    try {
        sqrt(-1.0);
    } except ValueError as exc {
        r["err_sqrt_neg"] = "ValueError: " + str(exc);
    } except Exception as exc {
        r["err_sqrt_neg"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_log_zero"] = "no-raise";
    try {
        log(0.0);
    } except ValueError as exc {
        r["err_log_zero"] = "ValueError: " + str(exc);
    } except Exception as exc {
        r["err_log_zero"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_log_base0"] = "no-raise";
    try {
        log(4.0, 0.0);
    } except ValueError as exc {
        r["err_log_base0"] = "ValueError: " + str(exc);
    } except Exception as exc {
        r["err_log_base0"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_log_base1"] = "no-raise";
    try {
        log(4.0, 1.0);
    } except ZeroDivisionError as exc {
        r["err_log_base1"] = "ZeroDivisionError: " + str(exc);
    } except Exception as exc {
        r["err_log_base1"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_exp_over"] = "no-raise";
    try {
        exp(1000.0);
    } except OverflowError as exc {
        r["err_exp_over"] = "OverflowError: " + str(exc);
    } except Exception as exc {
        r["err_exp_over"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_gamma_zero"] = "no-raise";
    try {
        gamma(0.0);
    } except ValueError as exc {
        r["err_gamma_zero"] = "ValueError: " + str(exc);
    } except Exception as exc {
        r["err_gamma_zero"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_acos_dom"] = "no-raise";
    try {
        acos(2.0);
    } except ValueError as exc {
        r["err_acos_dom"] = "ValueError: " + str(exc);
    } except Exception as exc {
        r["err_acos_dom"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_factorial_neg"] = "no-raise";
    try {
        factorial(-1);
    } except ValueError as exc {
        r["err_factorial_neg"] = "ValueError: " + str(exc);
    } except Exception as exc {
        r["err_factorial_neg"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_isqrt_neg"] = "no-raise";
    try {
        isqrt(-1);
    } except ValueError as exc {
        r["err_isqrt_neg"] = "ValueError: " + str(exc);
    } except Exception as exc {
        r["err_isqrt_neg"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_comb_neg"] = "no-raise";
    try {
        comb(-1, 1);
    } except ValueError as exc {
        r["err_comb_neg"] = "ValueError: " + str(exc);
    } except Exception as exc {
        r["err_comb_neg"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_perm_negk"] = "no-raise";
    try {
        perm(5, -1);
    } except ValueError as exc {
        r["err_perm_negk"] = "ValueError: " + str(exc);
    } except Exception as exc {
        r["err_perm_negk"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_fmod_zero"] = "no-raise";
    try {
        fmod(1.0, 0.0);
    } except ValueError as exc {
        r["err_fmod_zero"] = "ValueError: " + str(exc);
    } except Exception as exc {
        r["err_fmod_zero"] = "WRONG-TYPE: " + str(exc);
    }
}

def _errs_b_na(r: dict[str, any]) {
    r["err_remainder_zero"] = "no-raise";
    try {
        remainder(1.0, 0.0);
    } except ValueError as exc {
        r["err_remainder_zero"] = "ValueError: " + str(exc);
    } except Exception as exc {
        r["err_remainder_zero"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_ldexp_over"] = "no-raise";
    try {
        ldexp(1.0, 99999);
    } except OverflowError as exc {
        r["err_ldexp_over"] = "OverflowError: " + str(exc);
    } except Exception as exc {
        r["err_ldexp_over"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_fsum_infs"] = "no-raise";
    try {
        fsum([inf, -inf]);
    } except ValueError as exc {
        r["err_fsum_infs"] = "ValueError: " + str(exc);
    } except Exception as exc {
        r["err_fsum_infs"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_isclose_tol"] = "no-raise";
    try {
        isclose(1.0, 1.0, rel_tol=-1.0);
    } except ValueError as exc {
        r["err_isclose_tol"] = "ValueError: " + str(exc);
    } except Exception as exc {
        r["err_isclose_tol"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_nextafter_steps"] = "no-raise";
    try {
        nextafter(1.0, 2.0, steps=-1);
    } except ValueError as exc {
        r["err_nextafter_steps"] = "ValueError: " + str(exc);
    } except Exception as exc {
        r["err_nextafter_steps"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_dist_len"] = "no-raise";
    try {
        dist([1.0, 2.0], [1.0, 2.0, 3.0]);
    } except ValueError as exc {
        r["err_dist_len"] = "ValueError: " + str(exc);
    } except Exception as exc {
        r["err_dist_len"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_sumprod_len"] = "no-raise";
    try {
        sumprod([1.0, 2.0], [1.0]);
    } except ValueError as exc {
        r["err_sumprod_len"] = "ValueError: " + str(exc);
    } except Exception as exc {
        r["err_sumprod_len"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_ceil_nan"] = "no-raise";
    try {
        ceil(nan);
    } except ValueError as exc {
        r["err_ceil_nan"] = "ValueError: " + str(exc);
    } except Exception as exc {
        r["err_ceil_nan"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_floor_inf"] = "no-raise";
    try {
        floor(inf);
    } except OverflowError as exc {
        r["err_floor_inf"] = "OverflowError: " + str(exc);
    } except Exception as exc {
        r["err_floor_inf"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_trunc_inf"] = "no-raise";
    try {
        trunc(inf);
    } except OverflowError as exc {
        r["err_trunc_inf"] = "OverflowError: " + str(exc);
    } except Exception as exc {
        r["err_trunc_inf"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_pow_zero_neg"] = "no-raise";
    try {
        pow(0.0, -1.0);
    } except ValueError as exc {
        r["err_pow_zero_neg"] = "ValueError: " + str(exc);
    } except Exception as exc {
        r["err_pow_zero_neg"] = "WRONG-TYPE: " + str(exc);
    }
    r["err_fma_over"] = "no-raise";
    try {
        fma(1e308, 1e308, -1e308);
    } except OverflowError as exc {
        r["err_fma_over"] = "OverflowError: " + str(exc);
    } except Exception as exc {
        r["err_fma_over"] = "WRONG-TYPE: " + str(exc);
    }
}

def _congruence_na(r: dict[str, any]) {
    # result types are part of the contract: rounding returns int, not float
    r["floor_repr"] = str(floor(2.7));
    r["ceil_repr"] = str(ceil(-2.1));
    r["trunc_repr"] = str(trunc(-2.7));
    r["floor_expr_repr"] = str(floor(3.7) + 1);
    r["floor_int_exact"] = floor(9007199254740993);
    r["ceil_int_exact"] = ceil(-9007199254740993);
    # any iterable is accepted, not only list
    r["fsum_tuple"] = fsum((0.1, 0.2, 0.3));
    r["fsum_range"] = fsum(range(10));
    r["prod_range"] = prod(range(1, 8));
    r["prod_tuple"] = prod((1.5, 2.0));
    r["dist_tuple"] = dist((0.0, 0.0), (3.0, 4.0));
    r["dist_mixed"] = dist([1, 2, 3], (4.0, 6.0, 8.0));
    r["sumprod_range"] = sumprod((1, 2, 3), range(3));
    r["sumprod_mixed"] = sumprod([0.1, 0.2], (3, 4));
    # arity is not capped
    r["gcd_many"] = gcd(2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24);
    r["lcm_many"] = lcm(2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12);
    r["hypot_many"] = hypot(
        1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0
    );
    r["hypot_one"] = hypot(-3.5);
    r["gcd_none"] = gcd();
    r["lcm_none"] = lcm();
    # CPython's own Lanczos gamma/lgamma, away from the integer table
    r["gamma_frac"] = gamma(4.919272155929015);
    r["lgamma_neg"] = lgamma(-17.431905766684515);
    r["isqrt_max"] = isqrt(9223372036854775807);
    r["isqrt_edge"] = isqrt(9223372030926249000);
}

def math_na -> dict[str, any] {
    r: dict[str, any] = {};
    _core_na(r);
    _ints_na(r);
    _misc_na(r);
    _errs_a_na(r);
    _errs_b_na(r);
    _congruence_na(r);
    return r;
}
