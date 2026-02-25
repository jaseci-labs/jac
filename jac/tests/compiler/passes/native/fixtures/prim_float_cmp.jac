"""Float comparison and operation primitives.

Cross-backend equivalence fixture — Python reference + native implementation.
Tests float comparisons (lt, gt, le, ge), negation, floor division, modulo,
and the str() conversion of floats.
"""

def float_cmp_py() -> dict {
    x: float = 3.5;
    y: float = 1.2;
    z: float = 3.5;
    return {
        "lt_true": 1 if y < x else 0,
        "lt_false": 1 if x < y else 0,
        "gt_true": 1 if x > y else 0,
        "gt_false": 1 if y > x else 0,
        "le_true": 1 if y <= x else 0,
        "le_equal": 1 if x <= z else 0,
        "le_false": 1 if x <= y else 0,
        "ge_true": 1 if x >= y else 0,
        "ge_equal": 1 if x >= z else 0,
        "ge_false": 1 if y >= x else 0,
        "eq_true": 1 if x == z else 0,
        "eq_false": 1 if x == y else 0,
        "ne_true": 1 if x != y else 0,
        "ne_false": 1 if x != z else 0,
        "neg_pos": 0.0 - x,
        "neg_neg": 0.0 - (0.0 - x),
        "mod": 7.5 % 2.0,
        "pow_float": 2.0 ** 3.0,
        "abs_neg_float": abs(-3.14),
        "abs_pos_float": abs(3.14),
        "min_float": min(3.5, 1.2),
        "max_float": max(3.5, 1.2)
    };
}

na {
    def float_cmp_na() -> dict[str, any] {
        x: float = 3.5;
        y: float = 1.2;
        z: float = 3.5;
        return {
            "lt_true": 1 if y < x else 0,
            "lt_false": 1 if x < y else 0,
            "gt_true": 1 if x > y else 0,
            "gt_false": 1 if y > x else 0,
            "le_true": 1 if y <= x else 0,
            "le_equal": 1 if x <= z else 0,
            "le_false": 1 if x <= y else 0,
            "ge_true": 1 if x >= y else 0,
            "ge_equal": 1 if x >= z else 0,
            "ge_false": 1 if y >= x else 0,
            "eq_true": 1 if x == z else 0,
            "eq_false": 1 if x == y else 0,
            "ne_true": 1 if x != y else 0,
            "ne_false": 1 if x != z else 0,
            "neg_pos": 0.0 - x,
            "neg_neg": 0.0 - (0.0 - x),
            "mod": 7.5 % 2.0,
            "pow_float": 2.0 ** 3.0,
            "abs_neg_float": abs(-3.14),
            "abs_pos_float": abs(3.14),
            "min_float": min(3.5, 1.2),
            "max_float": max(3.5, 1.2)
        };
    }
}
