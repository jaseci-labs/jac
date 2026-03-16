"""Fixture for E0066: Positional argument follows keyword argument."""

def foo(a: int, b: int, c: int) -> int {
    return a + b + c;
}

with entry {
    foo(1, 2, 3);         # <-- Ok
    foo(1, b=2, c=3);     # <-- Ok
    foo(a=1, 2, 3);       # <-- Error E0066: positional after keyword
    foo(1, b=2, 3);       # <-- Error E0066: positional after keyword
}
