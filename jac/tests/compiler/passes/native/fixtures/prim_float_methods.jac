"""Float method primitives: is_integer, conjugate, floor division.

Cross-backend equivalence fixture — Python reference + native implementation.
"""

def float_methods_py() -> dict {
    return {
        # is_integer
        "isint_whole": 1 if (3.0).is_integer() else 0,
        "isint_frac": 1 if (3.5).is_integer() else 0,
        "isint_zero": 1 if (0.0).is_integer() else 0,
        "isint_neg_whole": 1 if (-4.0).is_integer() else 0,
        "isint_neg_frac": 1 if (-4.5).is_integer() else 0,
        # conjugate
        "conjugate_pos": (3.14).conjugate(),
        "conjugate_neg": (-2.5).conjugate(),
        "conjugate_zero": (0.0).conjugate(),
        # floor division
        "floordiv_pos": 7.0 // 2.0,
        "floordiv_neg": -7.0 // 2.0,
        "floordiv_exact": 6.0 // 3.0,
        "floordiv_small": 1.0 // 3.0,
        "floordiv_neg2": 7.0 // -2.0
    };
}

na {
    def float_methods_na() -> dict[str, any] {
        return {
            # is_integer
            "isint_whole": 1 if (3.0).is_integer() else 0,
            "isint_frac": 1 if (3.5).is_integer() else 0,
            "isint_zero": 1 if (0.0).is_integer() else 0,
            "isint_neg_whole": 1 if (-4.0).is_integer() else 0,
            "isint_neg_frac": 1 if (-4.5).is_integer() else 0,
            # conjugate
            "conjugate_pos": (3.14).conjugate(),
            "conjugate_neg": (-2.5).conjugate(),
            "conjugate_zero": (0.0).conjugate(),
            # floor division
            "floordiv_pos": 7.0 // 2.0,
            "floordiv_neg": -7.0 // 2.0,
            "floordiv_exact": 6.0 // 3.0,
            "floordiv_small": 1.0 // 3.0,
            "floordiv_neg2": 7.0 // -2.0
        };
    }
}
