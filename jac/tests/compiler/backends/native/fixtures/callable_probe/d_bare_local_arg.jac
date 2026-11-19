obj T {
    has v: int = 0;

    def bump(n: int) -> None {
        self.v = self.v + n;
    }
}

with entry {
    t = T();
    f: Callable = t.bump;
    f(4);
    print(t.v);
}
