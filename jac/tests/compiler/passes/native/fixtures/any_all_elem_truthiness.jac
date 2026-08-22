def any_str_none -> int {
    return 1 if any(["", ""]) else 0;
}

def any_str_some -> int {
    return 1 if any(["", "x"]) else 0;
}

def all_str_yes -> int {
    return 1 if all(["a", "b"]) else 0;
}

def all_str_no -> int {
    return 1 if all(["a", ""]) else 0;
}

def any_float_none -> int {
    return 1 if any([0.0, 0.0]) else 0;
}

def any_float_some -> int {
    return 1 if any([0.0, 2.5]) else 0;
}

def all_float_no -> int {
    return 1 if all([1.5, 0.0]) else 0;
}

def any_bool_none -> int {
    return 1 if any([False, False]) else 0;
}

def any_bool_some -> int {
    return 1 if any([False, True]) else 0;
}

def all_bool_no -> int {
    return 1 if all([True, False]) else 0;
}

def any_int_none -> int {
    return 1 if any([0, 0]) else 0;
}

def any_int_some -> int {
    return 1 if any([0, 3]) else 0;
}

def all_int_yes -> int {
    return 1 if all([1, 2]) else 0;
}

def all_int_no -> int {
    return 1 if all([1, 0]) else 0;
}
