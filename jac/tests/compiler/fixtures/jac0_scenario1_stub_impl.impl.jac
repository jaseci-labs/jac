impl Foo.make() -> Self {
    return Self(x=1);
}

impl Foo.clone() -> Self {
    return Self(x=self.x);
}
