impl Foo.make() -> Self {
    return Self(x=1);
}

impl Foo.ghost_method() -> Self {
    return Self(x=999);
}
