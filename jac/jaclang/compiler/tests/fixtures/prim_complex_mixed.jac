"""Mixed complex-scalar operator equivalence fixture.

CPython promotes a numeric operand against `complex` through the reflected
slot ((1+2j) + 1, 3 - 1j, ...); the native backend lowers the same shape by
boxing the scalar operand into a complex first. ES/JS has no comparable
lowering and opts out (returns {}).
"""

obj CBox {
    has f: complex = complex(0, 0);
}

def cmixed_py -> dict[any, any] {
    c1 = complex(3, 4);
    c2 = complex(3, 4);
    c2 += 1;
    box_add = CBox();
    box_add.f = complex(1, 1);
    box_add.f += 2;
    box_mul = CBox();
    box_mul.f = complex(1, 1);
    box_mul.f *= 3;
    box_pow = CBox();
    box_pow.f = complex(1, 1);
    box_pow.f **= 2;
    box_div = CBox();
    box_div.f = complex(1, 1);
    box_div.f /= 2;
    r: dict[any, any] = {
        "add_scalar": (c1 + 1) == complex(4, 4),
        "sub_scalar": (c1 - 2) == complex(1, 4),
        "mul_scalar": (c1 * 2) == complex(6, 8),
        "div_scalar": (c1 / 2) == complex(1.5, 2),
        "scalar_add": (1 + c1) == complex(4, 4),
        "scalar_sub": (10 - c1) == complex(7, -4),
        "scalar_mul": (2 * c1) == complex(6, 8),
        "scalar_div": (complex(6, 8) / 2) == complex(3, 4),
        "aug_add": c2 == complex(4, 4),
        "pow_scalar": (c1 ** 2) == complex(-7, 24),
        "aug_field_add": box_add.f == complex(3, 1),
        "aug_field_mul": box_mul.f == complex(3, 3),
        "aug_field_pow": box_pow.f == complex(0, 2),
        "aug_field_div": box_div.f == complex(0.5, 0.5)
    };
    inf = float("inf");
    nan = float("nan");
    r["radd_keeps_neg_zero"] = str((1.0 + complex(1.0, -0.0)).imag);
    r["add_keeps_neg_zero"] = str((complex(1.0, -0.0) + 2).imag);
    r["rsub_negates_imag"] = str((1.0 - complex(0.0, 0.0)).imag);
    r["sub_keeps_neg_zero"] = str((complex(1.0, -0.0) - 1.0).imag);
    r["mul_real_inf"] = str((complex(inf, 1.0) * 2.0).imag);
    r["rmul_real_inf"] = str((2.0 * complex(1.0, inf)).real);
    r["div_real_inf"] = str((complex(inf, 1.0) / 2.0).imag);
    z_rdiv = 3.0 / complex(2.0, 1.0);
    r["rdiv"] = str(z_rdiv.real) + " " + str(z_rdiv.imag);
    r["rdiv_inf"] = str((3.0 / complex(inf, 1.0)).imag);
    r["prod_recovers_inf"] = str((complex(inf, nan) * complex(1.0, 1.0)).imag);
    r["quot_recovers_inf"] = str((complex(inf, nan) / complex(1.0, 1.0)).imag);
    z_quot_by_inf = complex(1.0, 1.0) / complex(inf, inf);
    r["quot_by_inf"] = str(z_quot_by_inf.real) + " " + str(z_quot_by_inf.imag);
    z_pow_neg_int = complex(1.0, 2.0) ** -2;
    r["pow_neg_int"] = str(z_pow_neg_int.real) + " " + str(z_pow_neg_int.imag);
    r["div_zero_cc"] = "no-raise";
    try {
        complex(1.0, 1.0) / complex(0.0, 0.0);
    } except ZeroDivisionError as exc {
        r["div_zero_cc"] = "ZeroDivisionError: " + str(exc);
    }
    r["div_zero_cr"] = "no-raise";
    try {
        complex(1.0, 1.0) / 0.0;
    } except ZeroDivisionError as exc {
        r["div_zero_cr"] = "ZeroDivisionError: " + str(exc);
    }
    r["div_zero_rc"] = "no-raise";
    try {
        1.0 / complex(0.0, 0.0);
    } except ZeroDivisionError as exc {
        r["div_zero_rc"] = "ZeroDivisionError: " + str(exc);
    }
    r["pow_overflow"] = "no-raise";
    try {
        complex(0.0, 1e300) ** 2;
    } except OverflowError as exc {
        r["pow_overflow"] = "OverflowError: " + str(exc);
    }
    r["pow_zero_neg"] = "no-raise";
    try {
        complex(0.0, 0.0) ** -1;
    } except ZeroDivisionError as exc {
        r["pow_zero_neg"] = "ZeroDivisionError: " + str(exc);
    }
    return r;
}

def cmixed_cl -> dict[any, any] {
    return {};
}

def cmixed_na -> dict[str, any] {
    c1 = complex(3, 4);
    c2 = complex(3, 4);
    c2 += 1;
    box_add = CBox();
    box_add.f = complex(1, 1);
    box_add.f += 2;
    box_mul = CBox();
    box_mul.f = complex(1, 1);
    box_mul.f *= 3;
    box_pow = CBox();
    box_pow.f = complex(1, 1);
    box_pow.f **= 2;
    box_div = CBox();
    box_div.f = complex(1, 1);
    box_div.f /= 2;
    r: dict[str, any] = {
        "add_scalar": (c1 + 1) == complex(4, 4),
        "sub_scalar": (c1 - 2) == complex(1, 4),
        "mul_scalar": (c1 * 2) == complex(6, 8),
        "div_scalar": (c1 / 2) == complex(1.5, 2),
        "scalar_add": (1 + c1) == complex(4, 4),
        "scalar_sub": (10 - c1) == complex(7, -4),
        "scalar_mul": (2 * c1) == complex(6, 8),
        "scalar_div": (complex(6, 8) / 2) == complex(3, 4),
        "aug_add": c2 == complex(4, 4),
        "pow_scalar": (c1 ** 2) == complex(-7, 24),
        "aug_field_add": box_add.f == complex(3, 1),
        "aug_field_mul": box_mul.f == complex(3, 3),
        "aug_field_pow": box_pow.f == complex(0, 2),
        "aug_field_div": box_div.f == complex(0.5, 0.5)
    };
    inf = float("inf");
    nan = float("nan");
    r["radd_keeps_neg_zero"] = str((1.0 + complex(1.0, -0.0)).imag);
    r["add_keeps_neg_zero"] = str((complex(1.0, -0.0) + 2).imag);
    r["rsub_negates_imag"] = str((1.0 - complex(0.0, 0.0)).imag);
    r["sub_keeps_neg_zero"] = str((complex(1.0, -0.0) - 1.0).imag);
    r["mul_real_inf"] = str((complex(inf, 1.0) * 2.0).imag);
    r["rmul_real_inf"] = str((2.0 * complex(1.0, inf)).real);
    r["div_real_inf"] = str((complex(inf, 1.0) / 2.0).imag);
    z_rdiv = 3.0 / complex(2.0, 1.0);
    r["rdiv"] = str(z_rdiv.real) + " " + str(z_rdiv.imag);
    r["rdiv_inf"] = str((3.0 / complex(inf, 1.0)).imag);
    r["prod_recovers_inf"] = str((complex(inf, nan) * complex(1.0, 1.0)).imag);
    r["quot_recovers_inf"] = str((complex(inf, nan) / complex(1.0, 1.0)).imag);
    z_quot_by_inf = complex(1.0, 1.0) / complex(inf, inf);
    r["quot_by_inf"] = str(z_quot_by_inf.real) + " " + str(z_quot_by_inf.imag);
    z_pow_neg_int = complex(1.0, 2.0) ** -2;
    r["pow_neg_int"] = str(z_pow_neg_int.real) + " " + str(z_pow_neg_int.imag);
    r["div_zero_cc"] = "no-raise";
    try {
        complex(1.0, 1.0) / complex(0.0, 0.0);
    } except ZeroDivisionError as exc {
        r["div_zero_cc"] = "ZeroDivisionError: " + str(exc);
    }
    r["div_zero_cr"] = "no-raise";
    try {
        complex(1.0, 1.0) / 0.0;
    } except ZeroDivisionError as exc {
        r["div_zero_cr"] = "ZeroDivisionError: " + str(exc);
    }
    r["div_zero_rc"] = "no-raise";
    try {
        1.0 / complex(0.0, 0.0);
    } except ZeroDivisionError as exc {
        r["div_zero_rc"] = "ZeroDivisionError: " + str(exc);
    }
    r["pow_overflow"] = "no-raise";
    try {
        complex(0.0, 1e300) ** 2;
    } except OverflowError as exc {
        r["pow_overflow"] = "OverflowError: " + str(exc);
    }
    r["pow_zero_neg"] = "no-raise";
    try {
        complex(0.0, 0.0) ** -1;
    } except ZeroDivisionError as exc {
        r["pow_zero_neg"] = "ZeroDivisionError: " + str(exc);
    }
    return r;
}
