"""`sum` follows the element type of its list and an optional start value."""

def sum_ints -> int {
    values: list[int] = [2, 3, 5];
    return sum(values);
}

def sum_floats -> float {
    values: list[float] = [0.5, 0.25, 1.0];
    return sum(values);
}

def sum_bools -> int {
    flags = [True, False, True, True];
    return sum(flags);
}

def sum_int_start -> int {
    values: list[int] = [1, 2];
    return sum(values, 10);
}

def sum_float_start -> float {
    values: list[int] = [1, 2];
    return sum(values, 0.5);
}

def sum_float_comprehension -> float {
    flags = [True, False, True];
    weights = [0.5, 0.2, 0.3];
    return sum([weights[k] if flags[k] else 0.0 for k in range(3)]);
}

def sum_empty_floats -> float {
    values: list[float] = [];
    return sum(values);
}
