obj Foo {
    has msg: str postinit;
    def postinit {
        self.msg = "hello";
    }
}

obj Bar {
    has msg: str postinit;
    def postinit;
}

obj Baz;

impl Baz {
    has msg: str postinit;
    def postinit;
}
