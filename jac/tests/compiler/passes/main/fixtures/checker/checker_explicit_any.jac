"""Explicit `any` annotations on parameters, return types, fields, and
assignments — including nested forms — should produce W1037 warnings.
Specific type annotations should not warn."""

# Param + return any (2 warnings)
def takes_any(x: any) -> any {
    return x;
}

# Annotated assignment (1 warning)
def uses_any -> None {
    y: any = 5;
    print(y);
}

# Nested any inside a generic (1 warning)
def nested_any(items: list[any]) -> None {
    print(items);
}

# any in a union branch (1 warning)
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
