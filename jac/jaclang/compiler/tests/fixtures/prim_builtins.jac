"""Builtin function primitives: len, abs, round, min, max, chr, ord, hex, oct, bin, pow, divmod,
type conversions, sorted, reversed, list/set conversion, sum, any, all, format, slice, bool truthiness.

Cross-backend equivalence fixture.
"""

# --- Builtin functions ---
def builtins_py() -> dict {
    nums: list = [1, 2, 3, 4, 5];
    s: str = "hello";

    # prim_builtins: len, abs, round, min, max, pow, divmod, chr, ord, hex, oct, bin, type conversions
    d_extra: dict = dict([["a", 1], ["b", 2]]);
    set_sorted: list = sorted(list(set([3, 1, 2, 1])));
    t_list: list = list(tuple([10, 20, 30]));
    fs_list: list = sorted(list(frozenset([5, 3, 5, 1])));
    by_list: list = list(bytes([65, 66, 67]));
    ba_list: list = list(bytearray([68, 69]));
    c = complex(3, 4);
    c_eq: bool = c == complex(3, 4);

    # prim_builtins_extra2: sum, any, all, divmod
    sum_empty: int = sum([]);
    sum_one: int = sum([42]);
    sum_many: int = sum([1, 2, 3, 4, 5]);
    sum_neg: int = sum([-1, 0, 1]);

    any_empty: int = 1 if any([]) else 0;
    any_all_false: int = 1 if any([0, 0, 0]) else 0;
    any_one_true: int = 1 if any([0, 0, 1]) else 0;
    any_all_true: int = 1 if any([1, 2, 3]) else 0;

    all_empty: int = 1 if all([]) else 0;
    all_all_true: int = 1 if all([1, 2, 3]) else 0;
    all_one_false: int = 1 if all([1, 0, 3]) else 0;
    all_all_false: int = 1 if all([0, 0, 0]) else 0;

    dm1: tuple[int, int] = divmod(17, 5);
    dm1_q: int = dm1[0];
    dm1_r: int = dm1[1];
    dm2: tuple[int, int] = divmod(10, 3);
    dm2_q: int = dm2[0];
    dm2_r: int = dm2[1];
    dm3: tuple[int, int] = divmod(7, 1);
    dm3_q: int = dm3[0];
    dm3_r: int = dm3[1];

    # prim_builtin_sort: sorted, reversed
    sort_nums: list[int] = [3, 1, 4, 1, 5, 9, 2, 6];
    sort_desc: list[int] = [5, 4, 3, 2, 1];
    sort_single: list[int] = [42];
    sort_asc: list[int] = [1, 2, 3, 4, 5];

    s_nums: list[int] = sorted(sort_nums);
    s_desc: list[int] = sorted(sort_desc);
    s_single: list[int] = sorted(sort_single);
    s_asc: list[int] = sorted(sort_asc);

    r_nums: list[int] = list(reversed(sort_nums));
    r_desc: list[int] = list(reversed(sort_desc));
    r_single: list[int] = list(reversed(sort_single));

    # prim_builtin_convert: list/set conversion
    conv_list: list[int] = [1, 2, 3];
    conv_set: set[int] = {1, 2, 3};
    ll: list[int] = list(conv_list);
    ss: set[int] = set(conv_set);
    ls: list[int] = list(conv_set);
    sl: set[int] = set(conv_list);

    # format builtin
    f1: str = format(42);
    f2: str = format(3.14159);
    f3: str = format(3.14159, ".2f");
    f4: str = format(1000, ".1f");
    f5: str = format(42, "d");
    f6: str = format(255, "b");
    f7: str = format(255, "o");
    f8: str = format(255, "x");
    f9: str = format(255, "X");
    f10: str = format(42, "10d");
    f11: str = format("hi", "<10s");
    f12: str = format("hi", ">10s");

    # slice builtin
    sl1 = slice(5);
    s1_stop: int = sl1.stop;
    s1_start_none: bool = sl1.start is None;
    s1_step_none: bool = sl1.step is None;
    sl2 = slice(1, 5);
    s2_start: int = sl2.start;
    s2_stop: int = sl2.stop;
    s2_step_none: bool = sl2.step is None;
    sl3 = slice(0, 10, 2);
    s3_start: int = sl3.start;
    s3_stop: int = sl3.stop;
    s3_step: int = sl3.step;

    return {
        # prim_builtins
        "len_list": len(nums),
        "len_str": len(s),
        "len_empty": len(""),
        "abs_pos": abs(5),
        "abs_neg": abs(-7),
        "round_up": round(3.7),
        "round_down": round(3.2),
        "min_args": min(3, 1, 2),
        "max_args": max(3, 1, 2),
        "min_two": min(3, 7),
        "max_two": max(3, 7),
        "pow_result": pow(2, 10),
        "pow_int": pow(2, 10),
        "divmod_result": list(divmod(17, 5)),
        "reversed_list": list(reversed(nums)),
        "any_true": any([0, 1, 0]),
        "any_false": any([0, 0, 0]),
        "all_true": all([1, 1, 1]),
        "all_false": all([1, 0, 1]),
        "chr_A": chr(65),
        "chr_z": chr(122),
        "chr_65": chr(65),
        "chr_97": chr(97),
        "ord_A": ord("A"),
        "ord_z": ord("z"),
        "ord_a": ord("a"),
        "hex_255": hex(255),
        "hex_0": hex(0),
        "hex_16": hex(16),
        "hex_neg": hex(-1),
        "oct_8": oct(8),
        "oct_0": oct(0),
        "oct_255": oct(255),
        "oct_neg": oct(-1),
        "bin_5": bin(5),
        "bin_0": bin(0),
        "bin_1": bin(1),
        "bin_10": bin(10),
        "bin_255": bin(255),
        "bin_neg": bin(-1),
        "str_from_int": str(42),
        "str_from_float": str(3.5),
        "str_from_neg": str(-17),
        "int_from_str": int("42"),
        "int_from_float": int(3.9),
        "int_from_neg_str": int("-17"),
        "float_from_str": float("3.14"),
        "float_from_int": float(5),
        "float_from_int_str": float("42"),
        "float_neg_str": float("-1.5"),
        "bool_true": bool(1),
        "bool_false": bool(0),
        "bool_empty_str": bool(""),
        "list_count_one": [10, 20, 30, 20].count(20),
        "list_count_zero": [10, 20, 30].count(99),
        "list_count_many": [1, 1, 1, 2, 1].count(1),
        "round_int": round(5),
        "round_float_down": round(3.2),
        "round_float_up": round(3.7),
        "round_neg": round(-2.3),
        # prim_builtins_extra type constructors
        "dict_from_pairs": d_extra,
        "set_from_list": set_sorted,
        "tuple_as_list": t_list,
        "frozenset_as_list": fs_list,
        "bytes_as_list": by_list,
        "bytearray_as_list": ba_list,
        "complex_eq": c_eq,
        # prim_builtins_extra2
        "sum_empty": sum_empty, "sum_one": sum_one,
        "sum_many": sum_many, "sum_neg": sum_neg,
        "any_empty": any_empty, "any_all_false": any_all_false,
        "any_one_true": any_one_true, "any_all_true": any_all_true,
        "all_empty": all_empty, "all_all_true": all_all_true,
        "all_one_false": all_one_false, "all_all_false": all_all_false,
        "dm1_q": dm1_q, "dm1_r": dm1_r,
        "dm2_q": dm2_q, "dm2_r": dm2_r,
        "dm3_q": dm3_q, "dm3_r": dm3_r,
        # prim_builtin_sort
        "s_len": len(s_nums),
        "s0": s_nums[0], "s1": s_nums[1], "s2": s_nums[2], "s3": s_nums[3],
        "s4": s_nums[4], "s5": s_nums[5], "s6": s_nums[6], "s7": s_nums[7],
        "s_desc0": s_desc[0], "s_desc4": s_desc[4],
        "s_single0": s_single[0],
        "s_asc0": s_asc[0], "s_asc4": s_asc[4],
        "r_len": len(r_nums),
        "r0": r_nums[0], "r7": r_nums[7],
        "r_desc0": r_desc[0], "r_desc4": r_desc[4],
        "r_single0": r_single[0],
        "orig0": sort_nums[0],
        "desc0": sort_desc[0],
        # prim_builtin_convert
        "ll_len": len(ll), "ll0": ll[0], "ll2": ll[2],
        "ss_len": len(ss),
        "ls_len": len(ls), "ls_sum": sum(ls),
        "sl_len": len(sl),
        # format builtin
        "fmt_basic_int": f1, "fmt_basic_float": f2,
        "fmt_fixed_2": f3, "fmt_fixed_1": f4,
        "fmt_int_d": f5,
        "fmt_bin": f6, "fmt_oct": f7, "fmt_hex": f8, "fmt_hex_upper": f9,
        "fmt_width_int": f10, "fmt_left_str": f11, "fmt_right_str": f12,
        # slice builtin
        "s1_stop": s1_stop, "s1_start_none": s1_start_none,
        "s1_step_none": s1_step_none,
        "s2_start": s2_start, "s2_stop": s2_stop,
        "s2_step_none": s2_step_none,
        "s3_start": s3_start, "s3_stop": s3_stop, "s3_step": s3_step,
        # float abs/min/max from prim_float_cmp
        "abs_neg_float": abs(-3.14),
        "abs_pos_float": abs(3.14),
        "min_float": min(3.5, 1.2),
        "max_float": max(3.5, 1.2),
        # NA builtin extras
        "fmt_int": format(42, "d"),
        "fmt_hex": format(255, "x"),
        "fmt_oct": format(255, "o"),
        "hash_int": hash(42),
        "repr_int": repr(42),
        "repr_neg": repr(-17),
        "ascii_str": ascii("hello"),
        "fs_na_len": len(frozenset([1, 2, 3])),
        "ba_len": len(bytearray([68, 69]))
    };
}

cl def builtins_cl() -> dict {
    nums: list = [1, 2, 3, 4, 5];
    s: str = "hello";

    d_extra: dict = dict([["a", 1], ["b", 2]]);
    set_sorted: list = sorted(list(set([3, 1, 2, 1])));
    t_list: list = list(tuple([10, 20, 30]));
    fs_list: list = sorted(list(frozenset([5, 3, 5, 1])));
    by_list: list = list(bytes([65, 66, 67]));
    ba_list: list = list(bytearray([68, 69]));
    c = complex(3, 4);
    c_eq: bool = c == complex(3, 4);

    sum_empty: int = sum([]);
    sum_one: int = sum([42]);
    sum_many: int = sum([1, 2, 3, 4, 5]);
    sum_neg: int = sum([-1, 0, 1]);

    any_empty: int = 1 if any([]) else 0;
    any_all_false: int = 1 if any([0, 0, 0]) else 0;
    any_one_true: int = 1 if any([0, 0, 1]) else 0;
    any_all_true: int = 1 if any([1, 2, 3]) else 0;

    all_empty: int = 1 if all([]) else 0;
    all_all_true: int = 1 if all([1, 2, 3]) else 0;
    all_one_false: int = 1 if all([1, 0, 3]) else 0;
    all_all_false: int = 1 if all([0, 0, 0]) else 0;

    dm1: tuple[int, int] = divmod(17, 5);
    dm1_q: int = dm1[0];
    dm1_r: int = dm1[1];
    dm2: tuple[int, int] = divmod(10, 3);
    dm2_q: int = dm2[0];
    dm2_r: int = dm2[1];
    dm3: tuple[int, int] = divmod(7, 1);
    dm3_q: int = dm3[0];
    dm3_r: int = dm3[1];

    sort_nums: list[int] = [3, 1, 4, 1, 5, 9, 2, 6];
    sort_desc: list[int] = [5, 4, 3, 2, 1];
    sort_single: list[int] = [42];
    sort_asc: list[int] = [1, 2, 3, 4, 5];

    s_nums: list[int] = sorted(sort_nums);
    s_desc: list[int] = sorted(sort_desc);
    s_single: list[int] = sorted(sort_single);
    s_asc: list[int] = sorted(sort_asc);

    r_nums: list[int] = list(reversed(sort_nums));
    r_desc: list[int] = list(reversed(sort_desc));
    r_single: list[int] = list(reversed(sort_single));

    conv_list: list[int] = [1, 2, 3];
    conv_set: set = set([1, 2, 3]);
    ll: list[int] = list(conv_list);
    ss: set = set(conv_set);
    ls: list[int] = list(conv_set);
    sl: set = set(conv_list);

    f1: str = format(42);
    f2: str = format(3.14159);
    f3: str = format(3.14159, ".2f");
    f4: str = format(1000, ".1f");
    f5: str = format(42, "d");
    f6: str = format(255, "b");
    f7: str = format(255, "o");
    f8: str = format(255, "x");
    f9: str = format(255, "X");
    f10: str = format(42, "10d");
    f11: str = format("hi", "<10s");
    f12: str = format("hi", ">10s");

    sl1 = slice(5);
    s1_stop: int = sl1.stop;
    s1_start_none: bool = sl1.start is None;
    s1_step_none: bool = sl1.step is None;
    sl2 = slice(1, 5);
    s2_start: int = sl2.start;
    s2_stop: int = sl2.stop;
    s2_step_none: bool = sl2.step is None;
    sl3 = slice(0, 10, 2);
    s3_start: int = sl3.start;
    s3_stop: int = sl3.stop;
    s3_step: int = sl3.step;

    return {
        "len_list": len(nums),
        "len_str": len(s),
        "abs_pos": abs(5),
        "abs_neg": abs(-7),
        "round_up": round(3.7),
        "round_down": round(3.2),
        "min_args": min(3, 1, 2),
        "max_args": max(3, 1, 2),
        "pow_result": pow(2, 10),
        "divmod_result": list(divmod(17, 5)),
        "reversed_list": list(reversed(nums)),
        "any_true": any([0, 1, 0]),
        "any_false": any([0, 0, 0]),
        "all_true": all([1, 1, 1]),
        "all_false": all([1, 0, 1]),
        "chr_A": chr(65),
        "chr_z": chr(122),
        "ord_A": ord("A"),
        "ord_z": ord("z"),
        "hex_255": hex(255),
        "hex_0": hex(0),
        "hex_16": hex(16),
        "hex_neg": hex(-1),
        "oct_8": oct(8),
        "oct_0": oct(0),
        "oct_255": oct(255),
        "oct_neg": oct(-1),
        "bin_5": bin(5),
        "bin_0": bin(0),
        "bin_1": bin(1),
        "bin_10": bin(10),
        "bin_255": bin(255),
        "bin_neg": bin(-1),
        "str_from_int": str(42),
        "str_from_float": str(3.5),
        "str_from_neg": str(-17),
        "int_from_str": int("42"),
        "int_from_float": int(3.9),
        "float_from_str": float("3.14"),
        "float_from_int": float(5),
        "float_from_int_str": float("42"),
        "float_neg_str": float("-1.5"),
        "bool_true": bool(1),
        "bool_false": bool(0),
        "bool_empty_str": bool(""),
        "list_count_one": [10, 20, 30, 20].count(20),
        "list_count_zero": [10, 20, 30].count(99),
        "list_count_many": [1, 1, 1, 2, 1].count(1),
        "round_int": round(5),
        "round_float_down": round(3.2),
        "round_float_up": round(3.7),
        "round_neg": round(-2.3),
        "dict_from_pairs": d_extra,
        "set_from_list": set_sorted,
        "tuple_as_list": t_list,
        "frozenset_as_list": fs_list,
        "bytes_as_list": by_list,
        "bytearray_as_list": ba_list,
        "complex_eq": c_eq,
        "sum_empty": sum_empty, "sum_one": sum_one,
        "sum_many": sum_many, "sum_neg": sum_neg,
        "any_empty": any_empty, "any_all_false": any_all_false,
        "any_one_true": any_one_true, "any_all_true": any_all_true,
        "all_empty": all_empty, "all_all_true": all_all_true,
        "all_one_false": all_one_false, "all_all_false": all_all_false,
        "dm1_q": dm1_q, "dm1_r": dm1_r,
        "dm2_q": dm2_q, "dm2_r": dm2_r,
        "dm3_q": dm3_q, "dm3_r": dm3_r,
        "s_len": len(s_nums),
        "s0": s_nums[0], "s1": s_nums[1], "s2": s_nums[2], "s3": s_nums[3],
        "s4": s_nums[4], "s5": s_nums[5], "s6": s_nums[6], "s7": s_nums[7],
        "s_desc0": s_desc[0], "s_desc4": s_desc[4],
        "s_single0": s_single[0],
        "s_asc0": s_asc[0], "s_asc4": s_asc[4],
        "r_len": len(r_nums),
        "r0": r_nums[0], "r7": r_nums[7],
        "r_desc0": r_desc[0], "r_desc4": r_desc[4],
        "r_single0": r_single[0],
        "orig0": sort_nums[0],
        "desc0": sort_desc[0],
        "ll_len": len(ll), "ll0": ll[0], "ll2": ll[2],
        "ss_len": len(ss),
        "ls_len": len(ls), "ls_sum": sum(ls),
        "sl_len": len(sl),
        "fmt_basic_int": f1, "fmt_basic_float": f2,
        "fmt_fixed_2": f3, "fmt_fixed_1": f4,
        "fmt_int_d": f5,
        "fmt_bin": f6, "fmt_oct": f7, "fmt_hex": f8, "fmt_hex_upper": f9,
        "fmt_width_int": f10, "fmt_left_str": f11, "fmt_right_str": f12,
        "s1_stop": s1_stop, "s1_start_none": s1_start_none,
        "s1_step_none": s1_step_none,
        "s2_start": s2_start, "s2_stop": s2_stop,
        "s2_step_none": s2_step_none,
        "s3_start": s3_start, "s3_stop": s3_stop, "s3_step": s3_step,
        "abs_neg_float": abs(-3.14),
        "abs_pos_float": abs(3.14),
        "min_float": min(3.5, 1.2),
        "max_float": max(3.5, 1.2)
    };
}

na {
    def builtins_na() -> dict[str, any] {
        items: list[int] = [1, 2, 3, 4, 5];

        lst1: list[int] = [10, 20, 30, 20];
        lst2: list[int] = [10, 20, 30];
        lst3: list[int] = [1, 1, 1, 2, 1];

        lst_empty: list[int] = [];
        lst_one: list[int] = [42];
        lst_many: list[int] = [1, 2, 3, 4, 5];
        lst_neg: list[int] = [-1, 0, 1];
        sum_empty: int = sum(lst_empty);
        sum_one: int = sum(lst_one);
        sum_many: int = sum(lst_many);
        sum_neg: int = sum(lst_neg);

        lst_f: list[int] = [0, 0, 0];
        lst_ot: list[int] = [0, 0, 1];
        lst_at: list[int] = [1, 2, 3];
        any_empty: int = 1 if any(lst_empty) else 0;
        any_all_false: int = 1 if any(lst_f) else 0;
        any_one_true: int = 1 if any(lst_ot) else 0;
        any_all_true: int = 1 if any(lst_at) else 0;

        lst_of: list[int] = [1, 0, 3];
        all_empty: int = 1 if all(lst_empty) else 0;
        all_all_true: int = 1 if all(lst_at) else 0;
        all_one_false: int = 1 if all(lst_of) else 0;
        all_all_false: int = 1 if all(lst_f) else 0;

        dm1: tuple[int, int] = divmod(17, 5);
        dm1_q: int = dm1[0];
        dm1_r: int = dm1[1];
        dm2: tuple[int, int] = divmod(10, 3);
        dm2_q: int = dm2[0];
        dm2_r: int = dm2[1];
        dm3: tuple[int, int] = divmod(7, 1);
        dm3_q: int = dm3[0];
        dm3_r: int = dm3[1];

        sort_nums: list[int] = [3, 1, 4, 1, 5, 9, 2, 6];
        sort_desc: list[int] = [5, 4, 3, 2, 1];
        sort_single: list[int] = [42];
        sort_asc: list[int] = [1, 2, 3, 4, 5];

        s_nums: list[int] = sorted(sort_nums);
        s_desc: list[int] = sorted(sort_desc);
        s_single: list[int] = sorted(sort_single);
        s_asc: list[int] = sorted(sort_asc);

        r_nums: list[int] = reversed(sort_nums);
        r_desc: list[int] = reversed(sort_desc);
        r_single: list[int] = reversed(sort_single);

        conv_list: list[int] = [1, 2, 3];
        conv_set: set[int] = {1, 2, 3};
        ll: list[int] = list(conv_list);
        ss: set[int] = set(conv_set);
        ls: list[int] = list(conv_set);
        sl: set[int] = set(conv_list);

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

        fmt_int: str = format(42, "d");
        fmt_hex: str = format(255, "x");
        fmt_oct: str = format(255, "o");

        hash_int: int = hash(42);
        hash_str: int = hash("hello");
        repr_int: str = repr(42);
        repr_neg: str = repr(-17);

        fs_src: list[int] = [1, 2, 3];
        fs: set[int] = frozenset(fs_src);

        byte_src: list[int] = [72, 101, 108, 108, 111];
        bs: str = bytes(byte_src);

        ba_src: list[int] = [68, 69];
        ba: str = bytearray(ba_src);

        # slice builtin
        sl1 = slice(5);
        s1_stop: int = sl1.stop;
        sl2 = slice(1, 5);
        s2_start: int = sl2.start;
        s2_stop: int = sl2.stop;
        sl3 = slice(0, 10, 2);
        s3_start: int = sl3.start;
        s3_stop: int = sl3.stop;
        s3_step: int = sl3.step;

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
            "len_list": len(items),
            "hex_0": hex(0),
            "hex_255": hex(255),
            "hex_16": hex(16),
            "hex_neg": hex(-1),
            "oct_0": oct(0),
            "oct_8": oct(8),
            "oct_255": oct(255),
            "oct_neg": oct(-1),
            "bin_0": bin(0),
            "bin_1": bin(1),
            "bin_10": bin(10),
            "bin_255": bin(255),
            "bin_neg": bin(-1),
            "round_int": round(5),
            "round_float_down": round(3.2),
            "round_float_up": round(3.7),
            "round_neg": round(-2.3),
            "float_from_str": float("3.14"),
            "float_from_int_str": float("42"),
            "float_neg_str": float("-1.5"),
            "str_from_int": str(42),
            "str_from_neg": str(-17),
            "list_count_one": lst1.count(20),
            "list_count_zero": lst2.count(99),
            "list_count_many": lst3.count(1),
            "sum_empty": sum_empty, "sum_one": sum_one,
            "sum_many": sum_many, "sum_neg": sum_neg,
            "any_empty": any_empty, "any_all_false": any_all_false,
            "any_one_true": any_one_true, "any_all_true": any_all_true,
            "all_empty": all_empty, "all_all_true": all_all_true,
            "all_one_false": all_one_false, "all_all_false": all_all_false,
            "dm1_q": dm1_q, "dm1_r": dm1_r,
            "dm2_q": dm2_q, "dm2_r": dm2_r,
            "dm3_q": dm3_q, "dm3_r": dm3_r,
            "s_len": len(s_nums),
            "s0": s_nums[0], "s1": s_nums[1], "s2": s_nums[2], "s3": s_nums[3],
            "s4": s_nums[4], "s5": s_nums[5], "s6": s_nums[6], "s7": s_nums[7],
            "s_desc0": s_desc[0], "s_desc4": s_desc[4],
            "s_single0": s_single[0],
            "s_asc0": s_asc[0], "s_asc4": s_asc[4],
            "r_len": len(r_nums),
            "r0": r_nums[0], "r7": r_nums[7],
            "r_desc0": r_desc[0], "r_desc4": r_desc[4],
            "r_single0": r_single[0],
            "orig0": sort_nums[0],
            "desc0": sort_desc[0],
            "ll_len": len(ll), "ll0": ll[0], "ll2": ll[2],
            "ss_len": len(ss),
            "ls_len": len(ls), "ls_sum": sum(ls),
            "sl_len": len(sl),
            "abs_neg_float": abs(-3.14),
            "abs_pos_float": abs(3.14),
            "min_float": min(3.5, 1.2),
            "max_float": max(3.5, 1.2),
            "f_zero": f_zero, "f_empty_str": f_empty_str,
            "f_zero_float": f_zero_float,
            "f_empty_list": f_empty_list, "f_empty_dict": f_empty_dict,
            "t_one": t_one, "t_str": t_str,
            "t_list": t_list, "t_dict": t_dict, "t_neg": t_neg,
            "t_float": t_float,
            "fmt_int": fmt_int, "fmt_hex": fmt_hex, "fmt_oct": fmt_oct,
            "hash_int": hash_int,
            "repr_int": repr_int, "repr_neg": repr_neg,
            "ascii_str": ascii("hello"),
            "fs_na_len": len(fs),
            "bs_len": len(bs),
            "ba_len": len(ba),
            "s1_stop": s1_stop,
            "s2_start": s2_start, "s2_stop": s2_stop,
            "s3_start": s3_start, "s3_stop": s3_stop, "s3_step": s3_step
        };
    }
}
