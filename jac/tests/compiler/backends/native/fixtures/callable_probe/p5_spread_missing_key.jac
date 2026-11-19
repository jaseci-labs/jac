def add(a: int, b: int) -> int {
    return a * 10 + b;
}

with entry {
    kw: dict[str, int] = {"a": 1};
    try {
        print(add(**kw));
    } except TypeError as e {
        print("TypeError");
    }
}
