"""Float operator and method primitives not covered by prim_numeric.

Covers: is_integer, conjugate, floordiv, pow, all comparisons, neg, pos.
(hex/fromhex skipped — JS runtime uses toString(16)/parseFloat, not Python IEEE-754 hex format.)
"""

def float_ops_py() -> dict {
    x: float = 3.0;
    y: float = 3.5;
    a: float = 7.5;
    b: float = 2.5;

    # is_integer
    is_int_yes: bool = x.is_integer();
    is_int_no: bool = y.is_integer();

    # conjugate (identity for reals)
    conj: float = x.conjugate();

    # floordiv
    fdiv: float = a // b;
    fdiv_neg: float = (-7.5) // 2.5;

    # pow
    pw: float = 2.0 ** 10.0;
    pw_frac: float = 4.0 ** 0.5;

    # comparisons
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

    # unary
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
        "neg_val": neg_val, "pos_val": pos_val
    };
}

cl def float_ops_cl() -> dict {
    x: float = 3.0;
    y: float = 3.5;
    a: float = 7.5;
    b: float = 2.5;

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
        "neg_val": neg_val, "pos_val": pos_val
    };
}
