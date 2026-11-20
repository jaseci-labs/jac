"""Unannotated droppless locals with scalar-read-only uses are stack-promotable."""

obj Point {
    has x: int = 0,
        y: int = 0;
}

obj Loud {
    has n: int = 0;

    def drop {
        print("bye");
    }
}

def scalar_reads(n: int) -> int {
    t = 0;
    for i in range(n) {
        p = Point(x=i, y=i + 1);
        print(p.x);
        t = t + p.y;
    }
    return t;
}

def hooked(n: int) -> int {
    q = Loud(n=n);
    print(q.n);
    return q.n;
}

with entry {
    print(scalar_reads(2));
    print(hooked(5));
    print("end");
}
