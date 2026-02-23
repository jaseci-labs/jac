"""Set algebra: union, intersection, difference, issubset, issuperset, isdisjoint.

Cross-backend equivalence fixture -- Python reference + native implementation.
"""

def set_algebra_py() -> dict {
    a: set[int] = {1, 2, 3, 4};
    b: set[int] = {3, 4, 5, 6};
    # union
    u: set[int] = a.union(b);
    u_len: int = len(u);
    u_has_1: int = 1 if 1 in u else 0;
    u_has_5: int = 1 if 5 in u else 0;
    # intersection
    i_set: set[int] = a.intersection(b);
    i_len: int = len(i_set);
    i_has_3: int = 1 if 3 in i_set else 0;
    i_has_1: int = 1 if 1 in i_set else 0;
    # difference
    d_set: set[int] = a.difference(b);
    d_len: int = len(d_set);
    d_has_1: int = 1 if 1 in d_set else 0;
    d_has_3: int = 1 if 3 in d_set else 0;
    # issubset / issuperset / isdisjoint
    c: set[int] = {2, 3};
    sub: int = 1 if c.issubset(a) else 0;
    sup: int = 1 if a.issuperset(c) else 0;
    not_sub: int = 1 if a.issubset(c) else 0;
    e: set[int] = {7, 8};
    disj: int = 1 if a.isdisjoint(e) else 0;
    not_disj: int = 1 if a.isdisjoint(b) else 0;
    return {
        "u_len": u_len,
        "u_has_1": u_has_1,
        "u_has_5": u_has_5,
        "i_len": i_len,
        "i_has_3": i_has_3,
        "i_has_1": i_has_1,
        "d_len": d_len,
        "d_has_1": d_has_1,
        "d_has_3": d_has_3,
        "sub": sub,
        "sup": sup,
        "not_sub": not_sub,
        "disj": disj,
        "not_disj": not_disj
    };
}

na {
    def set_algebra_na() -> dict[str, any] {
        a: set[int] = {1, 2, 3, 4};
        b: set[int] = {3, 4, 5, 6};
        # union
        u: set[int] = a.union(b);
        u_len: int = len(u);
        u_has_1: int = 1 if 1 in u else 0;
        u_has_5: int = 1 if 5 in u else 0;
        # intersection
        i_set: set[int] = a.intersection(b);
        i_len: int = len(i_set);
        i_has_3: int = 1 if 3 in i_set else 0;
        i_has_1: int = 1 if 1 in i_set else 0;
        # difference
        d_set: set[int] = a.difference(b);
        d_len: int = len(d_set);
        d_has_1: int = 1 if 1 in d_set else 0;
        d_has_3: int = 1 if 3 in d_set else 0;
        # issubset / issuperset / isdisjoint
        c: set[int] = {2, 3};
        sub: int = 1 if c.issubset(a) else 0;
        sup: int = 1 if a.issuperset(c) else 0;
        not_sub: int = 1 if a.issubset(c) else 0;
        e: set[int] = {7, 8};
        disj: int = 1 if a.isdisjoint(e) else 0;
        not_disj: int = 1 if a.isdisjoint(b) else 0;
        return {
            "u_len": u_len,
            "u_has_1": u_has_1,
            "u_has_5": u_has_5,
            "i_len": i_len,
            "i_has_3": i_has_3,
            "i_has_1": i_has_1,
            "d_len": d_len,
            "d_has_1": d_has_1,
            "d_has_3": d_has_3,
            "sub": sub,
            "sup": sup,
            "not_sub": not_sub,
            "disj": disj,
            "not_disj": not_disj
        };
    }
}
