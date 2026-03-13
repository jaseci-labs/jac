"""Fixture for E0076: Class body contains duplicate method definitions."""

obj Foo {
    def bar(self: Foo) -> None { }
    def baz(self: Foo) -> None { }  # <-- Ok: different name
    def bar(self: Foo) -> int {     # <-- Error E0076: duplicate 'bar'
        return 0;
    }
}
