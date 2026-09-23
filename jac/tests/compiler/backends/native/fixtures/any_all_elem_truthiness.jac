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

obj BoolOpProbeItem {
    has flag: bool,
        value: float,
        label: str = "";
}

def boolop_items -> list[BoolOpProbeItem] {
    return [
        BoolOpProbeItem(flag=True, value=1.0, label="a"),
        BoolOpProbeItem(flag=False, value=2.0)
    ];
}

def any_and_field_comparison -> int {
    items = boolop_items();
    return 1 if any([item.flag and item.value == 1.0 for item in items]) else 0;
}

def any_and_field_comparison_miss -> int {
    items = boolop_items();
    return 1 if any([item.flag and item.value > 1.0 for item in items]) else 0;
}

def all_or_field_comparison -> int {
    items = boolop_items();
    return 1 if all([item.flag or item.value > 1.0 for item in items]) else 0;
}

def all_or_field_comparison_miss -> int {
    items = boolop_items();
    return 1 if all([item.flag or item.value > 5.0 for item in items]) else 0;
}

def any_and_bool_fields -> int {
    items = boolop_items();
    return 1 if any([item.flag and item.flag for item in items]) else 0;
}

def all_nested_boolop -> int {
    items = boolop_items();
    return 1
        if all([(item.flag and item.value < 2.0) or not item.flag for item in items])
        else 0;
}

def any_not_mixed_boolop -> int {
    items = boolop_items();
    return 1 if any([not item.flag and item.value > 1.0 for item in items]) else 0;
}

def stored_boolop_count -> int {
    items = boolop_items();
    flags = [item.flag or item.value > 2.5 for item in items];
    count = 0;
    for flag in flags {
        if flag {
            count += 1;
        }
    }
    return count * 10 + (1 if all(flags) else 0);
}

def any_float_boolop -> int {
    return 1 if any([v > 0.5 and v < 1.0 for v in [0.25, 0.75, 1.5]]) else 0;
}

def all_float_boolop -> int {
    return 1 if all([v < 0.5 or v > 1.0 for v in [0.25, 0.75, 1.5]]) else 0;
}

def any_empty_boolop -> int {
    items: list[BoolOpProbeItem] = [];
    return 1 if any([item.flag and item.value > 0.0 for item in items]) else 0;
}

def all_empty_boolop -> int {
    items: list[BoolOpProbeItem] = [];
    return 1 if all([item.flag or item.value > 0.0 for item in items]) else 0;
}

def or_keeps_int_operand -> int {
    values = [v or 7 for v in [0, 3]];
    return values[0] * 10 + values[1];
}

def or_keeps_str_operand -> int {
    items = boolop_items();
    labels = [item.label or "none" for item in items];
    return 1 if labels[0] == "a" and labels[1] == "none" else 0;
}
