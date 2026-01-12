with entry {
    foo: int = 42;
    foo = [1,2,3];  # <-- Error

    bar = [1,2,3];
    baz: list = bar;  # <-- Ok
}
