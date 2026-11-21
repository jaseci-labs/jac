"""Test fixture for nested class signature preservation.

This tests that auto-lint does NOT corrupt nested class impl signatures
by incorrectly matching them to parent class signatures.
"""

obj OuterClass {
    has value: int = 0;

    # Parent class init with its own signature
    def init(self: OuterClass, shared: int, private: int) -> None;

    # Nested class with DIFFERENT init signature
    class InnerClass {
        def init(self: InnerClass, name: str) -> None;
    }

    # Another nested class with yet another signature
    class AnotherInner {
        def init(
            self: AnotherInner,
            x: int,
            y: int,
            *,
            z: int = 0
        ) -> None;
    }

    def process(data: str) -> str;
}
