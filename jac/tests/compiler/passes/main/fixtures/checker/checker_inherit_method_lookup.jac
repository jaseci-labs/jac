obj Foo {
    def compile()  -> None {
        return None;
    }
}

obj Bar(Foo) {
    def some() {
        self.compile();  # <-- Ok: should resolve to Foo.compile()
    }
}

with entry {
    b = Bar();
    b.compile();  # <-- Ok
    b.some();  # <-- Ok
}
