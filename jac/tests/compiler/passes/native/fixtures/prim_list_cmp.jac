"""List comparison operators: ==, !=, <, >, <=, >= (lexicographic).

Cross-backend equivalence fixture -- Python reference + native implementation.
"""

def list_cmp_py() -> dict {
    a: list[int] = [1, 2, 3];
    b: list[int] = [1, 2, 3];
    c: list[int] = [1, 2, 4];
    d: list[int] = [1, 2];
    e: list[int] = [1, 2, 3, 4];

    return {
        # == and !=
        "eq_same": 1 if a == b else 0,
        "eq_diff": 1 if a == c else 0,
        "eq_shorter": 1 if a == d else 0,
        "ne_same": 1 if a != b else 0,
        "ne_diff": 1 if a != c else 0,
        # < (lexicographic)
        "lt_less": 1 if a < c else 0,
        "lt_greater": 1 if c < a else 0,
        "lt_equal": 1 if a < b else 0,
        "lt_shorter": 1 if d < a else 0,
        "lt_longer": 1 if a < e else 0,
        # > (lexicographic)
        "gt_less": 1 if a > c else 0,
        "gt_greater": 1 if c > a else 0,
        "gt_equal": 1 if a > b else 0,
        # <=
        "le_less": 1 if a <= c else 0,
        "le_equal": 1 if a <= b else 0,
        "le_greater": 1 if c <= a else 0,
        # >=
        "ge_less": 1 if a >= c else 0,
        "ge_equal": 1 if a >= b else 0,
        "ge_greater": 1 if c >= a else 0
    };
}

na {
    def list_cmp_na() -> dict[str, any] {
        a: list[int] = [1, 2, 3];
        b: list[int] = [1, 2, 3];
        c: list[int] = [1, 2, 4];
        d: list[int] = [1, 2];
        e: list[int] = [1, 2, 3, 4];

        return {
            "eq_same": 1 if a == b else 0,
            "eq_diff": 1 if a == c else 0,
            "eq_shorter": 1 if a == d else 0,
            "ne_same": 1 if a != b else 0,
            "ne_diff": 1 if a != c else 0,
            "lt_less": 1 if a < c else 0,
            "lt_greater": 1 if c < a else 0,
            "lt_equal": 1 if a < b else 0,
            "lt_shorter": 1 if d < a else 0,
            "lt_longer": 1 if a < e else 0,
            "gt_less": 1 if a > c else 0,
            "gt_greater": 1 if c > a else 0,
            "gt_equal": 1 if a > b else 0,
            "le_less": 1 if a <= c else 0,
            "le_equal": 1 if a <= b else 0,
            "le_greater": 1 if c <= a else 0,
            "ge_less": 1 if a >= c else 0,
            "ge_equal": 1 if a >= b else 0,
            "ge_greater": 1 if c >= a else 0
        };
    }
}
