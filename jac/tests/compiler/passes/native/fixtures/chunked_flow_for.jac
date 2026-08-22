"""Chunked flow for: per-chunk tasks over stack view headers into the
parent's element buffer -- mutation through the view, a reduction over
the join, and a plain sequential chunked for. Output must be identical
across gc modes, thread widths, and the Python backend."""

def scale(xs: &mut list[int], n: int) -> int {
    flow for chunk in &mut xs.chunks(n) {
        for j in range(len(chunk)) {
            chunk[j] = chunk[j] * 2 + 1;
        }
    }
    t = 0;
    flow for c in &xs.chunks(3) {
        t += len(c);
    }
    return t;
}

def tail_sum(xs: &list[int]) -> int {
    s = 0;
    for c in &xs.chunks(7) {
        s = s + c[len(c) - 1];
    }
    return s;
}

glob ys: own list[int] = [];

with entry {
    for i in range(100) {
        ys.append(i);
    }
    print(scale(&ys, 7));
    print(tail_sum(&ys));
    acc = 0;
    for v in ys {
        acc = (acc * 31 + v) % 1000000007;
    }
    print(acc);
}
