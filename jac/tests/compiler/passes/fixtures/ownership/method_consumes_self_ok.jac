obj Counter {
    has n: int = 0;

    def into_total(self: own Counter) -> int { return self.n; }
}

with entry {
    c: own Counter = Counter(n=3);
    print(c.into_total());
}
