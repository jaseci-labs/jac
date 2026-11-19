obj T {
    has v: int = 0;

    def bump(n: int) -> None {
        self.v = self.v + n;
    }
}

obj Holder {
    has fn: Callable;
    has args: list[any] = [];

    def run -> None {
        self.fn(*self.args);
    }
}

with entry {
    t = T();
    h = Holder(fn=t.bump, args=[3]);
    h.run();
    print(t.v);
}
