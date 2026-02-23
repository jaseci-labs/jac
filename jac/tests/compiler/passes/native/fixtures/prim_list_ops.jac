"""List operators: in, + (concatenation).

Cross-backend equivalence fixture -- Python reference + native implementation.
"""

def list_ops_py() -> dict {
    # list in operator
    nums: list[int] = [10, 20, 30, 40, 50];
    in_found: int = 1 if 30 in nums else 0;
    in_missing: int = 1 if 99 in nums else 0;
    not_in_found: int = 1 if 30 not in nums else 0;
    not_in_missing: int = 1 if 99 not in nums else 0;
    in_first: int = 1 if 10 in nums else 0;
    in_last: int = 1 if 50 in nums else 0;
    # list + operator (concatenation)
    a: list[int] = [1, 2, 3];
    b: list[int] = [4, 5, 6];
    c: list[int] = a + b;
    return {
        "in_found": in_found,
        "in_missing": in_missing,
        "not_in_found": not_in_found,
        "not_in_missing": not_in_missing,
        "in_first": in_first,
        "in_last": in_last,
        "concat_len": len(c),
        "concat_0": c[0],
        "concat_1": c[1],
        "concat_2": c[2],
        "concat_3": c[3],
        "concat_4": c[4],
        "concat_5": c[5],
        "orig_a_len": len(a),
        "orig_b_len": len(b)
    };
}

na {
    def list_ops_na() -> dict[str, any] {
        # list in operator
        nums: list[int] = [10, 20, 30, 40, 50];
        in_found: int = 1 if 30 in nums else 0;
        in_missing: int = 1 if 99 in nums else 0;
        not_in_found: int = 1 if 30 not in nums else 0;
        not_in_missing: int = 1 if 99 not in nums else 0;
        in_first: int = 1 if 10 in nums else 0;
        in_last: int = 1 if 50 in nums else 0;
        # list + operator (concatenation)
        a: list[int] = [1, 2, 3];
        b: list[int] = [4, 5, 6];
        c: list[int] = a + b;
        return {
            "in_found": in_found,
            "in_missing": in_missing,
            "not_in_found": not_in_found,
            "not_in_missing": not_in_missing,
            "in_first": in_first,
            "in_last": in_last,
            "concat_len": len(c),
            "concat_0": c[0],
            "concat_1": c[1],
            "concat_2": c[2],
            "concat_3": c[3],
            "concat_4": c[4],
            "concat_5": c[5],
            "orig_a_len": len(a),
            "orig_b_len": len(b)
        };
    }
}
