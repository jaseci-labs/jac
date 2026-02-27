"""Builtin function primitives: abs, min, max, pow, chr, ord, str, int, len.

Cross-backend equivalence fixture — Python reference + native implementation.
"""

def builtins_py() -> dict {
    return {
        "abs_pos": abs(5),
        "abs_neg": abs(-7),
        "min_two": min(3, 7),
        "max_two": max(3, 7),
        "pow_int": pow(2, 10),
        "chr_65": chr(65),
        "chr_97": chr(97),
        "ord_a": ord("a"),
        "ord_A": ord("A"),
        "int_from_str": int("42"),
        "int_from_neg_str": int("-17"),
        "len_str": len("hello"),
        "len_empty": len(""),
        "len_list": len([1, 2, 3])
    };
}

na {
    def builtins_na() -> dict[str, any] {
        items: list[int] = [1, 2, 3];
        return {
            "abs_pos": abs(5),
            "abs_neg": abs(-7),
            "min_two": min(3, 7),
            "max_two": max(3, 7),
            "pow_int": pow(2, 10),
            "chr_65": chr(65),
            "chr_97": chr(97),
            "ord_a": ord("a"),
            "ord_A": ord("A"),
            "int_from_str": int("42"),
            "int_from_neg_str": int("-17"),
            "len_str": len("hello"),
            "len_empty": len(""),
            "len_list": len(items)
        };
    }
}
