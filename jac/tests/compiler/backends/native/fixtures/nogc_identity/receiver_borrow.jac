"""A method that hands back its receiver returns a borrow: `with ... as q`
over an `__enter__` returning `self`, a fluent setter on a local, and a
`-> &str` view of a field all leave the object with its one owner. On a
temporary the receiver itself comes back, owned by the caller."""

obj Quiet {
    has hits: int = 0;

    def __enter__ -> Quiet {
        self.hits += 1;
        return self;
    }

    def __exit__(a: int, b: int, c: int) -> bool {
        return True;
    }
}

obj Builder {
    has items: list[int] = [],
        label: str = "";

    def add(x: int) -> Builder {
        self.items.append(x);
        return self;
    }

    def name -> &str {
        return self.label;
    }
}

def guarded(i: int) -> int {
    with Quiet() as q {
        if i % 3 == 0 {
            raise ValueError(f"quiet {i}");
        }
        return q.hits + i;
    }
    return 1;
}

def fluent(i: int) -> int {
    b = Builder(label=f"b{i}").add(i).add(2);
    c = Builder();
    d = c.add(3);
    v = b.name();
    return len(b.items) + len(d.items) + len(c.items) + len(v);
}

with entry {
    total = 0;
    for i in range(30) {
        try {
            total += guarded(i);
        } except ValueError {
            total += 100;
        }
        total += fluent(i);
    }
    print(total);
}
