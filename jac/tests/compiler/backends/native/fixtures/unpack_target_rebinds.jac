"""Loop targets unpacked from tuples that rebind a name to another type."""

def rebound -> list[float] {
    total = 0.0;
    names = 0;
    for (name, side) in [("a", 1.0), ("bb", -2.5)] {
        total += side;
        names += len(name);
    }
    for (side, sign) in [("l", 1.0), ("rr", -1.0)] {
        total += sign * float(len(side));
    }
    return [total, float(names)];
}

def kept -> int {
    total = 0;
    for (a, b) in [(1, 2), (3, 4)] {
        total += a * b;
    }
    for (a, b) in [(5, 6)] {
        total += a + b;
    }
    return total;
}

def swapped -> float {
    total = 0.0;
    for (k, v) in [(1, 2.0), (2, 3.0)] {
        total += float(k) * v;
    }
    for (v, k) in [(3.5, "zzz")] {
        total += v * float(len(k));
    }
    return total;
}

def assigned_after_tuple_loop(groups: list[tuple[int, int]], text: str) -> int {
    total = 0;
    for (first, number) in groups {
        total += first + number;
    }
    number = text.rsplit("_", 1)[-1] if "_" in text else "0";
    return total + (1 if number.isdigit() else 0) + len(number);
}

def assigned_after_loop(values: list[int], text: str) -> int {
    total = 0;
    for number in values {
        total += number;
    }
    number = text;
    return total + len(number);
}

def narrowed_optional(flag: bool) -> int {
    held: int | None = None;
    if flag {
        held = 5;
    }
    return held if held is not None else -1;
}

def trimmed(name: str) -> str {
    stem = name.lower().split("/")[-1];
    for prefix in ["ttl_", "m_"] {
        if stem.startswith(prefix) {
            stem = stem[len(prefix):];
            break;
        }
    }
    return stem.upper();
}

def popped_on_one_path(pool: list[any], take: bool) -> int {
    handle = 5;
    if take and len(pool) > 0 {
        handle = pool.pop();
    }
    return handle + 1;
}

with entry {
    print(rebound());
    print(kept());
    print(swapped());
    print(
        assigned_after_tuple_loop([(1, 2)], "x_12"), assigned_after_loop([1, 2], "abc")
    );
    print(narrowed_optional(True), narrowed_optional(False));
    print(trimmed("gfx/ttl_main"), trimmed("gfx/inter"));
    print(popped_on_one_path([3], True), popped_on_one_path([3], False));
}
