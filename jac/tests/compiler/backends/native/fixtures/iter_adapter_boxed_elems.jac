"""Lazy adapters over lists of tuples and objects yield each element by its layout."""

obj Tok {
    has kind: str,
        width: int;
}

def named_pairs(n: int) -> own list[tuple[str, int]] {
    out: list[tuple[str, int]] = [];
    for k in range(n) {
        item: own tuple[str, int] = (f"w{k}", k * 10);
        out.append(item);
    }
    return out;
}

def int_pairs(n: int) -> own list[tuple[int, int]] {
    out: list[tuple[int, int]] = [];
    for k in range(n) {
        item: own tuple[int, int] = (k, k * 7);
        out.append(item);
    }
    return out;
}

def tokens -> own list[Tok] {
    return [Tok(kind="name", width=4), Tok(kind="op", width=1)];
}

def pair_weight(p: &tuple[str, int]) -> int {
    return len(p[0]) + p[1];
}

def heavy(p: &tuple[str, int]) -> bool {
    return p[1] > 5;
}

def enumerated -> int {
    total = 0;
    for (i, m) in enumerate(named_pairs(3)) {
        print("enum", i, m[0], m[1]);
        total += i + m[1];
    }
    for (j, q) in enumerate(int_pairs(3)) {
        print("enum-int", j, q[0], q[1], q[0] + q[1]);
        total += q[0] * q[1];
    }
    return total;
}

def zipped -> int {
    total = 0;
    for (a, b) in zip(named_pairs(3), [100, 200]) {
        print("zip", a[0], a[1], b);
        total += a[1] + b;
    }
    for (c, d) in zip(int_pairs(2), named_pairs(3)) {
        print("zip-both", c[0], c[1], d[0], d[1]);
        total += c[1] + d[1];
    }
    return total;
}

def mapped -> int {
    total = 0;
    for v in map(pair_weight, named_pairs(3)) {
        print("map", v);
        total += v;
    }
    for p in filter(heavy, named_pairs(3)) {
        print("filter", p[0], p[1]);
        total += p[1];
    }
    return total;
}

def objects -> int {
    total = 0;
    for (i, t) in enumerate(tokens()) {
        print("obj", i, t.kind, t.width);
        total += t.width;
    }
    for (u, w) in zip(tokens(), [9, 8]) {
        print("obj-zip", u.kind, w);
        total += w;
    }
    return total;
}

with entry {
    for rep in range(3) {
        print(enumerated(), zipped(), mapped(), objects());
    }
}
