"""Float emitter: operators, named methods, comparisons.

Cross-backend equivalence fixture.
"""

# --- Float operators and methods ---
def float_py() -> dict {
    x: float = 3.0;
    y: float = 3.5;
    a: float = 7.5;
    b: float = 2.5;
    cmp_x: float = 3.5;
    cmp_y: float = 1.2;
    cmp_z: float = 3.5;

    is_int_yes: bool = x.is_integer();
    is_int_no: bool = y.is_integer();
    conj: float = x.conjugate();
    fdiv: float = a // b;
    fdiv_neg: float = (-7.5) // 2.5;
    pw: float = 2.0 ** 10.0;
    pw_frac: float = 4.0 ** 0.5;

    eq_t: bool = 3.0 == 3.0;
    eq_f: bool = 3.0 == 4.0;
    ne_t: bool = 3.0 != 4.0;
    ne_f: bool = 3.0 != 3.0;
    lt_t: bool = 2.0 < 3.0;
    lt_f: bool = 3.0 < 3.0;
    gt_t: bool = 4.0 > 3.0;
    gt_f: bool = 3.0 > 3.0;
    le_t: bool = 3.0 <= 3.0;
    le_f: bool = 4.0 <= 3.0;
    ge_t: bool = 3.0 >= 3.0;
    ge_f: bool = 2.0 >= 3.0;

    neg_val: float = -a;
    pos_val: float = +a;

    return {
        # is_integer, conjugate
        "is_int_yes": is_int_yes, "is_int_no": is_int_no,
        "conj": conj,
        # floor division, pow
        "fdiv": fdiv, "fdiv_neg": fdiv_neg,
        "pw": pw, "pw_frac": pw_frac,
        # comparisons
        "eq_t": eq_t, "eq_f": eq_f,
        "ne_t": ne_t, "ne_f": ne_f,
        "lt_t": lt_t, "lt_f": lt_f,
        "gt_t": gt_t, "gt_f": gt_f,
        "le_t": le_t, "le_f": le_f,
        "ge_t": ge_t, "ge_f": ge_f,
        # unary
        "neg_val": neg_val, "pos_val": pos_val,
        # is_integer variants
        "isint_whole": 1 if (3.0).is_integer() else 0,
        "isint_frac": 1 if (3.5).is_integer() else 0,
        "isint_zero": 1 if (0.0).is_integer() else 0,
        "isint_neg_whole": 1 if (-4.0).is_integer() else 0,
        "isint_neg_frac": 1 if (-4.5).is_integer() else 0,
        # conjugate variants
        "conjugate_pos": (3.14).conjugate(),
        "conjugate_neg": (-2.5).conjugate(),
        "conjugate_zero": (0.0).conjugate(),
        # floordiv variants
        "floordiv_pos": 7.0 // 2.0,
        "floordiv_neg": -7.0 // 2.0,
        "floordiv_exact": 6.0 // 3.0,
        "floordiv_small": 1.0 // 3.0,
        "floordiv_neg2": 7.0 // -2.0,
        # float_cmp tests
        "lt_true": 1 if cmp_y < cmp_x else 0,
        "lt_false": 1 if cmp_x < cmp_y else 0,
        "gt_true": 1 if cmp_x > cmp_y else 0,
        "gt_false": 1 if cmp_y > cmp_x else 0,
        "le_true": 1 if cmp_y <= cmp_x else 0,
        "le_equal": 1 if cmp_x <= cmp_z else 0,
        "le_false": 1 if cmp_x <= cmp_y else 0,
        "ge_true": 1 if cmp_x >= cmp_y else 0,
        "ge_equal": 1 if cmp_x >= cmp_z else 0,
        "ge_false": 1 if cmp_y >= cmp_x else 0,
        "eq_true": 1 if cmp_x == cmp_z else 0,
        "eq_false": 1 if cmp_x == cmp_y else 0,
        "ne_true": 1 if cmp_x != cmp_y else 0,
        "ne_false": 1 if cmp_x != cmp_z else 0,
        "neg_pos": 0.0 - cmp_x,
        "neg_neg": 0.0 - (0.0 - cmp_x),
        "mod": 7.5 % 2.0,
        "pow_float": 2.0 ** 3.0,
        "abs_neg_float": abs(-3.14),
        "abs_pos_float": abs(3.14),
        "min_float": min(3.5, 1.2),
        "max_float": max(3.5, 1.2),
        # as_integer_ratio (emit_as_integer_ratio)
        "air_3": list((3.0).as_integer_ratio()),
        "air_half": list((0.5).as_integer_ratio()),
        "air_neg": list((-2.0).as_integer_ratio()),
        "air_3_0": list((3.0).as_integer_ratio())[0],
        "air_3_1": list((3.0).as_integer_ratio())[1],
        "air_half_0": list((0.5).as_integer_ratio())[0],
        "air_half_1": list((0.5).as_integer_ratio())[1],
        "air_neg_0": list((-2.0).as_integer_ratio())[0],
        "air_neg_1": list((-2.0).as_integer_ratio())[1],
        # hex/fromhex (emit_hex / emit_fromhex) — SV/Python only
        "hex_1_5": (1.5).hex(),
        "hex_3_5": (3.5).hex(),
        "fromhex_1_5": float.fromhex("0x1.8p+0"),
        "fromhex_1_0": float.fromhex("0x1.0p+0")
    };
}

cl def float_cl() -> dict {
    x: float = 3.0;
    y: float = 3.5;
    a: float = 7.5;
    b: float = 2.5;
    cmp_x: float = 3.5;
    cmp_y: float = 1.2;
    cmp_z: float = 3.5;

    is_int_yes: bool = x.is_integer();
    is_int_no: bool = y.is_integer();
    conj: float = x.conjugate();
    fdiv: float = a // b;
    fdiv_neg: float = (-7.5) // 2.5;
    pw: float = 2.0 ** 10.0;
    pw_frac: float = 4.0 ** 0.5;

    eq_t: bool = 3.0 == 3.0;
    eq_f: bool = 3.0 == 4.0;
    ne_t: bool = 3.0 != 4.0;
    ne_f: bool = 3.0 != 3.0;
    lt_t: bool = 2.0 < 3.0;
    lt_f: bool = 3.0 < 3.0;
    gt_t: bool = 4.0 > 3.0;
    gt_f: bool = 3.0 > 3.0;
    le_t: bool = 3.0 <= 3.0;
    le_f: bool = 4.0 <= 3.0;
    ge_t: bool = 3.0 >= 3.0;
    ge_f: bool = 2.0 >= 3.0;

    neg_val: float = -a;
    pos_val: float = +a;

    return {
        "is_int_yes": is_int_yes, "is_int_no": is_int_no,
        "conj": conj,
        "fdiv": fdiv, "fdiv_neg": fdiv_neg,
        "pw": pw, "pw_frac": pw_frac,
        "eq_t": eq_t, "eq_f": eq_f,
        "ne_t": ne_t, "ne_f": ne_f,
        "lt_t": lt_t, "lt_f": lt_f,
        "gt_t": gt_t, "gt_f": gt_f,
        "le_t": le_t, "le_f": le_f,
        "ge_t": ge_t, "ge_f": ge_f,
        "neg_val": neg_val, "pos_val": pos_val,
        "isint_whole": 1 if (3.0).is_integer() else 0,
        "isint_frac": 1 if (3.5).is_integer() else 0,
        "isint_zero": 1 if (0.0).is_integer() else 0,
        "isint_neg_whole": 1 if (-4.0).is_integer() else 0,
        "isint_neg_frac": 1 if (-4.5).is_integer() else 0,
        "conjugate_pos": (3.14).conjugate(),
        "conjugate_neg": (-2.5).conjugate(),
        "conjugate_zero": (0.0).conjugate(),
        "floordiv_pos": 7.0 // 2.0,
        "floordiv_neg": -7.0 // 2.0,
        "floordiv_exact": 6.0 // 3.0,
        "floordiv_small": 1.0 // 3.0,
        "floordiv_neg2": 7.0 // -2.0,
        "lt_true": 1 if cmp_y < cmp_x else 0,
        "lt_false": 1 if cmp_x < cmp_y else 0,
        "gt_true": 1 if cmp_x > cmp_y else 0,
        "gt_false": 1 if cmp_y > cmp_x else 0,
        "le_true": 1 if cmp_y <= cmp_x else 0,
        "le_equal": 1 if cmp_x <= cmp_z else 0,
        "le_false": 1 if cmp_x <= cmp_y else 0,
        "ge_true": 1 if cmp_x >= cmp_y else 0,
        "ge_equal": 1 if cmp_x >= cmp_z else 0,
        "ge_false": 1 if cmp_y >= cmp_x else 0,
        "eq_true": 1 if cmp_x == cmp_z else 0,
        "eq_false": 1 if cmp_x == cmp_y else 0,
        "ne_true": 1 if cmp_x != cmp_y else 0,
        "ne_false": 1 if cmp_x != cmp_z else 0,
        "neg_pos": 0.0 - cmp_x,
        "neg_neg": 0.0 - (0.0 - cmp_x),
        "mod": 7.5 % 2.0,
        "pow_float": 2.0 ** 3.0,
        "abs_neg_float": abs(-3.14),
        "abs_pos_float": abs(3.14),
        "min_float": min(3.5, 1.2),
        "max_float": max(3.5, 1.2)
    };
}

na {
    def float_na() -> dict[str, any] {
        a: float = 7.5;
        b: float = 2.5;
        cmp_x: float = 3.5;
        cmp_y: float = 1.2;
        cmp_z: float = 3.5;

        fdiv: float = a // b;
        fdiv_neg: float = (-7.5) // 2.5;
        pw: float = 2.0 ** 10.0;
        pw_frac: float = 4.0 ** 0.5;

        eq_t: int = 1 if 3.0 == 3.0 else 0;
        eq_f: int = 1 if 3.0 == 4.0 else 0;
        ne_t: int = 1 if 3.0 != 4.0 else 0;
        ne_f: int = 1 if 3.0 != 3.0 else 0;
        lt_t: int = 1 if 2.0 < 3.0 else 0;
        lt_f: int = 1 if 3.0 < 3.0 else 0;
        gt_t: int = 1 if 4.0 > 3.0 else 0;
        gt_f: int = 1 if 3.0 > 3.0 else 0;
        le_t: int = 1 if 3.0 <= 3.0 else 0;
        le_f: int = 1 if 4.0 <= 3.0 else 0;
        ge_t: int = 1 if 3.0 >= 3.0 else 0;
        ge_f: int = 1 if 2.0 >= 3.0 else 0;

        neg_val: float = -a;
        pos_val: float = +a;

        return {
            "fdiv": fdiv, "fdiv_neg": fdiv_neg,
            "pw": pw, "pw_frac": pw_frac,
            "eq_t": eq_t, "eq_f": eq_f,
            "ne_t": ne_t, "ne_f": ne_f,
            "lt_t": lt_t, "lt_f": lt_f,
            "gt_t": gt_t, "gt_f": gt_f,
            "le_t": le_t, "le_f": le_f,
            "ge_t": ge_t, "ge_f": ge_f,
            "neg_val": neg_val, "pos_val": pos_val,
            "isint_whole": 1 if (3.0).is_integer() else 0,
            "isint_frac": 1 if (3.5).is_integer() else 0,
            "isint_zero": 1 if (0.0).is_integer() else 0,
            "isint_neg_whole": 1 if (-4.0).is_integer() else 0,
            "isint_neg_frac": 1 if (-4.5).is_integer() else 0,
            "conjugate_pos": (3.14).conjugate(),
            "conjugate_neg": (-2.5).conjugate(),
            "conjugate_zero": (0.0).conjugate(),
            "floordiv_pos": 7.0 // 2.0,
            "floordiv_neg": -7.0 // 2.0,
            "floordiv_exact": 6.0 // 3.0,
            "floordiv_small": 1.0 // 3.0,
            "floordiv_neg2": 7.0 // -2.0,
            "lt_true": 1 if cmp_y < cmp_x else 0,
            "lt_false": 1 if cmp_x < cmp_y else 0,
            "gt_true": 1 if cmp_x > cmp_y else 0,
            "gt_false": 1 if cmp_y > cmp_x else 0,
            "le_true": 1 if cmp_y <= cmp_x else 0,
            "le_equal": 1 if cmp_x <= cmp_z else 0,
            "le_false": 1 if cmp_x <= cmp_y else 0,
            "ge_true": 1 if cmp_x >= cmp_y else 0,
            "ge_equal": 1 if cmp_x >= cmp_z else 0,
            "ge_false": 1 if cmp_y >= cmp_x else 0,
            "eq_true": 1 if cmp_x == cmp_z else 0,
            "eq_false": 1 if cmp_x == cmp_y else 0,
            "ne_true": 1 if cmp_x != cmp_y else 0,
            "ne_false": 1 if cmp_x != cmp_z else 0,
            "neg_pos": 0.0 - cmp_x,
            "neg_neg": 0.0 - (0.0 - cmp_x),
            "mod": 7.5 % 2.0,
            "pow_float": 2.0 ** 3.0,
            "abs_neg_float": abs(-3.14),
            "abs_pos_float": abs(3.14),
            "min_float": min(3.5, 1.2),
            "max_float": max(3.5, 1.2),
            "air_3_0": (3.0).as_integer_ratio()[0],
            "air_3_1": (3.0).as_integer_ratio()[1],
            "air_half_0": (0.5).as_integer_ratio()[0],
            "air_half_1": (0.5).as_integer_ratio()[1],
            "air_neg_0": (-2.0).as_integer_ratio()[0],
            "air_neg_1": (-2.0).as_integer_ratio()[1],
            # fromhex (static method)
            "fromhex_1_5": float.fromhex("0x1.8p+0"),
            "fromhex_1_0": float.fromhex("0x1.0p+0")
        };
    }
}
