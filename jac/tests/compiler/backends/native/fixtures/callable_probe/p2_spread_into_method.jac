obj Calc {
    has base: int = 100;

    def add(a: int, b: int) -> int {
        return self.base + a * 10 + b;
    }
}

with entry {
    kw: dict[str, int] = {"a": 3, "b": 4};
    print(Calc().add(**kw));
}
