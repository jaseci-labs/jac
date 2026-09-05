obj Counter {
    has n: int = 0;

    def get -> int { return self.n; }
    def twice -> int { return self.get() * 2; }
}

def show(c: &Counter) -> int { return c.n; }

with entry {
    c: own Counter = Counter();
    v: &Counter = &c;
    print(c.twice());
    print(show(v));
}
