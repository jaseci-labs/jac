impl Foo.make() -> Self {
    return Self(x=1);
}

impl Foo.make_fake() -> Self {
    return Self(x=self.x);
}
