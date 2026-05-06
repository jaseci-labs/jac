obj Foo {
    has x: int = 0;

    class def make() -> Self;

    def clone() -> Self;
}

impl Foo.make() -> Self {
    return Self(x=1);
}

impl Foo.clone() -> Self {
    return Self(x=self.x);
}
