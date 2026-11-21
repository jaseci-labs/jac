"""Fixture: @classmethod and @staticmethod on obj should warn."""

obj Foo {
    @classmethod
    def bar(cls: type) -> str {
        return "hello";
    }

    @staticmethod
    def baz() -> str {
        return "world";
    }
}
