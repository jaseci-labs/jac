"""Explicit `typing.Any` annotations are the same gradual-typing escape
hatch as the Jac `any` keyword: each one — on a param, return type, field,
assignment, or nested inside a generic or union — should produce a W1037
warning. Specific type annotations should not warn."""

import from typing { Any }

# Param + return Any (2 warnings)
def takes_any(x: Any) -> Any {
    return x;
}

# Annotated assignment (1 warning)
def uses_any -> None {
    y: Any = 5;
    print(y);
}

# Nested Any inside a generic (1 warning)
def nested_any(items: list[Any]) -> None {
    print(items);
}

# Any in a union branch (1 warning)
def union_any -> Any | None {
    return None;
}

# Field annotation (1 warning)
obj Box {
    has payload: Any = None;
}

# Properly typed: should NOT warn
def typed(x: int) -> str {
    return str(x);
}
