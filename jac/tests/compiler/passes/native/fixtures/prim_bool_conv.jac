"""Bool conversion primitives: bool() on int, float, string.

Cross-backend equivalence fixture — Python reference + native implementation.
"""

def bool_conv_py() -> dict {
    return {
        # bool(int)
        "bool_zero": 1 if bool(0) else 0,
        "bool_one": 1 if bool(1) else 0,
        "bool_neg": 1 if bool(-1) else 0,
        "bool_big": 1 if bool(42) else 0,
        # bool(float)
        "bool_fzero": 1 if bool(0.0) else 0,
        "bool_fone": 1 if bool(1.0) else 0,
        "bool_fneg": 1 if bool(-0.5) else 0,
        # bool(str)
        "bool_empty": 1 if bool("") else 0,
        "bool_nonempty": 1 if bool("hello") else 0,
        "bool_space": 1 if bool(" ") else 0
    };
}

na {
    def bool_conv_na() -> dict[str, any] {
        return {
            # bool(int)
            "bool_zero": 1 if bool(0) else 0,
            "bool_one": 1 if bool(1) else 0,
            "bool_neg": 1 if bool(-1) else 0,
            "bool_big": 1 if bool(42) else 0,
            # bool(float)
            "bool_fzero": 1 if bool(0.0) else 0,
            "bool_fone": 1 if bool(1.0) else 0,
            "bool_fneg": 1 if bool(-0.5) else 0,
            # bool(str)
            "bool_empty": 1 if bool("") else 0,
            "bool_nonempty": 1 if bool("hello") else 0,
            "bool_space": 1 if bool(" ") else 0
        };
    }
}
