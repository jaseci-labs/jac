"""Test fixture: comments inside brace-delimited blocks must be preserved in place."""

obj Ops {
    # Comment inside native block
    def add(a: int, b: int) -> int {
        return a + b;
    }

    # Another comment
    def mul(a: int, b: int) -> int {
        return a * b;
    }
}
