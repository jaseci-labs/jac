"""Test fixture: comments inside na {} blocks must be preserved in place."""

na {
    # Comment inside native block
    def add(a: int, b: int) -> int {
        return a + b;
    }

    # Another comment
    def mul(a: int, b: int) -> int {
        return a * b;
    }
}
