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

# Importing the module's own name binds the same definition.
import from .scope_E2036_allowed_redefinitions { area }

# An untyped glob assigns the imported name rather than declaring a new one.
import from scope_E2036_import_provider { Setting }

glob Setting = 4;
