obj T {
    has v: int = 0;

    def bump(n: int) -> None {
        self.v = self.v + n;
    }

    def reset -> None {
        self.v = 0;
    }
}

with entry {
    t = T();
    f: Callable[[int], None] = t.bump;
    f(2);
    print(t.v);
}
