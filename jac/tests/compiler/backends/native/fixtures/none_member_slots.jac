"""A none-typed member is a real one-word slot in every aggregate."""

obj Holder {
    has tag: int = 1,
        gap: None = None,
        tail: int = 3;
}

def pair(x: int) -> tuple[int, None] {
    return (x, None);
}

with entry {
    p = pair(2);
    (a, b) = p;
    print(p, a, b, p == (2, None), p[1] is None);
    xs: list[tuple[int, None]] = [p, (5, None)];
    print(xs, len(xs), xs[1][0]);
}

glob n: list[None] = [None, None];

with entry {
    print(n, n[0], len(n));
}

glob d: dict[str, None] = {"a": None};

with entry {
    print(d, d["a"], "a" in d);
    z: any = p;
    print(z, z == p);
    h = Holder();
    print(h.tag, h.gap, h.tail);
}
