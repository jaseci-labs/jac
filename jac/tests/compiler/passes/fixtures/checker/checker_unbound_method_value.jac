"""An instance method read through its class is a function of the receiver."""

obj Counter {
    has n: int = 0;

    def bump(step: int) -> int {
        self.n += step;
        return self.n;
    }

    def label -> str {
        return f"n={self.n}";
    }
}

def apply(f: Callable[[Counter, int], int], c: Counter) -> int {
    return f(c, 5);
}

with entry {
    c = Counter();
    direct: int = Counter.bump(c, 2);
}

glob m = Counter.bump;

with entry {
    through_name: int = m(c, 3);
    through_callable: int = apply(Counter.bump, c);
}

glob fs = [Counter.label];

with entry {
    through_list: str = fs[0](c);
    bound: int = c.bump(1);
    print(direct, through_name, through_callable, through_list, bound);
}

def doubled_bump(self: Counter, step: int) -> int {
    self.n += step * 2;
    return self.n;
}

glob saved = Counter.bump;

with entry {
    Counter.bump = doubled_bump;
    Counter.bump = saved;
}
