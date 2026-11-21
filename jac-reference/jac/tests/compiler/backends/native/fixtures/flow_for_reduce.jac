"""Parallel flow for reductions under zero-RC enforcement: `+=` and
min/max accumulators become per-task partials that combine at the join,
so output is identical to the sequential managed modes and to any
thread width."""

def work(v: int) -> int {
    t = v;
    for i in range(150) {
        t = (t * 31 + i) % 1000003;
    }
    return t;
}

def build(n: int) -> list[int] {
    xs: list[int] = [];
    for i in range(n) {
        xs.append(work(i));
    }
    return xs;
}

with entry {
    xs = build(64);
    total = 100;
    lo = 1000000007;
    hi = -1;
    flow for v in &xs {
        total += v;
        lo = min(lo, v);
        hi = max(hi, v);
    }
    print(total);
    print(lo);
    print(hi);
    print("end");
}
