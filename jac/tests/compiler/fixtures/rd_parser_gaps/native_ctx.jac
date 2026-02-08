"""Test native (na) context block parsing."""

na {
    def native_add(a: int, b: int) -> int {
        return a + b;
    }

    def native_mul(x: int, y: int) -> int {
        return x * y;
    }
}
