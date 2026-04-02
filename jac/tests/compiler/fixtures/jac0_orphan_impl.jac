obj Foo {
    has x: int = 0;

    class def make() -> Self {
        return Self(x=1);
    }

    def clone() -> Self {
        return Self(x=self.x);
    }

    def equals(other: Self) -> bool {
        return self.x == other.x;
    }
}

with entry {
    f = Foo.make();
    print(f"make: {f.x}");

    g = Foo(x=5);
    h = g.clone();
    print(f"clone: {h.x}");

    print(f"equals: {g.equals(h)}");
}
