"""Explicit `typing.Any` annotations are the same gradual-typing escape
hatch as the Jac `any` keyword: each one — on a param, return type, field,
assignment, or nested inside a generic or union — should produce a W1037
warning. Specific type annotations should not warn."""

# Param + return Any (2 warnings)
def takes_any(x: any) -> any {
    return x;
}

# Annotated assignment (1 warning)
def uses_any -> None {
    y: any = 5;
    print(y);
}

# Nested Any inside a generic (1 warning)
def nested_any(items: list[any]) -> None {
    print(items);
}

# Any in a union branch (1 warning)
def union_any -> any | None {
    return None;
}

# Field annotation (1 warning)
obj Box {
    has payload: any = None;
}

# Properly typed: should NOT warn
def typed(x: int) -> str {
    return str(x);
}
