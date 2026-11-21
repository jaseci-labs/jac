obj Counter {
    has n: int = 0;

    def into_total(self: own Counter) -> int { return self.n; }
}

with entry {
    c: own Counter = Counter(n=3);
    t = c.into_total();
    print(c.n);
}
