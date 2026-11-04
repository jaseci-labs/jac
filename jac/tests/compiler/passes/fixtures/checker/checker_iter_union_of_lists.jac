"""Iterating a union of differently-parameterized lists yields the union of
their element types."""

obj A {
    has n: int = 0;
}

obj B {
    has n: int = 0;
}

def take(x: A) -> int {
    return x.n;
}

def take_either(x: A | B) -> int {
    return x.n;
}

def fine(xs: list[A] | list[A | B] | None) -> int {
    total = 0;
    for x in xs or [] {
        total += take_either(x);
    }
    return total;
}

def mismatched(xs: list[A] | list[A | B]) -> int {
    total = 0;
    for x in xs {
        total += take(x);
    }
    return total;
}
