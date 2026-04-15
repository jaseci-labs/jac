impl Foo.make() -> Self {
    return Self(x=99);
}

impl Foo.clone() -> Self {
    return Self(x=self.x + 100);
}
