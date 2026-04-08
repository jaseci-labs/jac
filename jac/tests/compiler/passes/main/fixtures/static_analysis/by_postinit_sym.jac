obj Foo {
    has msg: str by postinit;
    def postinit {
        self.msg = "hello";
    }
}

obj Bar {
    has msg: str by postinit;
    def postinit;
}

obj Baz;

impl Baz {
    has msg: str by postinit;
    def postinit;
}
