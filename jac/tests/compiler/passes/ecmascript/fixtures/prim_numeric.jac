"""Numeric operator primitives: int and float arithmetic, comparisons, bitwise, unary."""

def numeric_py() -> dict {
    a: int = 17;
    b: int = 5;
    x: float = 3.5;
    y: float = 1.2;
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
        "float_add": x + y,
        "float_sub": x - y,
        "float_mul": x * y,
        "float_truediv": x / y
    };
}

cl def numeric_cl() -> dict {
    a: int = 17;
    b: int = 5;
    x: float = 3.5;
    y: float = 1.2;
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
        "float_add": x + y,
        "float_sub": x - y,
        "float_mul": x * y,
        "float_truediv": x / y
    };
}
