class Foo {
    def first_is_self(self: Foo) -> None { }
    def with_default_args(self: Foo, a: int, b: int = 42) -> None { }
}

with entry {
    f = Foo();
    f.first_is_self();  # <-- Ok
    f.first_is_self(f);  # <-- Error

    f.with_default_args(1);  # <-- Ok
    f.with_default_args(1, 2);  # <-- Ok
    f.with_default_args(1, 2, 3);  # <-- Error
    f.with_default_args();  # <-- Error

    # Argument unpacking
    f.with_default_args(*[1, 2]);  # <-- Ok
}
