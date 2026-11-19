def add(a: int, b: int) -> int {
    return a * 10 + b;
}

def kwunpack(kw: dict[str, any], f: Callable) -> any {
    return f(**kw);
}

with entry {
    print(kwunpack({"a": 1, "b": 2}, add));
}
