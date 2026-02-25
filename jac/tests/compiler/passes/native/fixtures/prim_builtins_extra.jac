"""Extra builtin function primitives: hex, oct, bin, round, float, str(float),
list.count.

Cross-backend equivalence fixture — Python reference + native implementation.
"""

def builtins_extra_py() -> dict {
    return {
        # hex
        "hex_0": hex(0),
        "hex_255": hex(255),
        "hex_16": hex(16),
        "hex_neg": hex(-1),
        # oct
        "oct_0": oct(0),
        "oct_8": oct(8),
        "oct_255": oct(255),
        "oct_neg": oct(-1),
        # bin
        "bin_0": bin(0),
        "bin_1": bin(1),
        "bin_10": bin(10),
        "bin_255": bin(255),
        "bin_neg": bin(-1),
        # round
        "round_int": round(5),
        "round_float_down": round(3.2),
        "round_float_up": round(3.7),
        "round_neg": round(-2.3),
        # float from string
        "float_from_str": float("3.14"),
        "float_from_int_str": float("42"),
        "float_neg_str": float("-1.5"),
        # str from float
        "str_from_int": str(42),
        "str_from_neg": str(-17),
        # list count
        "list_count_one": [10, 20, 30, 20].count(20),
        "list_count_zero": [10, 20, 30].count(99),
        "list_count_many": [1, 1, 1, 2, 1].count(1)
    };
}

na {
    def builtins_extra_na() -> dict[str, any] {
        # list count
        lst1: list[int] = [10, 20, 30, 20];
        lst2: list[int] = [10, 20, 30];
        lst3: list[int] = [1, 1, 1, 2, 1];

        return {
            # hex
            "hex_0": hex(0),
            "hex_255": hex(255),
            "hex_16": hex(16),
            "hex_neg": hex(-1),
            # oct
            "oct_0": oct(0),
            "oct_8": oct(8),
            "oct_255": oct(255),
            "oct_neg": oct(-1),
            # bin
            "bin_0": bin(0),
            "bin_1": bin(1),
            "bin_10": bin(10),
            "bin_255": bin(255),
            "bin_neg": bin(-1),
            # round
            "round_int": round(5),
            "round_float_down": round(3.2),
            "round_float_up": round(3.7),
            "round_neg": round(-2.3),
            # float from string
            "float_from_str": float("3.14"),
            "float_from_int_str": float("42"),
            "float_neg_str": float("-1.5"),
            # str from float
            "str_from_int": str(42),
            "str_from_neg": str(-17),
            # list count
            "list_count_one": lst1.count(20),
            "list_count_zero": lst2.count(99),
            "list_count_many": lst3.count(1)
        };
    }
}
