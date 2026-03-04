"""Int emitter: operators, named methods, bool subtype.

Cross-backend equivalence fixture.
"""

# --- Int arithmetic and bitwise operators ---
def int_py() -> dict {
    a: int = 17;
    b: int = 5;

    # bool truthiness
    f_none: bool = bool(None);
    f_zero: bool = bool(0);
    f_empty_str: bool = bool("");
    f_false: bool = bool(False);
    f_zero_float: bool = bool(0.0);
    f_empty_list: bool = bool([]);
    f_empty_dict: bool = bool({});
    t_one: bool = bool(1);
    t_str: bool = bool("hello");
    t_true: bool = bool(True);
    t_list: bool = bool([1, 2]);
    t_dict: bool = bool({"a": 1});
    t_neg: bool = bool(-1);
    t_float: bool = bool(3.14);

    # bool bitwise
    ba: bool = True;
    bb: bool = False;
    and_tf: bool = ba & bb;
    and_tt: bool = ba & ba;
    and_ff: bool = bb & bb;
    or_tf: bool = ba | bb;
    or_tt: bool = ba | ba;
    or_ff: bool = bb | bb;
    xor_tf: bool = ba ^ bb;
    xor_tt: bool = ba ^ ba;
    xor_ff: bool = bb ^ bb;
    and_val: int = int(ba & bb);
    or_val: int = int(ba | bb);
    xor_val: int = int(ba ^ bb);

    # int extra (as_integer_ratio, to_bytes, from_bytes)
    n: int = 42;
    ratio: tuple = n.as_integer_ratio();
    ratio_list: list = list(ratio);
    conj: int = n.conjugate();
    tb_big: list = list((1024).to_bytes(2, "big"));
    tb_little: list = list((1024).to_bytes(2, "little"));
    tb_zero: list = list((0).to_bytes(1, "big"));
    tb_255: list = list((255).to_bytes(1, "big"));
    fb_big: int = int.from_bytes([4, 0], "big");
    fb_little: int = int.from_bytes([0, 4], "big");
    fb_single: int = int.from_bytes([255], "big");

    return {
        # arithmetic
        "int_add": a + b,
        "int_sub": a - b,
        "int_mul": a * b,
        "int_truediv": a / b,
        "int_floordiv": a // b,
        "int_mod": a % b,
        "int_pow": 2 ** 10,
        "int_neg": -a,
        "int_pos": +a,
        # bitwise
        "int_bw_and": a & b,
        "int_bw_or": a | b,
        "int_bw_xor": a ^ b,
        "int_lshift": b << 2,
        "int_rshift": a >> 2,
        "int_bw_not": ~a,
        # comparisons
        "int_eq": a == 17,
        "int_ne": a != b,
        "int_lt": b < a,
        "int_gt": a > b,
        "int_le": b <= 5,
        "int_ge": a >= 17,
        # named methods
        "conjugate_pos": (42).conjugate(),
        "conjugate_neg": (-7).conjugate(),
        "conjugate_zero": (0).conjugate(),
        "bitlen_0": (0).bit_length(),
        "bitlen_1": (1).bit_length(),
        "bitlen_2": (2).bit_length(),
        "bitlen_3": (3).bit_length(),
        "bitlen_255": (255).bit_length(),
        "bitlen_256": (256).bit_length(),
        "bitlen_neg1": (-1).bit_length(),
        "bitlen_neg128": (-128).bit_length(),
        "bitcnt_0": (0).bit_count(),
        "bitcnt_1": (1).bit_count(),
        "bitcnt_7": (7).bit_count(),
        "bitcnt_255": (255).bit_count(),
        "bitcnt_256": (256).bit_count(),
        "bitcnt_neg1": (-1).bit_count(),
        "bitcnt_neg7": (-7).bit_count(),
        # bool() conversions
        "bool_zero": 1 if bool(0) else 0,
        "bool_one": 1 if bool(1) else 0,
        "bool_neg": 1 if bool(-1) else 0,
        "bool_big": 1 if bool(42) else 0,
        "bool_fzero": 1 if bool(0.0) else 0,
        "bool_fone": 1 if bool(1.0) else 0,
        "bool_fneg": 1 if bool(-0.5) else 0,
        "bool_empty": 1 if bool("") else 0,
        "bool_nonempty": 1 if bool("hello") else 0,
        "bool_space": 1 if bool(" ") else 0,
        # bool truthiness
        "f_none": f_none, "f_zero": f_zero, "f_empty_str": f_empty_str,
        "f_false": f_false, "f_zero_float": f_zero_float,
        "f_empty_list": f_empty_list, "f_empty_dict": f_empty_dict,
        "t_one": t_one, "t_str": t_str, "t_true": t_true,
        "t_list": t_list, "t_dict": t_dict, "t_neg": t_neg,
        "t_float": t_float,
        # bool bitwise
        "and_tf": and_tf, "and_tt": and_tt, "and_ff": and_ff,
        "or_tf": or_tf, "or_tt": or_tt, "or_ff": or_ff,
        "xor_tf": xor_tf, "xor_tt": xor_tt, "xor_ff": xor_ff,
        "and_val": and_val, "or_val": or_val, "xor_val": xor_val,
        # int extra
        "ratio": ratio_list,
        "ratio_0": ratio_list[0], "ratio_1": ratio_list[1],
        "conj": conj,
        "tb_big": tb_big, "tb_little": tb_little,
        "tb_zero": tb_zero, "tb_255": tb_255,
        "fb_big": fb_big, "fb_little": fb_little,
        "fb_single": fb_single,
        # to_bytes (ord of single-byte results)
        "tb_65": ord((65).to_bytes(1, "big")),
        "tb_255": ord((255).to_bytes(1, "big")),
        # from_bytes round-trip
        "fb_rt_258": int.from_bytes((258).to_bytes(2, "big"), "big"),
        "fb_rt_65": int.from_bytes((65).to_bytes(1, "big"), "big")
    };
}

cl def int_cl() -> dict {
    a: int = 17;
    b: int = 5;

    ba: bool = True;
    bb: bool = False;
    and_tf: bool = ba & bb;
    and_tt: bool = ba & ba;
    and_ff: bool = bb & bb;
    or_tf: bool = ba | bb;
    or_tt: bool = ba | ba;
    or_ff: bool = bb | bb;
    xor_tf: bool = ba ^ bb;
    xor_tt: bool = ba ^ ba;
    xor_ff: bool = bb ^ bb;
    and_val: int = int(ba & bb);
    or_val: int = int(ba | bb);
    xor_val: int = int(ba ^ bb);

    n: int = 42;
    ratio: tuple = n.as_integer_ratio();
    ratio_list: list = list(ratio);
    conj: int = n.conjugate();
    tb_big: list = list((1024).to_bytes(2, "big"));
    tb_little: list = list((1024).to_bytes(2, "little"));
    tb_zero: list = list((0).to_bytes(1, "big"));
    tb_255: list = list((255).to_bytes(1, "big"));
    fb_big: int = int.from_bytes([4, 0], "big");
    fb_little: int = int.from_bytes([0, 4], "big");
    fb_single: int = int.from_bytes([255], "big");

    return {
        "int_add": a + b,
        "int_sub": a - b,
        "int_mul": a * b,
        "int_truediv": a / b,
        "int_floordiv": a // b,
        "int_pow": 2 ** 10,
        "int_neg": -a,
        "int_pos": +a,
        "int_bw_and": a & b,
        "int_bw_or": a | b,
        "int_bw_xor": a ^ b,
        "int_lshift": b << 2,
        "int_rshift": a >> 2,
        "int_bw_not": ~a,
        "int_eq": a == 17,
        "int_ne": a != b,
        "int_lt": b < a,
        "int_gt": a > b,
        "int_le": b <= 5,
        "int_ge": a >= 17,
        "conjugate_pos": (42).conjugate(),
        "conjugate_neg": (-7).conjugate(),
        "conjugate_zero": (0).conjugate(),
        "bitlen_0": (0).bit_length(),
        "bitlen_1": (1).bit_length(),
        "bitlen_2": (2).bit_length(),
        "bitlen_3": (3).bit_length(),
        "bitlen_255": (255).bit_length(),
        "bitlen_256": (256).bit_length(),
        "bitlen_neg1": (-1).bit_length(),
        "bitlen_neg128": (-128).bit_length(),
        "bool_zero": 1 if bool(0) else 0,
        "bool_one": 1 if bool(1) else 0,
        "bool_neg": 1 if bool(-1) else 0,
        "bool_big": 1 if bool(42) else 0,
        "bool_fzero": 1 if bool(0.0) else 0,
        "bool_fone": 1 if bool(1.0) else 0,
        "bool_fneg": 1 if bool(-0.5) else 0,
        "bool_empty": 1 if bool("") else 0,
        "bool_nonempty": 1 if bool("hello") else 0,
        "bool_space": 1 if bool(" ") else 0,
        "and_tf": and_tf, "and_tt": and_tt, "and_ff": and_ff,
        "or_tf": or_tf, "or_tt": or_tt, "or_ff": or_ff,
        "xor_tf": xor_tf, "xor_tt": xor_tt, "xor_ff": xor_ff,
        "and_val": and_val, "or_val": or_val, "xor_val": xor_val,
        "ratio": ratio_list,
        "conj": conj,
        "tb_big": tb_big, "tb_little": tb_little,
        "tb_zero": tb_zero, "tb_255": tb_255,
        "fb_big": fb_big, "fb_little": fb_little,
        "fb_single": fb_single
    };
}

na {
    def int_na() -> dict[str, any] {
        a: int = 17;
        b: int = 5;

        # bool truthiness
        f_zero: int = 1 if bool(0) else 0;
        f_empty_str: int = 1 if bool("") else 0;
        f_zero_float: int = 1 if bool(0.0) else 0;
        f_empty_list: int = 1 if bool([]) else 0;
        f_empty_dict: int = 1 if bool({}) else 0;
        t_one: int = 1 if bool(1) else 0;
        t_str: int = 1 if bool("hello") else 0;
        t_list: int = 1 if bool([1, 2]) else 0;
        t_dict: int = 1 if bool({"a": 1}) else 0;
        t_neg: int = 1 if bool(-1) else 0;
        t_float: int = 1 if bool(3.14) else 0;

        # bool bitwise
        ba: bool = True;
        bb: bool = False;
        and_tf: int = 1 if (ba & bb) else 0;
        and_tt: int = 1 if (ba & ba) else 0;
        and_ff: int = 1 if (bb & bb) else 0;
        or_tf: int = 1 if (ba | bb) else 0;
        or_tt: int = 1 if (ba | ba) else 0;
        or_ff: int = 1 if (bb | bb) else 0;
        xor_tf: int = 1 if (ba ^ bb) else 0;
        xor_tt: int = 1 if (ba ^ ba) else 0;
        xor_ff: int = 1 if (bb ^ bb) else 0;
        and_val: int = int(ba & bb);
        or_val: int = int(ba | bb);
        xor_val: int = int(ba ^ bb);

        return {
            "int_add": a + b,
            "int_sub": a - b,
            "int_mul": a * b,
            "int_floordiv": a // b,
            "int_mod": a % b,
            "int_pow": 2 ** 10,
            "int_neg": 0 - a,
            "int_bw_and": a & b,
            "int_bw_or": a | b,
            "int_bw_xor": a ^ b,
            "int_lshift": b << 2,
            "int_rshift": a >> 2,
            "int_eq": 1 if a == 17 else 0,
            "int_ne": 1 if a != b else 0,
            "int_lt": 1 if b < a else 0,
            "int_gt": 1 if a > b else 0,
            "int_le": 1 if b <= 5 else 0,
            "int_ge": 1 if a >= 17 else 0,
            "conjugate_pos": (42).conjugate(),
            "conjugate_neg": (-7).conjugate(),
            "conjugate_zero": (0).conjugate(),
            "bitlen_0": (0).bit_length(),
            "bitlen_1": (1).bit_length(),
            "bitlen_2": (2).bit_length(),
            "bitlen_3": (3).bit_length(),
            "bitlen_255": (255).bit_length(),
            "bitlen_256": (256).bit_length(),
            "bitlen_neg1": (-1).bit_length(),
            "bitlen_neg128": (-128).bit_length(),
            "bitcnt_0": (0).bit_count(),
            "bitcnt_1": (1).bit_count(),
            "bitcnt_7": (7).bit_count(),
            "bitcnt_255": (255).bit_count(),
            "bitcnt_256": (256).bit_count(),
            "bitcnt_neg1": (-1).bit_count(),
            "bitcnt_neg7": (-7).bit_count(),
            "bool_zero": 1 if bool(0) else 0,
            "bool_one": 1 if bool(1) else 0,
            "bool_neg": 1 if bool(-1) else 0,
            "bool_big": 1 if bool(42) else 0,
            "bool_fzero": 1 if bool(0.0) else 0,
            "bool_fone": 1 if bool(1.0) else 0,
            "bool_fneg": 1 if bool(-0.5) else 0,
            "bool_empty": 1 if bool("") else 0,
            "bool_nonempty": 1 if bool("hello") else 0,
            "bool_space": 1 if bool(" ") else 0,
            "f_zero": f_zero, "f_empty_str": f_empty_str,
            "f_zero_float": f_zero_float,
            "f_empty_list": f_empty_list, "f_empty_dict": f_empty_dict,
            "t_one": t_one, "t_str": t_str,
            "t_list": t_list, "t_dict": t_dict, "t_neg": t_neg,
            "t_float": t_float,
            "and_tf": and_tf, "and_tt": and_tt, "and_ff": and_ff,
            "or_tf": or_tf, "or_tt": or_tt, "or_ff": or_ff,
            "xor_tf": xor_tf, "xor_tt": xor_tt, "xor_ff": xor_ff,
            "and_val": and_val, "or_val": or_val, "xor_val": xor_val,
            "ratio_0": (42).as_integer_ratio()[0],
            "ratio_1": (42).as_integer_ratio()[1],
            # to_bytes (test with non-zero bytes to avoid strlen null-term issues)
            "tb_65": ord((65).to_bytes(1, "big")),
            "tb_255": ord((255).to_bytes(1, "big")),
            # from_bytes round-trip (avoids bytes vs i8* type mismatch)
            "fb_rt_258": int.from_bytes((258).to_bytes(2, "big"), "big"),
            "fb_rt_65": int.from_bytes((65).to_bytes(1, "big"), "big")
        };
    }
}
