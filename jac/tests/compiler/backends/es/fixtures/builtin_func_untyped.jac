"""Builtin functions used inside an untyped client function."""

def summarize(xs: list) -> dict {
    return {
        "sorted": sorted(xs),
        "total": sum(xs),
        "count": len(xs),
        "enumerated": enumerate(xs),
        "ranged": range(len(xs))
    };
}

def numeric(n: int) -> dict {
    return {"abs": abs(0 - n), "round": round(3.14159, 2)};
}

def combined(a: list, b: list) -> list {
    m = min(a);
    x = max(a);
    pairs = zip(a, b);
    return [m, x, pairs];
}

def str_len(s: str) -> int {
    return len(s);
}

def min_max_by_key(items: list) -> list {
    return [min(items, key=str_len), max(items, key=str_len)];
}

def min_of_empty -> int {
    return min([]);
}

def min_of_spread(xs: list) -> int {
    return min(*xs);
}

def min_max_varargs(a: int, b: int, c: int) -> list {
    return [min(a, b, c), max(a, b, c)];
}
