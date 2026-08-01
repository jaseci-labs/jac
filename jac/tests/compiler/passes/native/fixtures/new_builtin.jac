obj Widget {
    has size: int;

    def area -> int {
        return self.size * self.size;
    }
}

obj Pair {
    has a: int = 0,
        b: int = 0;

    def init(a: int, b: int) {
        self.a = a;
        self.b = b;
    }
}

obj Tag {
    has v: int = 7;
}

def make_area(n: int) -> int {
    w = new(Widget, n);
    return w.area();
}

def make_sum(x: int, y: int) -> int {
    p = new(Pair, x, y);
    return p.a + p.b;
}

def make_tag -> int {
    t = new(Tag);
    return t.v;
}

with entry {
    print(make_area(5));
}
