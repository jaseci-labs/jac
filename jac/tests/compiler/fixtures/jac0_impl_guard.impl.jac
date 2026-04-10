impl Foo.make() -> Self {
    return Self(x=1);
}

impl Foo.clone() -> Self {
    return Self(x=self.x + 100);
}

impl Foo.ghost_method() -> Self {
    return Self(x=999);
}
