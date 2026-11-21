obj Foo {
    has x: int = 0;

    class def make() -> Self {
        return Self(x=1);
    }

    def clone() -> Self {
        return Self(x=self.x);
    }
}
