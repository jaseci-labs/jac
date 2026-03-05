"""Test: Guard check should narrow optional types."""

obj Prefetch {
    has list_class: int | None = None;
}

def use_int(x: int) -> int {
    return x + 1;
}

def test_guard_narrowing(prefetch: Prefetch) -> int {
    if prefetch.list_class {
        return use_int(prefetch.list_class);  # Error: int | None to int

    }
    return 0;
}
