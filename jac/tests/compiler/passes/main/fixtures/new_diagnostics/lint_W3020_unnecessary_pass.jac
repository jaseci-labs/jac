"""Fixture for W3020: Unnecessary pass in non-empty body."""

obj Foo {
    has x: int = 5;
    pass;  # <-- Warning W3020: body is not empty
}

obj Bar {
    pass;  # <-- Ok: empty body needs pass (if Jac has this pattern)
}
