"""Fixture for E0065: Duplicate keyword argument in function call."""

def foo(a: int, b: int) -> int {
    return a + b;
}

with entry {
    foo(a=1, b=2);        # <-- Ok
    foo(a=1, a=2);        # <-- Error E0065: duplicate keyword 'a'
    foo(a=1, b=2, b=3);   # <-- Error E0065: duplicate keyword 'b'
}
