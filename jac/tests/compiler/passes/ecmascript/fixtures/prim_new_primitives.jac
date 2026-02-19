"""Tests for new primitive emitter additions.

Covers: bool() Python truthiness, range(), slice(), BoolEmitter bitwise ops,
and enhanced format().
"""

# =============================================================================
# bool() — Python truthiness semantics
# =============================================================================

def bool_truthiness_py() -> dict {
    # Falsy values
    f_none: bool = bool(None);
    f_zero: bool = bool(0);
    f_empty_str: bool = bool("");
    f_false: bool = bool(False);
    f_zero_float: bool = bool(0.0);
    f_empty_list: bool = bool([]);
    f_empty_dict: bool = bool({});

    # Truthy values
    t_one: bool = bool(1);
    t_str: bool = bool("hello");
    t_true: bool = bool(True);
    t_list: bool = bool([1, 2]);
    t_dict: bool = bool({"a": 1});
    t_neg: bool = bool(-1);
    t_float: bool = bool(3.14);

    return {
        "f_none": f_none, "f_zero": f_zero, "f_empty_str": f_empty_str,
        "f_false": f_false, "f_zero_float": f_zero_float,
        "f_empty_list": f_empty_list, "f_empty_dict": f_empty_dict,
        "t_one": t_one, "t_str": t_str, "t_true": t_true,
        "t_list": t_list, "t_dict": t_dict, "t_neg": t_neg,
        "t_float": t_float
    };
}

cl def bool_truthiness_cl() -> dict {
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

    return {
        "f_none": f_none, "f_zero": f_zero, "f_empty_str": f_empty_str,
        "f_false": f_false, "f_zero_float": f_zero_float,
        "f_empty_list": f_empty_list, "f_empty_dict": f_empty_dict,
        "t_one": t_one, "t_str": t_str, "t_true": t_true,
        "t_list": t_list, "t_dict": t_dict, "t_neg": t_neg,
        "t_float": t_float
    };
}

# =============================================================================
# range() — constructor
# =============================================================================

def range_builtin_py() -> dict {
    # range(stop)
    r1: list = list(range(5));
    # range(start, stop)
    r2: list = list(range(2, 7));
    # range(start, stop, step)
    r3: list = list(range(0, 10, 2));
    # negative step
    r4: list = list(range(10, 0, -2));
    # empty range
    r5: list = list(range(5, 5));
    r6: list = list(range(10, 5));
    # single element
    r7: list = list(range(3, 4));

    # for i in range — accumulate sum
    total: int = 0;
    for i in range(5) {
        total += i;
    }

    # for i in range with step — collect values
    stepped: list = [];
    for i in range(1, 10, 3) {
        stepped.append(i);
    }

    # for i in range — negative step countdown
    countdown: list = [];
    for i in range(5, 0, -1) {
        countdown.append(i);
    }

    # nested for i in range
    pairs: list = [];
    for i in range(3) {
        for j in range(2) {
            pairs.append(i * 10 + j);
        }
    }

    return {
        "r_stop": r1, "r_start_stop": r2,
        "r_step": r3, "r_neg_step": r4,
        "r_empty_eq": r5, "r_empty_inv": r6,
        "r_single": r7,
        "loop_sum": total, "loop_stepped": stepped,
        "loop_countdown": countdown, "loop_nested": pairs
    };
}

cl def range_builtin_cl() -> dict {
    r1: list = list(range(5));
    r2: list = list(range(2, 7));
    r3: list = list(range(0, 10, 2));
    r4: list = list(range(10, 0, -2));
    r5: list = list(range(5, 5));
    r6: list = list(range(10, 5));
    r7: list = list(range(3, 4));

    total: int = 0;
    for i in range(5) {
        total += i;
    }

    stepped: list = [];
    for i in range(1, 10, 3) {
        stepped.append(i);
    }

    countdown: list = [];
    for i in range(5, 0, -1) {
        countdown.append(i);
    }

    pairs: list = [];
    for i in range(3) {
        for j in range(2) {
            pairs.append(i * 10 + j);
        }
    }

    return {
        "r_stop": r1, "r_start_stop": r2,
        "r_step": r3, "r_neg_step": r4,
        "r_empty_eq": r5, "r_empty_inv": r6,
        "r_single": r7,
        "loop_sum": total, "loop_stepped": stepped,
        "loop_countdown": countdown, "loop_nested": pairs
    };
}

# =============================================================================
# Bool bitwise operators — & | ^ return bool not int
# =============================================================================

def bool_bitwise_py() -> dict {
    a: bool = True;
    b: bool = False;

    and_tf: bool = a & b;
    and_tt: bool = a & a;
    and_ff: bool = b & b;
    or_tf: bool = a | b;
    or_tt: bool = a | a;
    or_ff: bool = b | b;
    xor_tf: bool = a ^ b;
    xor_tt: bool = a ^ a;
    xor_ff: bool = b ^ b;

    # Type check: bool & bool should be bool (which is also int 0/1)
    and_val: int = int(a & b);
    or_val: int = int(a | b);
    xor_val: int = int(a ^ b);

    return {
        "and_tf": and_tf, "and_tt": and_tt, "and_ff": and_ff,
        "or_tf": or_tf, "or_tt": or_tt, "or_ff": or_ff,
        "xor_tf": xor_tf, "xor_tt": xor_tt, "xor_ff": xor_ff,
        "and_val": and_val, "or_val": or_val, "xor_val": xor_val
    };
}

cl def bool_bitwise_cl() -> dict {
    a: bool = True;
    b: bool = False;

    and_tf: bool = a & b;
    and_tt: bool = a & a;
    and_ff: bool = b & b;
    or_tf: bool = a | b;
    or_tt: bool = a | a;
    or_ff: bool = b | b;
    xor_tf: bool = a ^ b;
    xor_tt: bool = a ^ a;
    xor_ff: bool = b ^ b;

    and_val: int = int(a & b);
    or_val: int = int(a | b);
    xor_val: int = int(a ^ b);

    return {
        "and_tf": and_tf, "and_tt": and_tt, "and_ff": and_ff,
        "or_tf": or_tf, "or_tt": or_tt, "or_ff": or_ff,
        "xor_tf": xor_tf, "xor_tt": xor_tt, "xor_ff": xor_ff,
        "and_val": and_val, "or_val": or_val, "xor_val": xor_val
    };
}

# =============================================================================
# format() builtin — enhanced format spec support
# =============================================================================

def format_builtin_py() -> dict {
    # Basic string conversion
    f1: str = format(42);
    f2: str = format(3.14159);
    # Fixed-point
    f3: str = format(3.14159, ".2f");
    f4: str = format(1000, ".1f");
    # Integer
    f5: str = format(42, "d");
    # Binary, octal, hex
    f6: str = format(255, "b");
    f7: str = format(255, "o");
    f8: str = format(255, "x");
    f9: str = format(255, "X");
    # Width and alignment
    f10: str = format(42, "10d");
    f11: str = format("hi", "<10s");
    f12: str = format("hi", ">10s");

    return {
        "basic_int": f1, "basic_float": f2,
        "fixed_2": f3, "fixed_1": f4,
        "int_d": f5,
        "bin": f6, "oct": f7, "hex": f8, "hex_upper": f9,
        "width_int": f10, "left_str": f11, "right_str": f12
    };
}

cl def format_builtin_cl() -> dict {
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

    return {
        "basic_int": f1, "basic_float": f2,
        "fixed_2": f3, "fixed_1": f4,
        "int_d": f5,
        "bin": f6, "oct": f7, "hex": f8, "hex_upper": f9,
        "width_int": f10, "left_str": f11, "right_str": f12
    };
}

# =============================================================================
# slice() — constructor
# =============================================================================

def slice_builtin_py() -> dict {
    # Basic slice objects — test construction and attribute access
    s1 = slice(5);
    s1_stop: int = s1.stop;
    s1_start_none: bool = s1.start is None;
    s1_step_none: bool = s1.step is None;

    s2 = slice(1, 5);
    s2_start: int = s2.start;
    s2_stop: int = s2.stop;
    s2_step_none: bool = s2.step is None;

    s3 = slice(0, 10, 2);
    s3_start: int = s3.start;
    s3_stop: int = s3.stop;
    s3_step: int = s3.step;

    return {
        "s1_stop": s1_stop, "s1_start_none": s1_start_none,
        "s1_step_none": s1_step_none,
        "s2_start": s2_start, "s2_stop": s2_stop,
        "s2_step_none": s2_step_none,
        "s3_start": s3_start, "s3_stop": s3_stop, "s3_step": s3_step
    };
}

cl def slice_builtin_cl() -> dict {
    s1 = slice(5);
    s1_stop: int = s1.stop;
    s1_start_none: bool = s1.start is None;
    s1_step_none: bool = s1.step is None;

    s2 = slice(1, 5);
    s2_start: int = s2.start;
    s2_stop: int = s2.stop;
    s2_step_none: bool = s2.step is None;

    s3 = slice(0, 10, 2);
    s3_start: int = s3.start;
    s3_stop: int = s3.stop;
    s3_step: int = s3.step;

    return {
        "s1_stop": s1_stop, "s1_start_none": s1_start_none,
        "s1_step_none": s1_step_none,
        "s2_start": s2_start, "s2_stop": s2_stop,
        "s2_step_none": s2_step_none,
        "s3_start": s3_start, "s3_stop": s3_stop, "s3_step": s3_step
    };
}
