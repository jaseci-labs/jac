"""Tests for Union[] and Optional[] special form type annotations from typing module."""

import from typing { Union, Optional }

# --- Union[...] produces proper UnionType (same as pipe syntax) ---

def with_union(x: Union[int, str]) -> str {
    y: int = x;  # <-- Error: int | str not assignable to int
    return str(x);
}

def with_pipe(x: int | str) -> str {
    z: int = x;  # <-- Error: int | str not assignable to int
    return str(x);
}

# --- Union[...] works with type narrowing via early returns ---

def narrow_union(x: Union[list, int, str]) -> str {
    if isinstance(x, list) {
        return str(len(x));
    }
    if isinstance(x, int) {
        return str(x);
    }
    # x should be narrowed to str here
    return x.upper();  # <-- Ok: x is str
}

# --- Optional[T] produces Union[T, None] ---

def with_optional(x: Optional[str]) -> str {
    if x is None {
        return "default";
    }
    return x.upper();  # <-- Ok: x is str
}

def optional_error(x: Optional[str]) -> str {
    y: int = x;  # <-- Error: str | None not assignable to int
    return str(y);
}
