impl Foo.make() -> Self {
    return Self(x=999);
}

impl Foo.clone() -> Self {
    return Self(x=self.x + 1001);
}
