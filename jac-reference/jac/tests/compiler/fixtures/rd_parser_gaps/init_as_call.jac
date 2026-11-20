# init and postinit as impl target names (SpecialVarRef)
obj Foo {
    has val: int = 0;
}

impl Foo.init {
    self.val = 42;
}

impl Foo.postinit {
    print("done");
}
