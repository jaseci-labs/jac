"""Frozenset operator and method primitives.

Cross-backend equivalence fixture.
Covers all 18 FrozensetEmitter interfaces: copy, union, intersection,
difference, symmetric_difference, issubset, issuperset, isdisjoint,
op_or, op_and, op_sub, op_xor, op_eq, op_ne, op_le, op_lt, op_ge, op_gt.
"""

def frozenset_py() -> dict {
    a = frozenset([1, 2, 3, 4]);
    b = frozenset([3, 4, 5, 6]);

    copy_a: list = sorted(list(a.copy()));
    union: list = sorted(list(a.union(b)));
    intersection: list = sorted(list(a.intersection(b)));
    difference: list = sorted(list(a.difference(b)));
    sym_diff: list = sorted(list(a.symmetric_difference(b)));

    sub_yes: bool = frozenset([1, 2]).issubset(frozenset([1, 2, 3]));
    sub_no: bool = frozenset([1, 4]).issubset(frozenset([1, 2, 3]));
    super_yes: bool = frozenset([1, 2, 3]).issuperset(frozenset([1, 2]));
    super_no: bool = frozenset([1, 2]).issuperset(frozenset([1, 2, 3]));
    disj_yes: bool = frozenset([1, 2]).isdisjoint(frozenset([3, 4]));
    disj_no: bool = frozenset([1, 2]).isdisjoint(frozenset([2, 3]));

    or_op: list = sorted(list(a | b));
    and_op: list = sorted(list(a & b));
    sub_op: list = sorted(list(a - b));
    xor_op: list = sorted(list(a ^ b));

    eq_yes: bool = frozenset([1, 2]) == frozenset([1, 2]);
    eq_no: bool = frozenset([1, 2]) == frozenset([1, 3]);
    ne_yes: bool = frozenset([1, 2]) != frozenset([1, 3]);
    ne_no: bool = frozenset([1, 2]) != frozenset([1, 2]);

    le_yes: bool = frozenset([1, 2]) <= frozenset([1, 2, 3]);
    le_eq: bool = frozenset([1, 2]) <= frozenset([1, 2]);
    lt_yes: bool = frozenset([1, 2]) < frozenset([1, 2, 3]);
    lt_no: bool = frozenset([1, 2]) < frozenset([1, 2]);
    ge_yes: bool = frozenset([1, 2, 3]) >= frozenset([1, 2]);
    ge_eq: bool = frozenset([1, 2]) >= frozenset([1, 2]);
    gt_yes: bool = frozenset([1, 2, 3]) > frozenset([1, 2]);
    gt_no: bool = frozenset([1, 2]) > frozenset([1, 2]);

    u: frozenset = a | b;
    i: frozenset = a & b;
    d: frozenset = a - b;
    sd: frozenset = a ^ b;
    u2: frozenset = a.union(b);
    i2: frozenset = a.intersection(b);
    d2: frozenset = a.difference(b);
    cp: frozenset = a.copy();

    c1: frozenset = frozenset([1, 2, 3]);
    c2: frozenset = frozenset([1, 2, 3]);
    c3: frozenset = frozenset([1, 2]);

    return {
        "copy": copy_a,
        "union": union, "intersection": intersection,
        "difference": difference, "sym_diff": sym_diff,
        "sub_yes": sub_yes, "sub_no": sub_no,
        "super_yes": super_yes, "super_no": super_no,
        "disj_yes": disj_yes, "disj_no": disj_no,
        "or_op": or_op, "and_op": and_op,
        "sub_op": sub_op, "xor_op": xor_op,
        "eq_yes": eq_yes, "eq_no": eq_no,
        "ne_yes": ne_yes, "ne_no": ne_no,
        "le_yes": le_yes, "le_eq": le_eq,
        "lt_yes": lt_yes, "lt_no": lt_no,
        "ge_yes": ge_yes, "ge_eq": ge_eq,
        "gt_yes": gt_yes, "gt_no": gt_no,
        "u_len": len(u), "u_has_1": 1 if 1 in u else 0, "u_has_5": 1 if 5 in u else 0,
        "i_len": len(i), "i_has_3": 1 if 3 in i else 0, "i_has_1": 1 if 1 in i else 0,
        "d_len": len(d), "d_has_1": 1 if 1 in d else 0, "d_has_3": 1 if 3 in d else 0,
        "sd_len": len(sd), "sd_has_1": 1 if 1 in sd else 0, "sd_has_5": 1 if 5 in sd else 0,
        "u2_len": len(u2), "i2_len": len(i2), "d2_len": len(d2),
        "sd2_len": len(a.symmetric_difference(b)),
        "sd2_has_1": 1 if 1 in a.symmetric_difference(b) else 0,
        "sd2_has_5": 1 if 5 in a.symmetric_difference(b) else 0,
        "cp_len": len(cp),
        "eq_same": 1 if c1 == c2 else 0,
        "eq_diff": 1 if c1 == c3 else 0,
        "ne_same": 1 if c1 != c2 else 0,
        "ne_diff": 1 if c1 != c3 else 0,
        "le_sub": 1 if c3 <= c1 else 0,
        "le_eq_na": 1 if c1 <= c2 else 0,
        "lt_sub": 1 if c3 < c1 else 0,
        "lt_eq": 1 if c1 < c2 else 0,
        "ge_sup": 1 if c1 >= c3 else 0,
        "ge_eq_na": 1 if c1 >= c2 else 0,
        "gt_sup": 1 if c1 > c3 else 0,
        "gt_eq": 1 if c1 > c2 else 0,
        "sub_yes_na": 1 if c3.issubset(c1) else 0,
        "sub_no_na": 1 if c1.issubset(c3) else 0,
        "super_yes_na": 1 if c1.issuperset(c3) else 0,
        "super_no_na": 1 if c3.issuperset(c1) else 0,
        "disj_yes_na": 1 if c1.isdisjoint(frozenset([7, 8, 9])) else 0,
        "disj_no_na": 1 if c1.isdisjoint(frozenset([1, 9])) else 0
    };
}

cl def frozenset_cl() -> dict {
    a = frozenset([1, 2, 3, 4]);
    b = frozenset([3, 4, 5, 6]);

    copy_a: list = sorted(list(a.copy()));
    union: list = sorted(list(a.union(b)));
    intersection: list = sorted(list(a.intersection(b)));
    difference: list = sorted(list(a.difference(b)));
    sym_diff: list = sorted(list(a.symmetric_difference(b)));

    sub_yes: bool = frozenset([1, 2]).issubset(frozenset([1, 2, 3]));
    sub_no: bool = frozenset([1, 4]).issubset(frozenset([1, 2, 3]));
    super_yes: bool = frozenset([1, 2, 3]).issuperset(frozenset([1, 2]));
    super_no: bool = frozenset([1, 2]).issuperset(frozenset([1, 2, 3]));
    disj_yes: bool = frozenset([1, 2]).isdisjoint(frozenset([3, 4]));
    disj_no: bool = frozenset([1, 2]).isdisjoint(frozenset([2, 3]));

    or_op: list = sorted(list(a | b));
    and_op: list = sorted(list(a & b));
    sub_op: list = sorted(list(a - b));
    xor_op: list = sorted(list(a ^ b));

    eq_yes: bool = frozenset([1, 2]) == frozenset([1, 2]);
    eq_no: bool = frozenset([1, 2]) == frozenset([1, 3]);
    ne_yes: bool = frozenset([1, 2]) != frozenset([1, 3]);
    ne_no: bool = frozenset([1, 2]) != frozenset([1, 2]);

    le_yes: bool = frozenset([1, 2]) <= frozenset([1, 2, 3]);
    le_eq: bool = frozenset([1, 2]) <= frozenset([1, 2]);
    lt_yes: bool = frozenset([1, 2]) < frozenset([1, 2, 3]);
    lt_no: bool = frozenset([1, 2]) < frozenset([1, 2]);
    ge_yes: bool = frozenset([1, 2, 3]) >= frozenset([1, 2]);
    ge_eq: bool = frozenset([1, 2]) >= frozenset([1, 2]);
    gt_yes: bool = frozenset([1, 2, 3]) > frozenset([1, 2]);
    gt_no: bool = frozenset([1, 2]) > frozenset([1, 2]);

    return {
        "copy": copy_a,
        "union": union, "intersection": intersection,
        "difference": difference, "sym_diff": sym_diff,
        "sub_yes": sub_yes, "sub_no": sub_no,
        "super_yes": super_yes, "super_no": super_no,
        "disj_yes": disj_yes, "disj_no": disj_no,
        "or_op": or_op, "and_op": and_op,
        "sub_op": sub_op, "xor_op": xor_op,
        "eq_yes": eq_yes, "eq_no": eq_no,
        "ne_yes": ne_yes, "ne_no": ne_no,
        "le_yes": le_yes, "le_eq": le_eq,
        "lt_yes": lt_yes, "lt_no": lt_no,
        "ge_yes": ge_yes, "ge_eq": ge_eq,
        "gt_yes": gt_yes, "gt_no": gt_no
    };
}

na {
    def frozenset_na() -> dict[str, any] {
        a: frozenset[int] = {1, 2, 3, 4};
        b: frozenset[int] = {3, 4, 5, 6};

        u: frozenset[int] = a | b;
        i: frozenset[int] = a & b;
        d: frozenset[int] = a - b;
        sd: frozenset[int] = a ^ b;

        u2: frozenset[int] = a.union(b);
        i2: frozenset[int] = a.intersection(b);
        d2: frozenset[int] = a.difference(b);
        sd2: frozenset[int] = a.symmetric_difference(b);
        cp: frozenset[int] = a.copy();

        c1: frozenset[int] = {1, 2, 3};
        c2: frozenset[int] = {1, 2, 3};
        c3: frozenset[int] = {1, 2};

        return {
            "u_len": len(u), "u_has_1": 1 if 1 in u else 0, "u_has_5": 1 if 5 in u else 0,
            "i_len": len(i), "i_has_3": 1 if 3 in i else 0, "i_has_1": 1 if 1 in i else 0,
            "d_len": len(d), "d_has_1": 1 if 1 in d else 0, "d_has_3": 1 if 3 in d else 0,
            "sd_len": len(sd), "sd_has_1": 1 if 1 in sd else 0, "sd_has_5": 1 if 5 in sd else 0,
            "u2_len": len(u2), "i2_len": len(i2), "d2_len": len(d2),
            "sd2_len": len(sd2), "sd2_has_1": 1 if 1 in sd2 else 0, "sd2_has_5": 1 if 5 in sd2 else 0,
            "cp_len": len(cp),
            "eq_same": 1 if c1 == c2 else 0,
            "eq_diff": 1 if c1 == c3 else 0,
            "ne_same": 1 if c1 != c2 else 0,
            "ne_diff": 1 if c1 != c3 else 0,
            "le_sub": 1 if c3 <= c1 else 0,
            "le_eq_na": 1 if c1 <= c2 else 0,
            "lt_sub": 1 if c3 < c1 else 0,
            "lt_eq": 1 if c1 < c2 else 0,
            "ge_sup": 1 if c1 >= c3 else 0,
            "ge_eq_na": 1 if c1 >= c2 else 0,
            "gt_sup": 1 if c1 > c3 else 0,
            "gt_eq": 1 if c1 > c2 else 0,
            "sub_yes_na": 1 if c3.issubset(c1) else 0,
            "sub_no_na": 1 if c1.issubset(c3) else 0,
            "super_yes_na": 1 if c1.issuperset(c3) else 0,
            "super_no_na": 1 if c3.issuperset(c1) else 0,
            "disj_yes_na": 1 if c1.isdisjoint({7, 8, 9}) else 0,
            "disj_no_na": 1 if c1.isdisjoint({1, 9}) else 0
        };
    }
}
