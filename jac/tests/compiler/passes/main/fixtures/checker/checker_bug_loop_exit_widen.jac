"""A variable reassigned in a loop body widens to (entry | assigned) after the loop."""

def for_widen(items: list[int]) -> int {
    fb: int | None = None;
    for it in items {
        fb = 5;
    }
    if fb is not None {
        return fb;          # fb narrows to int -> valid
    }
    return 0;
}

def while_widen(n: int) -> int {
    x: int | None = None;
    while n > 0 {
        x = 5;
        n = n - 1;
    }
    if x is not None {
        return x;           # x narrows to int -> valid
    }
    return 0;
}

def nested_widen(rows: list[list[int]]) -> int {
    acc: int | None = None;
    for row in rows {
        for v in row {
            acc = v;
        }
    }
    if acc is not None {
        return acc;         # acc narrows to int -> valid
    }
    return 0;
}

def union_precision(items: list[int]) -> int {
    fb: int | str | None = None;
    for it in items {
        fb = 5;
    }
    if fb is not None {
        return fb;          # fb narrows to int -> valid
    }
    return 0;
}

def nested_scope(items: list[int]) -> int {
    fb: int | None = None;
    for it in items {
        def inner() -> str {
            fb = "x";       # distinct symbol in inner scope
            return fb;
        }
        fb = 5;
    }
    if fb is not None {
        return fb;          # fb narrows to int, not Literal["x"] | int -> valid
    }
    return 0;
}

def aug_assign(items: list[int]) -> int {
    total: int = 0;
    for it in items {
        total += it;
    }
    return total;           # int -> valid
}
