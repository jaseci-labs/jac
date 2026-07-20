"""Abort semantics: a raise with no same-frame handler in an enforced module
terminates via abort — unwinding never crosses an enforced frame."""

def risky(n: int) -> int {
    if n > 2 {
        raise ValueError("too big");
    }
    return n * 10;
}

with entry {
    print(risky(1));
    print(risky(5));
    print("unreachable");
}
