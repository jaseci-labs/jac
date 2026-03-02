"""Frozenset operations: operators, methods, comparisons.

frozenset[T] uses the same underlying type as set[T] in native.
Cross-backend equivalence fixture -- Python reference + native implementation.
"""

def frozenset_py() -> dict {
    a: frozenset = frozenset([1, 2, 3, 4]);
    b: frozenset = frozenset([3, 4, 5, 6]);

    # Operators
    u: frozenset = a | b;
    i: frozenset = a & b;
    d: frozenset = a - b;
    sd: frozenset = a ^ b;

    # Methods
    u2: frozenset = a.union(b);
    i2: frozenset = a.intersection(b);
    d2: frozenset = a.difference(b);
    cp: frozenset = a.copy();

    # Comparisons
    c1: frozenset = frozenset([1, 2, 3]);
    c2: frozenset = frozenset([1, 2, 3]);
    c3: frozenset = frozenset([1, 2]);

    return {
        # operator results (lengths + membership)
        "u_len": len(u), "u_has_1": 1 if 1 in u else 0, "u_has_5": 1 if 5 in u else 0,
        "i_len": len(i), "i_has_3": 1 if 3 in i else 0, "i_has_1": 1 if 1 in i else 0,
        "d_len": len(d), "d_has_1": 1 if 1 in d else 0, "d_has_3": 1 if 3 in d else 0,
        "sd_len": len(sd), "sd_has_1": 1 if 1 in sd else 0, "sd_has_5": 1 if 5 in sd else 0,
        # method results (lengths)
        "u2_len": len(u2), "i2_len": len(i2), "d2_len": len(d2), "cp_len": len(cp),
        # comparisons
        "eq_same": 1 if c1 == c2 else 0,
        "eq_diff": 1 if c1 == c3 else 0,
        "ne_same": 1 if c1 != c2 else 0,
        "ne_diff": 1 if c1 != c3 else 0,
        "le_sub": 1 if c3 <= c1 else 0,
        "le_eq": 1 if c1 <= c2 else 0,
        "lt_sub": 1 if c3 < c1 else 0,
        "lt_eq": 1 if c1 < c2 else 0,
        "ge_sup": 1 if c1 >= c3 else 0,
        "ge_eq": 1 if c1 >= c2 else 0,
        "gt_sup": 1 if c1 > c3 else 0,
        "gt_eq": 1 if c1 > c2 else 0,
        # issubset, issuperset, isdisjoint
        "sub_yes": 1 if c3.issubset(c1) else 0,
        "sub_no": 1 if c1.issubset(c3) else 0,
        "super_yes": 1 if c1.issuperset(c3) else 0,
        "super_no": 1 if c3.issuperset(c1) else 0,
        "disj_yes": 1 if c1.isdisjoint(frozenset([7, 8, 9])) else 0,
        "disj_no": 1 if c1.isdisjoint(frozenset([1, 9])) else 0
    };
}

na {
    def frozenset_na() -> dict[str, any] {
        a: frozenset[int] = {1, 2, 3, 4};
        b: frozenset[int] = {3, 4, 5, 6};

        # Operators
        u: frozenset[int] = a | b;
        i: frozenset[int] = a & b;
        d: frozenset[int] = a - b;
        sd: frozenset[int] = a ^ b;

        # Methods (dispatch through set emitter since same underlying type)
        u2: frozenset[int] = a.union(b);
        i2: frozenset[int] = a.intersection(b);
        d2: frozenset[int] = a.difference(b);
        cp: frozenset[int] = a.copy();

        # Comparisons
        c1: frozenset[int] = {1, 2, 3};
        c2: frozenset[int] = {1, 2, 3};
        c3: frozenset[int] = {1, 2};

        return {
            "u_len": len(u), "u_has_1": 1 if 1 in u else 0, "u_has_5": 1 if 5 in u else 0,
            "i_len": len(i), "i_has_3": 1 if 3 in i else 0, "i_has_1": 1 if 1 in i else 0,
            "d_len": len(d), "d_has_1": 1 if 1 in d else 0, "d_has_3": 1 if 3 in d else 0,
            "sd_len": len(sd), "sd_has_1": 1 if 1 in sd else 0, "sd_has_5": 1 if 5 in sd else 0,
            "u2_len": len(u2), "i2_len": len(i2), "d2_len": len(d2), "cp_len": len(cp),
            "eq_same": 1 if c1 == c2 else 0,
            "eq_diff": 1 if c1 == c3 else 0,
            "ne_same": 1 if c1 != c2 else 0,
            "ne_diff": 1 if c1 != c3 else 0,
            "le_sub": 1 if c3 <= c1 else 0,
            "le_eq": 1 if c1 <= c2 else 0,
            "lt_sub": 1 if c3 < c1 else 0,
            "lt_eq": 1 if c1 < c2 else 0,
            "ge_sup": 1 if c1 >= c3 else 0,
            "ge_eq": 1 if c1 >= c2 else 0,
            "gt_sup": 1 if c1 > c3 else 0,
            "gt_eq": 1 if c1 > c2 else 0,
            "sub_yes": 1 if c3.issubset(c1) else 0,
            "sub_no": 1 if c1.issubset(c3) else 0,
            "super_yes": 1 if c1.issuperset(c3) else 0,
            "super_no": 1 if c3.issuperset(c1) else 0,
            "disj_yes": 1 if c1.isdisjoint({7, 8, 9}) else 0,
            "disj_no": 1 if c1.isdisjoint({1, 9}) else 0
        };
    }
}
