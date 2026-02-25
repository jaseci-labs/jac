"""String comparison primitives: <, >, <=, >=.

Cross-backend equivalence fixture — Python reference + native implementation.
"""

def str_cmp_py() -> dict {
    return {
        # Less than
        "lt_abc_def": 1 if "abc" < "def" else 0,
        "lt_def_abc": 1 if "def" < "abc" else 0,
        "lt_same": 1 if "abc" < "abc" else 0,
        "lt_prefix": 1 if "abc" < "abcd" else 0,
        "lt_empty": 1 if "" < "a" else 0,
        # Greater than
        "gt_abc_def": 1 if "abc" > "def" else 0,
        "gt_def_abc": 1 if "def" > "abc" else 0,
        "gt_same": 1 if "abc" > "abc" else 0,
        "gt_longer": 1 if "abcd" > "abc" else 0,
        # Less or equal
        "le_abc_def": 1 if "abc" <= "def" else 0,
        "le_same": 1 if "abc" <= "abc" else 0,
        "le_def_abc": 1 if "def" <= "abc" else 0,
        # Greater or equal
        "ge_abc_def": 1 if "abc" >= "def" else 0,
        "ge_same": 1 if "abc" >= "abc" else 0,
        "ge_def_abc": 1 if "def" >= "abc" else 0
    };
}

na {
    def str_cmp_na() -> dict[str, any] {
        return {
            # Less than
            "lt_abc_def": 1 if "abc" < "def" else 0,
            "lt_def_abc": 1 if "def" < "abc" else 0,
            "lt_same": 1 if "abc" < "abc" else 0,
            "lt_prefix": 1 if "abc" < "abcd" else 0,
            "lt_empty": 1 if "" < "a" else 0,
            # Greater than
            "gt_abc_def": 1 if "abc" > "def" else 0,
            "gt_def_abc": 1 if "def" > "abc" else 0,
            "gt_same": 1 if "abc" > "abc" else 0,
            "gt_longer": 1 if "abcd" > "abc" else 0,
            # Less or equal
            "le_abc_def": 1 if "abc" <= "def" else 0,
            "le_same": 1 if "abc" <= "abc" else 0,
            "le_def_abc": 1 if "def" <= "abc" else 0,
            # Greater or equal
            "ge_abc_def": 1 if "abc" >= "def" else 0,
            "ge_same": 1 if "abc" >= "abc" else 0,
            "ge_def_abc": 1 if "def" >= "abc" else 0
        };
    }
}
