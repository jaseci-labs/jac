def floor_div(a: int, b: int) -> int {
    return a // b;
}

def chk_floordiv_lowest -> int {
    lowest = -9223372036854775807 - 1;
    caught = 0;
    try {
        floor_div(lowest, -1);
    } except OverflowError {
        caught = 1;
    }
    same = 1 if floor_div(lowest, 1) == lowest else 0;
    top = 1 if floor_div(lowest + 1, -1) == 9223372036854775807 else 0;
    return caught * 100 + same * 10 + top;
}

def chk_abs_float -> int {
    return int(abs(-2.5) * 2.0) * 10 + int(abs(3.0));
}

with entry {
    print(chk_floordiv_lowest());
    print(chk_abs_float());
}
