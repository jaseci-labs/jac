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
