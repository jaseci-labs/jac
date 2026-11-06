"""Tuples of C scalars come back from a call by value, and every consumer that
needs a tuple object still gets one.

`ordered`, `scaled` and the imported `split_ratio` return a register pair
instead of a heap tuple; the cases below destructure the result, index it,
store it in a local, a glob, a field, a list and an optional, return it
through another function, pass it to a `tuple[...]` parameter, and call it
through a `Callable`, a method, a lambda and a nested function.
"""
import from tuple_return_byvalue_lib { split_ratio, Extent }

obj Holder {
    has span: tuple[int, int] = (0, 0);
}

obj Shape {
    def bounds -> tuple[int, int] {
        return (1, 2);
    }
}

obj Wide(Shape) {
    override def bounds -> tuple[int, int] {
        return (10, 20);
    }
}

obj Countdown {
    has n: int = 3;

    def __iter__ -> Countdown {
        return self;
    }

    def __next__ -> tuple[int, int] {
        if self.n <= 0 {
            raise StopIteration();
        }
        self.n -= 1;
        return (self.n, self.n * self.n);
    }
}

def ordered(a: int, b: int) -> tuple[int, int] {
    if a > b {
        return (b, a);
    }
    return (a, b);
}

def scaled(p: ptr[u8], x: f64) -> tuple[ptr[u8], f64] {
    return (p, x * 2.0);
}

def checked(n: int) -> tuple[bool, int] {
    return (n > 3, n * 10);
}

def labeled(n: int) -> tuple[str, int] {
    return (f"n{n}", n);
}

def forwarded(a: int, b: int) -> tuple[int, int] {
    return ordered(a, b);
}

def through_local(a: int) -> tuple[int, int] {
    kept = ordered(a + 1, a);
    return kept;
}

def from_field(h: Holder) -> tuple[int, int] {
    return h.span;
}

def maybe_ordered(a: int) -> (tuple[int, int] | None) {
    if a < 0 {
        return None;
    }
    return ordered(a, 2);
}

def total(t: tuple[int, int]) -> int {
    return t[0] + t[1];
}

def apply(f: Callable[[int, int], tuple[int, int]], a: int) -> int {
    (x, y) = f(a, a + 1);
    return x * 100 + y;
}

def nested(n: int) -> int {
    def inner(k: int) -> tuple[int, int] {
        return (k + n, k - n);
    }
    (p, q) = inner(10);
    return p * q;
}

glob latest: tuple[int, int] = (0, 0);

with entry {
    (lo, hi) = ordered(9, 3);
    print("destructured", lo, hi);
    pair = ordered(5, 1);
    print("indexed", pair[0], pair[1], pair);
    print("inline index", ordered(8, 7)[1]);
    print("as argument", total(ordered(2, 40)));
    latest = ordered(12, 11);
    print("glob", latest);
    (p, scale) = scaled(ptr[u8](), 1.25);
    print("ptr and f64", p == ptr[u8](), scale);
    (ok, tens) = checked(5);
    print("bool element", ok, tens, checked(1));
    (name, num) = labeled(7);
    print("managed element", name, num);
    (f1, f2) = forwarded(2, 1);
    print("forwarded", f1, f2);
    print("through local", through_local(4));
    h = Holder(span=(6, 7));
    print("from field", from_field(h));
    h.span = ordered(30, 20);
    print("into field", h.span);
    m = maybe_ordered(5);
    if m is not None {
        print("optional", m[0], m[1]);
    }
    print("optional none", maybe_ordered(-1));
}

glob spans: list[tuple[int, int]] = [];

with entry {
    for i in range(3) {
        spans.append(ordered(10, i));
    }
    print("list", spans);
    acc = 0;
    for i in range(1000) {
        (a, b) = ordered(i, 500);
        acc += b - a;
    }
    print("loop", acc);
    for e in ordered(4, 3) {
        print("iterated", e);
    }
    print("compared", ordered(3, 4) == (3, 4));
    (half, quarter) = split_ratio(10);
    print("imported", half, quarter);
    ext = Extent();
    (w, ht) = ext.dims();
    print("imported method", w, ht, ext.dims());
    shapes: list[Shape] = [Shape(), Wide()];
    for s in shapes {
        (b0, b1) = s.bounds();
        print("override", b0, b1, s.bounds());
    }
    print("callable", apply(ordered, 4));
}

glob swap = lambda (a: int, b: int) -> tuple[int, int] { return (b * 3, a * 2); };

with entry {
    print("lambda", apply(swap, 5));
    print("nested", nested(3));
    for (k, sq) in Countdown() {
        print("user iterator", k, sq);
    }
    for pr in map(checked, [5, 1]) {
        print("map", pr);
    }
    print("comprehension", [ordered(i, 1) for i in range(3)]);
    print("dict value", {i: ordered(2, i) for i in range(2)});
}
