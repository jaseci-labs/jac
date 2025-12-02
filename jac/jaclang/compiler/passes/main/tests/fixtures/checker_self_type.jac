node Foo {
    has i: int = 0;

    def foo() {
        y: int = self.i;  # <-- Ok
        x: str = self.i;  # <-- Error
    }
}
