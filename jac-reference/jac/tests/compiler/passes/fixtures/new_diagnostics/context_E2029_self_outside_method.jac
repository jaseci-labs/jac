"""Fixture for E2029: self used outside of archetype method."""

def standalone() -> None {
    print(self.x);  # <-- Error E2029
}

obj Foo {
    has x: int = 5;
    def method(self: Foo) -> int {
        return self.x;  # <-- Ok
    }
}
