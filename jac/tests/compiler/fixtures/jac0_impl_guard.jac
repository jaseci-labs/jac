obj Foo {
    has x: int = 0;

    class def make() -> Self;

    def clone() -> Self {
        return Self(x=self.x);
    }
}

with entry {
    f = Foo.make();
    print(f"make: {f.x}");

    g = Foo(x=5);
    h = g.clone();
    print(f"clone: {h.x}");
}
