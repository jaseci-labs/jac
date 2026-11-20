"""A protocol member bound to an overloaded method solves its type variable from
the overload that fits the protocol's signature. `float.__round__` returns `int`
without ndigits and `float` with it, so `round(x, 3)` is a float."""

def rounded(value: float, values: list[float]) -> list[float] {
    places: float = round(value, 3);
    keyword: float = round(value, ndigits=3);
    whole: int = round(value);
    listed: list[float] = [round(item, 3) for item in values];
    wrong_places: int = round(value, 3);
    wrong_whole: str = round(value);
    return listed + [places, keyword, float(whole)];
}
