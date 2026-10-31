"""Empty constructors receive element types through optional assignments and
through the declared type of the tuple that holds them."""

def optional_set(flag: int) -> int {
    seen: set[int] | None = None;
    if flag {
        seen = set();
    }
    if seen is None {
        seen = set();
    }
    seen.add(3);
    seen.add(5);
    return len(seen);
}

def optional_list -> int {
    values: list[int] | None = None;
    if values is None {
        values = list();
    }
    values.append(7);
    return values[0];
}

def tuple_with_empty(n: int) -> tuple[dict[str, int], int] {
    if n > 0 {
        return ({}, n);
    }
    return ({"a": 1}, 0);
}

def empty_dict_in_tuple -> int {
    (table, k) = tuple_with_empty(4);
    table["x"] = 9;
    return table["x"] * 10 + k + len(table);
}
