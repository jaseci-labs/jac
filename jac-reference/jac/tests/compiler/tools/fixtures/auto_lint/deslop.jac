"""Module docstring to deslop."""

# standalone comment
glob x = 1;  # inline comment

"""Archetype docstring to deslop."""
obj Foo {
    has a: int = 0;  # field comment
}

"""Function docstring to deslop."""
def bump(n: int) -> int {
    return n + 1;  # jac:ignore[E1053]
}
