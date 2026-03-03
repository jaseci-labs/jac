"""Test: patterns that should NOT trigger warnings."""
obj Foo {
    has name: str;
    has count: int = 0;

    def bar(_unused: int) -> None {
        print(self.name);
    }
}
