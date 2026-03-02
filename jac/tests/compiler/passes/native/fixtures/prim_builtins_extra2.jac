"""Extra builtin functions: sum, any, all, divmod.

Cross-backend equivalence fixture -- Python reference + native implementation.
"""

def builtins_extra2_py() -> dict {
    # sum
    sum_empty: int = sum([]);
    sum_one: int = sum([42]);
    sum_many: int = sum([1, 2, 3, 4, 5]);
    sum_neg: int = sum([-1, 0, 1]);

    # any
    any_empty: int = 1 if any([]) else 0;
    any_all_false: int = 1 if any([0, 0, 0]) else 0;
    any_one_true: int = 1 if any([0, 0, 1]) else 0;
    any_all_true: int = 1 if any([1, 2, 3]) else 0;

    # all
    all_empty: int = 1 if all([]) else 0;
    all_all_true: int = 1 if all([1, 2, 3]) else 0;
    all_one_false: int = 1 if all([1, 0, 3]) else 0;
    all_all_false: int = 1 if all([0, 0, 0]) else 0;

    # divmod
    dm1: tuple[int, int] = divmod(17, 5);
    dm1_q: int = dm1[0];
    dm1_r: int = dm1[1];
    dm2: tuple[int, int] = divmod(10, 3);
    dm2_q: int = dm2[0];
    dm2_r: int = dm2[1];
    dm3: tuple[int, int] = divmod(7, 1);
    dm3_q: int = dm3[0];
    dm3_r: int = dm3[1];

    return {
        "sum_empty": sum_empty, "sum_one": sum_one,
        "sum_many": sum_many, "sum_neg": sum_neg,
        "any_empty": any_empty, "any_all_false": any_all_false,
        "any_one_true": any_one_true, "any_all_true": any_all_true,
        "all_empty": all_empty, "all_all_true": all_all_true,
        "all_one_false": all_one_false, "all_all_false": all_all_false,
        "dm1_q": dm1_q, "dm1_r": dm1_r,
        "dm2_q": dm2_q, "dm2_r": dm2_r,
        "dm3_q": dm3_q, "dm3_r": dm3_r
    };
}

na {
    def builtins_extra2_na() -> dict[str, any] {
        # sum
        lst_empty: list[int] = [];
        lst_one: list[int] = [42];
        lst_many: list[int] = [1, 2, 3, 4, 5];
        lst_neg: list[int] = [-1, 0, 1];
        sum_empty: int = sum(lst_empty);
        sum_one: int = sum(lst_one);
        sum_many: int = sum(lst_many);
        sum_neg: int = sum(lst_neg);

        # any
        lst_f: list[int] = [0, 0, 0];
        lst_ot: list[int] = [0, 0, 1];
        lst_at: list[int] = [1, 2, 3];
        any_empty: int = 1 if any(lst_empty) else 0;
        any_all_false: int = 1 if any(lst_f) else 0;
        any_one_true: int = 1 if any(lst_ot) else 0;
        any_all_true: int = 1 if any(lst_at) else 0;

        # all
        lst_of: list[int] = [1, 0, 3];
        all_empty: int = 1 if all(lst_empty) else 0;
        all_all_true: int = 1 if all(lst_at) else 0;
        all_one_false: int = 1 if all(lst_of) else 0;
        all_all_false: int = 1 if all(lst_f) else 0;

        # divmod
        dm1: tuple[int, int] = divmod(17, 5);
        dm1_q: int = dm1[0];
        dm1_r: int = dm1[1];
        dm2: tuple[int, int] = divmod(10, 3);
        dm2_q: int = dm2[0];
        dm2_r: int = dm2[1];
        dm3: tuple[int, int] = divmod(7, 1);
        dm3_q: int = dm3[0];
        dm3_r: int = dm3[1];

        return {
            "sum_empty": sum_empty, "sum_one": sum_one,
            "sum_many": sum_many, "sum_neg": sum_neg,
            "any_empty": any_empty, "any_all_false": any_all_false,
            "any_one_true": any_one_true, "any_all_true": any_all_true,
            "all_empty": all_empty, "all_all_true": all_all_true,
            "all_one_false": all_one_false, "all_all_false": all_all_false,
            "dm1_q": dm1_q, "dm1_r": dm1_r,
            "dm2_q": dm2_q, "dm2_r": dm2_r,
            "dm3_q": dm3_q, "dm3_r": dm3_r
        };
    }
}
