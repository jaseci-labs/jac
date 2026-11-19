def add(a: int, b: int, c: int = 9) -> int {
    return a * 100 + b * 10 + c;
}

with entry {
    kw: dict[str, int] = {"b": 2};
    print(add(1, **kw));
}
