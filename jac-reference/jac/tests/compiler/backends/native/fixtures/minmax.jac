def extrema(a: int, b: int, c: int, mode: int) -> int {
    if mode == 0 {
        return min(a, b, c);
    }
    if mode == 1 {
        return max(a, b, c);
    }
    values = [a, b, c];
    if mode == 2 {
        return min(values);
    }
    return max(values);
}

def floating(a: float, b: float, c: float, mode: int) -> float {
    if mode == 0 {
        return min(a, b, c);
    }
    if mode == 1 {
        return max(a, b, c);
    }
    values = [a, b, c];
    if mode == 2 {
        return min(values);
    }
    return max(values);
}

def empty_checks -> bool {
    values: list[int] = [];
    caught = 0;
    try {
        min(values);
    } except ValueError {
        caught += 1;
    }
    try {
        max(values);
    } except ValueError {
        caught += 1;
    }
    return caught == 2
        and min(values, `default=17) == 17
        and max(values, `default=-9) == -9
        and min([3, 8], `default=-100) == 3
        and max([3, 8], `default=100) == 8;
}

def paeth -> bool {
    distances = [8, 5, 2];
    return [40, 50, 60][distances.index(min(distances))] == 60;
}

def scalar_checks -> bool {
    flags = [True, False, True];
    values: list[u64] = [u64(18446744073709551615), u64(1), u64(9223372036854775808)];
    return not min(flags)
        and max(flags)
        and min(values) == u64(1)
        and max(values) == u64(18446744073709551615)
        and min(u64(18446744073709551615), u64(1), u64(9)) == u64(1)
        and min([42]) == 42
        and max([-8]) == -8;
}

with entry {
    assert extrema(4, 2, -3, 0) == -3;
    assert extrema(4, 2, 9, 3) == 9;
    assert empty_checks();
    assert scalar_checks();
    assert paeth();
    print("NATIVE MINMAX PASS");
}

def touch(counter: list[int]) -> int {
    counter[0] += 1;
    return -99;
}

def more_scalars -> bool {
    small: list[i8] = [i8(-128), i8(127), i8(0)];
    floats: list[f32] = [f32(2.5), f32(-1.5), f32(0)];
    counter = [0];
    values = [7, -3, 5];
    result = min(values, `default=touch(counter));
    empty: list[int] = [];
    fallback = max(empty, `default=touch(counter));
    return int(min(small)) == -128
        and int(max(small)) == 127
        and float(min(floats)) == -1.5
        and float(max(floats)) == 2.5
        and result == -3
        and fallback == -99
        and counter[0] == 2
        and values == [7, -3, 5];
}
