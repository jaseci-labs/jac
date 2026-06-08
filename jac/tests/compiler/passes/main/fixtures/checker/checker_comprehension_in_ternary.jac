"""Regression test: type narrowing inside a list comprehension in a ternary true branch."""

obj Items {
    has data: list[str] = [];
}

obj Container {
    has items: Items | None = None;
}

# -- These must produce NO errors --

def simple_expression_in_true_branch(c: Container) -> list[str] {
    return c.items.data if c.items else [];
}

def comprehension_in_true_branch(c: Container) -> list[str] {
    return [x for x in c.items.data] if c.items else [];
}

# -- This must produce exactly 1 error (no guard at all) --

def no_guard(c: Container) -> list[str] {
    return [x for x in c.items.data];   # Error: E1099
}
