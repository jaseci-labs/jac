obj Counter;

obj Base {
    has seed: int = 7;

    def seeded -> int {
        return self.seed;
    }
}

obj Derived(Base);

impl Counter{
    has count: int = 0,
        label: str = "c";

    def bump(step: int) -> int;
    def show -> str {
        return f"{self.label}={self.count}";
    }
}

impl Counter.bump(step: int) -> int {
    self.count += step;
    return self.count;
}

impl Derived{
    has extra: int = 1;

    def total -> int {
        return self.seeded() + self.extra;
    }
}

with entry {
    c = Counter(count=2, label="k");
    print(c.bump(3), c.show());
    d = Counter();
    print(d.bump(1), d.show());
    e = Derived(seed=4, extra=5);
    print(e.total(), e.seed, e.extra);
}
