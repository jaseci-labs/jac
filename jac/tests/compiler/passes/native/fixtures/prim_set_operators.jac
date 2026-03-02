"""Set operator primitives: |, &, -, ^, ==, !=, <=, <, >=, >.

Cross-backend equivalence fixture -- Python reference + native implementation.
"""

def set_operators_py() -> dict {
    a: set[int] = {1, 2, 3, 4};
    b: set[int] = {3, 4, 5, 6};

    # Union |
    u: set[int] = a | b;
    u_len: int = len(u);
    u_has_1: int = 1 if 1 in u else 0;
    u_has_5: int = 1 if 5 in u else 0;

    # Intersection &
    i: set[int] = a & b;
    i_len: int = len(i);
    i_has_3: int = 1 if 3 in i else 0;
    i_has_1: int = 1 if 1 in i else 0;

    # Difference -
    d: set[int] = a - b;
    d_len: int = len(d);
    d_has_1: int = 1 if 1 in d else 0;
    d_has_3: int = 1 if 3 in d else 0;

    # Symmetric difference ^
    sd: set[int] = a ^ b;
    sd_len: int = len(sd);
    sd_has_1: int = 1 if 1 in sd else 0;
    sd_has_3: int = 1 if 3 in sd else 0;
    sd_has_5: int = 1 if 5 in sd else 0;

    # Comparison operators
    c: set[int] = {1, 2, 3};
    c2: set[int] = {1, 2, 3};
    c3: set[int] = {1, 2};
    c4: set[int] = {1, 2, 3, 4};
    c5: set[int] = {7, 8, 9};

    eq_same: int = 1 if c == c2 else 0;
    eq_diff: int = 1 if c == c3 else 0;
    ne_same: int = 1 if c != c2 else 0;
    ne_diff: int = 1 if c != c3 else 0;
    le_sub: int = 1 if c3 <= c else 0;
    le_eq: int = 1 if c <= c2 else 0;
    le_sup: int = 1 if c <= c3 else 0;
    lt_sub: int = 1 if c3 < c else 0;
    lt_eq: int = 1 if c < c2 else 0;
    ge_sup: int = 1 if c >= c3 else 0;
    ge_eq: int = 1 if c >= c2 else 0;
    ge_sub: int = 1 if c3 >= c else 0;
    gt_sup: int = 1 if c > c3 else 0;
    gt_eq: int = 1 if c > c2 else 0;

    return {
        "u_len": u_len, "u_has_1": u_has_1, "u_has_5": u_has_5,
        "i_len": i_len, "i_has_3": i_has_3, "i_has_1": i_has_1,
        "d_len": d_len, "d_has_1": d_has_1, "d_has_3": d_has_3,
        "sd_len": sd_len, "sd_has_1": sd_has_1, "sd_has_3": sd_has_3, "sd_has_5": sd_has_5,
        "eq_same": eq_same, "eq_diff": eq_diff,
        "ne_same": ne_same, "ne_diff": ne_diff,
        "le_sub": le_sub, "le_eq": le_eq, "le_sup": le_sup,
        "lt_sub": lt_sub, "lt_eq": lt_eq,
        "ge_sup": ge_sup, "ge_eq": ge_eq, "ge_sub": ge_sub,
        "gt_sup": gt_sup, "gt_eq": gt_eq
    };
}

na {
    def set_operators_na() -> dict[str, any] {
        a: set[int] = {1, 2, 3, 4};
        b: set[int] = {3, 4, 5, 6};

        # Union |
        u: set[int] = a | b;
        u_len: int = len(u);
        u_has_1: int = 1 if 1 in u else 0;
        u_has_5: int = 1 if 5 in u else 0;

        # Intersection &
        i: set[int] = a & b;
        i_len: int = len(i);
        i_has_3: int = 1 if 3 in i else 0;
        i_has_1: int = 1 if 1 in i else 0;

        # Difference -
        d: set[int] = a - b;
        d_len: int = len(d);
        d_has_1: int = 1 if 1 in d else 0;
        d_has_3: int = 1 if 3 in d else 0;

        # Symmetric difference ^
        sd: set[int] = a ^ b;
        sd_len: int = len(sd);
        sd_has_1: int = 1 if 1 in sd else 0;
        sd_has_3: int = 1 if 3 in sd else 0;
        sd_has_5: int = 1 if 5 in sd else 0;

        # Comparison operators
        c: set[int] = {1, 2, 3};
        c2: set[int] = {1, 2, 3};
        c3: set[int] = {1, 2};
        c4: set[int] = {1, 2, 3, 4};
        c5: set[int] = {7, 8, 9};

        eq_same: int = 1 if c == c2 else 0;
        eq_diff: int = 1 if c == c3 else 0;
        ne_same: int = 1 if c != c2 else 0;
        ne_diff: int = 1 if c != c3 else 0;
        le_sub: int = 1 if c3 <= c else 0;
        le_eq: int = 1 if c <= c2 else 0;
        le_sup: int = 1 if c <= c3 else 0;
        lt_sub: int = 1 if c3 < c else 0;
        lt_eq: int = 1 if c < c2 else 0;
        ge_sup: int = 1 if c >= c3 else 0;
        ge_eq: int = 1 if c >= c2 else 0;
        ge_sub: int = 1 if c3 >= c else 0;
        gt_sup: int = 1 if c > c3 else 0;
        gt_eq: int = 1 if c > c2 else 0;

        return {
            "u_len": u_len, "u_has_1": u_has_1, "u_has_5": u_has_5,
            "i_len": i_len, "i_has_3": i_has_3, "i_has_1": i_has_1,
            "d_len": d_len, "d_has_1": d_has_1, "d_has_3": d_has_3,
            "sd_len": sd_len, "sd_has_1": sd_has_1, "sd_has_3": sd_has_3, "sd_has_5": sd_has_5,
            "eq_same": eq_same, "eq_diff": eq_diff,
            "ne_same": ne_same, "ne_diff": ne_diff,
            "le_sub": le_sub, "le_eq": le_eq, "le_sup": le_sup,
            "lt_sub": lt_sub, "lt_eq": lt_eq,
            "ge_sup": ge_sup, "ge_eq": ge_eq, "ge_sub": ge_sub,
            "gt_sup": gt_sup, "gt_eq": gt_eq
        };
    }
}
