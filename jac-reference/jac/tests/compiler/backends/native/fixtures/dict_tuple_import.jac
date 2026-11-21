import from dict_tuple_data { OPERATOR_NAMES }
def imported_tuple -> int {
    (left, right) = OPERATOR_NAMES["+"];
    return len(left) * 10 + len(right);
}

with entry {
    print(imported_tuple());
}
