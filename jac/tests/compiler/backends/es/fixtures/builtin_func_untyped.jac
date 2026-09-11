"""Builtin functions used inside an untyped client function."""

def summarize(xs: list[any]) -> dict[any, any] {
    return {
        "sorted": sorted(xs),
        "total": sum(xs),
        "count": len(xs),
        "enumerated": enumerate(xs),
        "ranged": range(len(xs))
    };
}

def numeric(n: int) -> dict[any, any] {
    return {"abs": abs(0 - n), "round": round(3.14159, 2)};
}

def combined(a: list[any], b: list[any]) -> list[any] {
    m = min(a);
    x = max(a);
    pairs = zip(a, b);
    return [m, x, pairs];
}
