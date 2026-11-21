"""Same field twice: two mutable borrows of one field stay E1302."""

obj Inner {
    has n: int = 0;
}

obj Pair {
    has l: Inner = Inner(),
        r: Inner = Inner();
}

def touch(a: Inner, b: Inner) { }

with entry {
    p: own Pair = Pair();
    m1: &mut Inner = &mut p.l;
    m2: &mut Inner = &mut p.l;
    touch(m1, m2);
}
