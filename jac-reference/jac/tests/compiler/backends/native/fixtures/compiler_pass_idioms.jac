"""Fixture: idioms the compiler's own analysis passes rely on natively.

Each function answers an integer so the JIT test can compare it with the
value the Python backend computes for the same code.
"""

def joined_generator -> int {
    numbers: list[int] = [1, 22, 333];
    text = ", ".join(str(n) for n in numbers);
    return 1 if text == "1, 22, 333" else 0;
}

def set_update_from_lists -> int {
    seen: set[str] = {"a"};
    seen.update(["b", "a", "c"]);
    declared: dict[str, list[str]] = {"reads": ["r1", "r2", "a"]};
    seen.update(declared["reads"]);
    merged = seen.union(["z", "a"]);
    return len(seen) * 10 + len(merged);
}

def set_update_from_keys -> int {
    ids: set[int] = {1};
    table: dict[int, str] = {2: "x", 1: "y", 5: "z"};
    ids.update(table.keys());
    return sum(sorted(ids));
}

obj Signature {
    has parts: (list[tuple[int, str]] | None) = None;
}

def optional_list_equality -> int {
    sig = Signature(parts=[(1, "2"), (0, "UT")]);
    same: list[tuple[int, str]] = [(1, "2"), (0, "UT")];
    changed: list[tuple[int, str]] = [(1, "3"), (0, "UT")];
    empty = Signature();
    return (1 if sig.parts == same else 0) * 1000
        + (1 if sig.parts == changed else 0) * 100
        + (1 if sig.parts != changed else 0) * 10
        + (1 if empty.parts == same else 0);
}
