# sum() over floats is a float. Two causes made it `int`: an `Iterable[X]`
# target accepted any iterable whatever its element type, so sum's first
# overload (`Iterable[bool | int] -> int`) matched a list of floats; and a
# `T | Literal[0]` annotation collapsed to `int`, so the generic overload
# returned `int` too.
def total(prices: list[float], shipping: float) -> float {
    value = sum([p for p in prices]);
    value += shipping;  # <-- Ok
    return value;
}

def total_plain(prices: list[float]) -> float {
    value = sum(prices);
    value += 1.5;  # <-- Ok
    return value;
}

def first_or_zero[T](xs: list[T]) -> T | Literal[0] {
    return xs[0] if xs else 0;
}

def uses_first(prices: list[float]) -> float {
    got: float | int = first_or_zero(prices);  # <-- Ok
    return got;
}

def pick[T](xs: Iterable[T]) -> list[T] {
    return list(xs);
}

def firsts[T](groups: Iterable[list[T]]) -> list[T] {
    return [g[0] for g in groups];
}

def generic_target(prices: list[float], nested: dict[list[int], str]) -> list[float] {
    heads: list[int] = firsts(nested);  # <-- Ok
    print(heads);
    return pick(prices);  # <-- Ok
}

def element_types(prices: list[float], names: list[str]) {
    ok: Iterable[float] = prices;  # <-- Ok
    also_ok: Iterable[str] = names;  # <-- Ok
    wrong: Iterable[int] = prices;  # <-- Error
    print(ok, also_ok, wrong);
}
