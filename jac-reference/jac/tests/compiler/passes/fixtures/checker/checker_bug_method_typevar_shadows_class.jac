"""A method's own type parameter shadows the class's parameter of the same name."""

obj Leaf {
    has num: int = 0;
}

obj Box[T] {
    has item: (T | None) = None;

    def stash(v: T) {
        self.item = v;
    }

    def echo[T](other: T) -> T {
        return other;
    }
}

def drive -> int {
    b = Box[Leaf]();
    b.stash(Leaf(num=2));
    n = b.echo(7);
    s = b.echo("x");
    return n + len(s);
}
