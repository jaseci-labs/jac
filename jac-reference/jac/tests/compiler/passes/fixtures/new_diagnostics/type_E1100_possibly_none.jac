"""Fixture for E1100: Expression is possibly None."""

def maybe_int() -> int | None {
    return None;
}

with entry {
    x: int | None = maybe_int();
    y = x + 1;        # <-- Error E1100: x is possibly None

    if x is not None {
        z = x + 1;    # <-- Ok: narrowed to int
    }

    w: int = 5;
    v = w + 1;        # <-- Ok: w is definitely int
}
