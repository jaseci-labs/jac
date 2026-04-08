obj Foo {
    has x: int = 0;

    class def make() -> Self;
}

with entry {
    f = Foo.make();
    print(f"make: {f.x}");
}
