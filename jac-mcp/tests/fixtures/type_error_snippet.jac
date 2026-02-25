"""A snippet with intentional type errors for testing."""

obj Broken {
    has x: int = "not_an_int";
    has y: str = 42;
}

with entry {
    b = Broken();
    result: int = "hello";
}
