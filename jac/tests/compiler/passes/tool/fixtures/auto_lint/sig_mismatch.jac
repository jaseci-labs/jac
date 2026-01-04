"""Test fixture for signature mismatch fixing between decl and impl."""

obj Calculator {
    has value: int = 0;

    def add(x: int, y: int) -> int;
    def multiply(a: int, b: int) -> int;
    def no_change(val: int) -> int;
}
