"""Builtin function primitives: len, abs, round, min, max, chr, ord, hex, oct, bin, pow, divmod, type conversions."""

def builtins_py() -> dict {
    nums: list = [1, 2, 3, 4, 5];
    s: str = "hello";

    return {
        # Length
        "len_list": len(nums),
        "len_str": len(s),

        # Math
        "abs_pos": abs(5),
        "abs_neg": abs(-7),
        "round_up": round(3.7),
        "round_down": round(3.2),
        "min_args": min(3, 1, 2),
        "max_args": max(3, 1, 2),
        "pow_result": pow(2, 10),
        "divmod_result": list(divmod(17, 5)),

        # Sequence
        "reversed_list": list(reversed(nums)),
        "any_true": any([0, 1, 0]),
        "any_false": any([0, 0, 0]),
        "all_true": all([1, 1, 1]),
        "all_false": all([1, 0, 1]),

        # Character / encoding
        "chr_A": chr(65),
        "chr_z": chr(122),
        "ord_A": ord("A"),
        "ord_z": ord("z"),
        "hex_255": hex(255),
        "hex_0": hex(0),
        "oct_8": oct(8),
        "oct_0": oct(0),
        "bin_5": bin(5),
        "bin_0": bin(0),

        # Type conversions
        "str_from_int": str(42),
        "str_from_float": str(3.5),
        "int_from_str": int("42"),
        "int_from_float": int(3.9),
        "float_from_str": float("3.14"),
        "float_from_int": float(5),
        "bool_true": bool(1),
        "bool_false": bool(0),
        "bool_empty_str": bool("")
    };
}

cl def builtins_cl() -> dict {
    nums: list = [1, 2, 3, 4, 5];
    s: str = "hello";

    return {
        # Length
        "len_list": len(nums),
        "len_str": len(s),

        # Math
        "abs_pos": abs(5),
        "abs_neg": abs(-7),
        "round_up": round(3.7),
        "round_down": round(3.2),
        "min_args": min(3, 1, 2),
        "max_args": max(3, 1, 2),
        "pow_result": pow(2, 10),
        "divmod_result": list(divmod(17, 5)),

        # Sequence
        "reversed_list": list(reversed(nums)),
        "any_true": any([0, 1, 0]),
        "any_false": any([0, 0, 0]),
        "all_true": all([1, 1, 1]),
        "all_false": all([1, 0, 1]),

        # Character / encoding
        "chr_A": chr(65),
        "chr_z": chr(122),
        "ord_A": ord("A"),
        "ord_z": ord("z"),
        "hex_255": hex(255),
        "hex_0": hex(0),
        "oct_8": oct(8),
        "oct_0": oct(0),
        "bin_5": bin(5),
        "bin_0": bin(0),

        # Type conversions
        "str_from_int": str(42),
        "str_from_float": str(3.5),
        "int_from_str": int("42"),
        "int_from_float": int(3.9),
        "float_from_str": float("3.14"),
        "float_from_int": float(5),
        "bool_true": bool(1),
        "bool_false": bool(0),
        "bool_empty_str": bool("")
    };
}
