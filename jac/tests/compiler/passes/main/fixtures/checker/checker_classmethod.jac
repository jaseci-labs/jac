"""Test classmethod type checking."""

obj Foo {
    @classmethod
    def foo(cls: "Foo") { }
}

with entry {
    Foo.foo();  # <-- OK (No errors)
}
