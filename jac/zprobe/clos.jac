def outer(k: int) -> int {
    def inner(a: int, b: int = 10) -> int { return a + b + k; }
    h = inner;
    return h(1, b=100) + h(a=2, b=3);
}

with entry {
    assert outer(0) == 106;
}
