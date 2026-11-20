"""Test: bare assignment to a has var name inside an obj method should still warn (use self.x instead)."""

obj Foo {
    has x: int = 0;

    def bar -> None {
        x = 5;
    }
}
