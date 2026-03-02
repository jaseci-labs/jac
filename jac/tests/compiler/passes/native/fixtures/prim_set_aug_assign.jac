"""Set augmented assignment operators: |=, &=, -=, ^=.

Cross-backend equivalence fixture -- Python reference + native implementation.
"""

def set_aug_assign_py() -> dict {
    # |= (union update)
    a: set[int] = {1, 2, 3};
    b: set[int] = {3, 4, 5};
    a |= b;
    ior_len: int = len(a);
    ior_has_1: int = 1 if 1 in a else 0;
    ior_has_4: int = 1 if 4 in a else 0;
    ior_has_5: int = 1 if 5 in a else 0;

    # &= (intersection update)
    c: set[int] = {1, 2, 3, 4};
    d: set[int] = {2, 4, 6};
    c &= d;
    iand_len: int = len(c);
    iand_has_2: int = 1 if 2 in c else 0;
    iand_has_4: int = 1 if 4 in c else 0;
    iand_has_1: int = 1 if 1 in c else 0;

    # -= (difference update)
    e: set[int] = {1, 2, 3, 4, 5};
    f: set[int] = {2, 4};
    e -= f;
    isub_len: int = len(e);
    isub_has_1: int = 1 if 1 in e else 0;
    isub_has_2: int = 1 if 2 in e else 0;
    isub_has_3: int = 1 if 3 in e else 0;

    # ^= (symmetric difference update)
    g: set[int] = {1, 2, 3};
    h: set[int] = {2, 3, 4};
    g ^= h;
    ixor_len: int = len(g);
    ixor_has_1: int = 1 if 1 in g else 0;
    ixor_has_2: int = 1 if 2 in g else 0;
    ixor_has_4: int = 1 if 4 in g else 0;

    return {
        "ior_len": ior_len, "ior_has_1": ior_has_1,
        "ior_has_4": ior_has_4, "ior_has_5": ior_has_5,
        "iand_len": iand_len, "iand_has_2": iand_has_2,
        "iand_has_4": iand_has_4, "iand_has_1": iand_has_1,
        "isub_len": isub_len, "isub_has_1": isub_has_1,
        "isub_has_2": isub_has_2, "isub_has_3": isub_has_3,
        "ixor_len": ixor_len, "ixor_has_1": ixor_has_1,
        "ixor_has_2": ixor_has_2, "ixor_has_4": ixor_has_4
    };
}

na {
    def set_aug_assign_na() -> dict[str, any] {
        # |= (union update)
        a: set[int] = {1, 2, 3};
        b: set[int] = {3, 4, 5};
        a |= b;
        ior_len: int = len(a);
        ior_has_1: int = 1 if 1 in a else 0;
        ior_has_4: int = 1 if 4 in a else 0;
        ior_has_5: int = 1 if 5 in a else 0;

        # &= (intersection update)
        c: set[int] = {1, 2, 3, 4};
        d: set[int] = {2, 4, 6};
        c &= d;
        iand_len: int = len(c);
        iand_has_2: int = 1 if 2 in c else 0;
        iand_has_4: int = 1 if 4 in c else 0;
        iand_has_1: int = 1 if 1 in c else 0;

        # -= (difference update)
        e: set[int] = {1, 2, 3, 4, 5};
        f: set[int] = {2, 4};
        e -= f;
        isub_len: int = len(e);
        isub_has_1: int = 1 if 1 in e else 0;
        isub_has_2: int = 1 if 2 in e else 0;
        isub_has_3: int = 1 if 3 in e else 0;

        # ^= (symmetric difference update)
        g: set[int] = {1, 2, 3};
        h: set[int] = {2, 3, 4};
        g ^= h;
        ixor_len: int = len(g);
        ixor_has_1: int = 1 if 1 in g else 0;
        ixor_has_2: int = 1 if 2 in g else 0;
        ixor_has_4: int = 1 if 4 in g else 0;

        return {
            "ior_len": ior_len, "ior_has_1": ior_has_1,
            "ior_has_4": ior_has_4, "ior_has_5": ior_has_5,
            "iand_len": iand_len, "iand_has_2": iand_has_2,
            "iand_has_4": iand_has_4, "iand_has_1": iand_has_1,
            "isub_len": isub_len, "isub_has_1": isub_has_1,
            "isub_has_2": isub_has_2, "isub_has_3": isub_has_3,
            "ixor_len": ixor_len, "ixor_has_1": ixor_has_1,
            "ixor_has_2": ixor_has_2, "ixor_has_4": ixor_has_4
        };
    }
}
