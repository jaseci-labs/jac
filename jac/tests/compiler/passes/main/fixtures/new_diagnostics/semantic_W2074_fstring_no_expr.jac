"""Fixture for W2074: f-string has no interpolated expressions."""

with entry {
    a = f"hello world";  # <-- Warning W2074: no expressions, use regular string
    b = f"hello {42}";   # <-- Ok: has expression
    c = "hello world";   # <-- Ok: regular string
}
