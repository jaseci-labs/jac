"""Tuple emitter: concatenation, in, not in, count, index, comparisons.

Cross-backend equivalence fixture.
"""

# --- Tuple operators and methods ---
def tuple_py() -> dict {
    # From containers: tuple concat, in, not in
    t: tuple = (10, 20);
    tuple_concat: list = list(t + (30,));
    tuple_in: bool = 10 in t;
    tuple_nin: bool = 99 not in t;

    # From jac_rt_tuple: count, index, repeat, comparisons
    t2: tuple = (1, 2, 3, 2, 1);
    cnt: int = t2.count(2);
    idx: int = t2.index(3);

    t3: tuple = (1, 2);
    repeated: list = list(t3 * 3);

    a: tuple = (1, 2, 3);
    b: tuple = (1, 2, 3);
    c: tuple = (1, 2, 4);
    d: tuple = (1, 2);
    eq_t: bool = a == b;
    eq_f: bool = a == c;
    lt_t: bool = a < c;
    gt_t: bool = c > a;
    le_t: bool = a <= b;
    ge_t: bool = c >= a;
    lt_len: bool = d < a;

    return {
        "tuple_concat": tuple_concat,
        "tuple_in": tuple_in,
        "tuple_nin": tuple_nin,
        "count": cnt,
        "index": idx,
        "repeat": repeated,
        "eq_true": eq_t, "eq_false": eq_f,
        "lt_true": lt_t, "gt_true": gt_t,
        "le_true": le_t, "ge_true": ge_t,
        "lt_shorter": lt_len
    };
}

cl def tuple_cl() -> dict {
    t: tuple = (10, 20);
    tuple_concat: list = list(t + (30,));
    tuple_in: bool = 10 in t;
    tuple_nin: bool = 99 not in t;

    t2: tuple = (1, 2, 3, 2, 1);
    cnt: int = t2.count(2);
    idx: int = t2.index(3);

    t3: tuple = (1, 2);
    repeated: list = list(t3 * 3);

    a: tuple = (1, 2, 3);
    b: tuple = (1, 2, 3);
    c: tuple = (1, 2, 4);
    d: tuple = (1, 2);
    eq_t: bool = a == b;
    eq_f: bool = a == c;
    lt_t: bool = a < c;
    gt_t: bool = c > a;
    le_t: bool = a <= b;
    ge_t: bool = c >= a;
    lt_len: bool = d < a;

    return {
        "tuple_concat": tuple_concat,
        "tuple_in": tuple_in,
        "tuple_nin": tuple_nin,
        "count": cnt,
        "index": idx,
        "repeat": repeated,
        "eq_true": eq_t, "eq_false": eq_f,
        "lt_true": lt_t, "gt_true": gt_t,
        "le_true": le_t, "ge_true": ge_t,
        "lt_shorter": lt_len
    };
}

na {
    def tuple_na() -> dict[str, any] {
        return {};
    }
}
