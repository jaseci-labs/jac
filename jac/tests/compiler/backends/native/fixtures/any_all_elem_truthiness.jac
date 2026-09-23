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

obj BoolProbeItem {
    has value: float;
}

def any_object_comprehension -> int {
    items = [BoolProbeItem(value=0.0), BoolProbeItem(value=1.0)];
    return 1 if any([item.value > 0.0 for item in items]) else 0;
}

def all_object_comprehension -> int {
    items = [BoolProbeItem(value=0.0), BoolProbeItem(value=1.0)];
    return 1 if all([item.value > 0.0 for item in items]) else 0;
}

def any_negated_comprehension -> int {
    items = [BoolProbeItem(value=0.0)];
    return 1 if any([not item.value for item in items]) else 0;
}

def all_literal_comprehension -> int {
    items = [BoolProbeItem(value=0.0), BoolProbeItem(value=1.0)];
    return 1 if all([True for item in items]) else 0;
}

def any_float_comparison -> int {
    return 1 if any([value > 0.0 for value in [0.0, 1.5]]) else 0;
}

def any_empty_comprehension -> int {
    items: list[BoolProbeItem] = [];
    return 1 if any([item.value > 0.0 for item in items]) else 0;
}
