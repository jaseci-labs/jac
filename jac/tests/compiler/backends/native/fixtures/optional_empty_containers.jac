"""Empty constructors receive element types through optional assignments."""

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
