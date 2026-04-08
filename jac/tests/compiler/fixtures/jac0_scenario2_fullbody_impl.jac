obj Foo {
    has x: int = 0;

    class def make() -> Self {
        return Self(x=1);
    }

    def clone() -> Self {
        return Self(x=self.x);
    }
}

impl Foo.make() -> Self {
    return Self(x=99);
}

impl Foo.clone() -> Self {
    return Self(x=self.x + 100);
}

impl Foo.non_decl_func{
        print("I should make error after decl impl matchpass or semantic analysis pass");
}

with entry {
    f = Foo.make();
    print(f"make: {f.x}");

    g = Foo(x=5);
    h = g.clone();
    print(f"clone: {h.x}");
}
