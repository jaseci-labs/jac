obj T {
    has v: int = 0;

    def bump(n: int) -> None {
        self.v = self.v + n;
    }
}

obj Inverse {
    has fn: Callable | None = None,
        args: list[any] = [];

    def run -> None {
        if self.fn is not None {
            self.fn(*self.args);
        }
    }
}

with entry {
    t = T();
    inv = Inverse(fn=t.bump, args=[3]);
    inv.run();
    print(t.v);
}
