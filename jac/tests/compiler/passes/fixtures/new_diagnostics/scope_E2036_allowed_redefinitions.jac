"""Fixture for E2036: same-named definitions that are not duplicates."""
import from typing { overload }

# A declaration and its impl are one definition.
def area(width: int) -> int;

impl area(width: int) -> int {
    return width * width;
}

# Alternative signatures.
@overload
def render(value: int) -> str {
    return str(value);
}

@overload
def render(value: str) -> str {
    return value;
}
