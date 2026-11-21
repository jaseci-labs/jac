"""Depth cap: paths deeper than one field collapse to the whole object (conservative)."""

obj Inner {
    has n: int = 0;
}

obj Pair {
    has l: Inner = Inner(),
        r: Inner = Inner();
}

def use_int(x: int) { }

with entry {
    p: own Pair = Pair();
    v: &int = &p.l.n;
    p.r = Inner();
    use_int(v);
}
