"""`super.init(...)` reaching the initializer an `obj` derives from its fields."""

enum Kind { A = "a", B = "b" }

obj Tag {
    has label: str;
}

obj Shape {
    has kind: Kind;

    def area -> float abst;
}

obj Square(Shape) {
    has side: float;

    def init(side: float) {
        self.side = side;
        super.init(Kind.A);
    }

    override def area -> float {
        return self.side * self.side;
    }
}

obj Base {
    has kind: Kind,
        name: str,
        tags: list[str],
        tag: Tag;
}

obj Mid(Base) {}

obj Leaf(Mid) {
    has extra: int;

    def init(extra: int, nm: str) {
        super.init(Kind.B, name=nm + "!", tags=["x", nm], tag=Tag(label=nm));
        self.extra = extra;
    }
}

obj Pair {
    has x: int,
        y: int;
}

obj PairChild(Pair) {
    def init {
        self.x = 9;
        super.init(1, self.x);
    }
}

obj Named {
    has first: str,
        second: str;
}

obj NamedChild(Named) {
    def init(seed: str) {
        self.first = seed + "-old";
        super.init(seed + "-new", self.first);
    }
}

with entry {
    sq = Square(3.0);
    print(sq.kind.value, sq.side, sq.area());
    for i in range(3) {
        leaf = Leaf(i, f"n{i}");
        print(leaf.extra, leaf.kind.value, leaf.name, leaf.tags, leaf.tag.label);
    }
    pc = PairChild();
    print(pc.x, pc.y);
    for i in range(3) {
        nc = NamedChild(f"s{i}");
        print(nc.first, nc.second);
    }
}
