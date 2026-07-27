"""Must-pass under --enforce-nogc: fully annotated ownership coverage."""

obj Point {
    has x: float = 0.0,
        y: float = 0.0;
}

def total(pts: &list[int]) -> int {
    s = 0;
    for v in pts {
        s += v;
    }
    return s;
}

def make_point(x: float, y: float) -> Point {
    p: own Point = Point(x=x, y=y);
    return p;
}

def run_all {
    data = [1, 2, 3, 4];
    print(total(&data));
    q = make_point(1.5, 2.5);
    print(q.x + q.y);
}

with entry {
    run_all();
}
