"""Fixture for E2020: Name used before definition in same scope."""

with entry {
    print(x);  # <-- Error E2020: 'x' used before definition
    x = 5;
}

def ok_func() -> None {
    x = 10;
    print(x);  # <-- Ok: defined before use
}
