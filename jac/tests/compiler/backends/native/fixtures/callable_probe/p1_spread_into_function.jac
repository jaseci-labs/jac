def add(a: int, b: int) -> int {
    return a * 10 + b;
}

with entry {
    kw: dict[str, int] = {"b": 2, "a": 1};
    print(add(**kw));
}
