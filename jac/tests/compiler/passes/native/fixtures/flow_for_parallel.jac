"""Parallel flow for under zero-RC enforcement: element writes through
disjoint &mut lends, deterministic post-join state, output identical to
the sequential managed modes."""

obj P {
    has x: int = 0,
        y: int = 0;
}

def build(n: int) -> list[P] {
    ps: list[P] = [];
    for i in range(n) {
        ps.append(P(x=i, y=0));
    }
    return ps;
}

def work(v: int) -> int {
    t = v;
    for i in range(200) {
        t = (t * 31 + i) % 1000003;
    }
    return t;
}

with entry {
    ps = build(64);
}

glob k = 7;

with entry {
    flow for m in &mut ps {
        m.y = work(m.x) + k;
    }
    total = 0;
    for i in range(len(ps)) {
        total = (total + ps[i].y * (i + 1)) % 1000000007;
    }
    print(total);
    print("end");
}
