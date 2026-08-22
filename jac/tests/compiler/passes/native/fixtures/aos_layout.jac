"""list[own T] stores elements inline and contiguous under enforced
headerless codegen (#7870 item 3): appends move the fresh payload into
the buffer (one allocation per grow, none per element), reads yield
interior pointers, and container drop tears elements down in place,
hooks first. Managed modes keep pointer elements with byte-identical
output -- the annotation erases."""

obj Cell {
    has a: int = 0,
        b: float = 0.0;

    def drop {
        print(f"drop {self.a}");
    }
}

def build(n: int) -> list[own Cell] {
    xs: list[own Cell] = [];
    for i in range(n) {
        xs.append(Cell(a=i, b=i * 0.5));
    }
    return xs;
}

def scan(xs: &list[own Cell]) -> int {
    t = 0;
    for i in range(len(xs)) {
        t = (t + xs[i].a * 3 + int(xs[i].b)) % 1000003;
    }
    return t;
}

def run {
    xs = build(12);
    print(scan(&xs));
}

with entry {
    run();
    print("end");
}
