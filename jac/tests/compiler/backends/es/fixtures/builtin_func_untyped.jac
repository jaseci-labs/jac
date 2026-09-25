"""Builtin functions used inside an untyped client function."""

def summarize(xs: list[any]) -> dict[any, any] {
    return {
        "sorted": sorted(xs),
        "sorted_reverse": sorted(xs, reverse=True),
        "total": sum(xs),
        "sum_kwarg": sum(xs, start=10),
        "count": len(xs),
        "enumerated": enumerate(xs),
        "enumerated_kwarg": enumerate(xs, start=5),
        "ranged": range(len(xs))
    };
}

def numeric(n: int) -> dict[any, any] {
    return {
        "abs": abs(0 - n),
        "round": round(3.14159, 2),
        "round_kwarg": round(3.14159, ndigits=2),
        "pow_base_exp": pow(base=n, exp=3),
        "pow_exp_base": pow(exp=3, base=n)
    };
}

def combined(a: list[any], b: list[any]) -> list[any] {
    m = min(a);
    x = max(a);
    pairs = zip(a, b);
    return [m, x, pairs];
}

def str_len(s: str) -> int {
    return len(s);
}

def min_max_by_key(items: list[any]) -> list[any] {
    return [min(items, key=str_len), max(items, key=str_len)];
}

def sorted_kwargs_order(items: list[any]) -> dict[any, any] {
    return {
        "key_then_reverse": sorted(items, key=str_len, reverse=True),
        "reverse_then_key": sorted(items, reverse=True, key=str_len)
    };
}

def sorted_kwargs_spread(items: list[any], opts: dict[str, any]) -> list[any] {
    return sorted(items, reverse=True, **opts);
}

def min_of_empty -> int {
    return min([]);
}

def min_of_spread(xs: list[any]) -> int {
    return min(*xs);
}

def min_max_varargs(a: int, b: int, c: int) -> list[int] {
    return [min(a, b, c), max(a, b, c)];
}
