"""Two mutable borrows of disjoint fields of one owner may coexist."""

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
    ml: &mut Inner = &mut p.l;
    mr: &mut Inner = &mut p.r;
    touch(ml, mr);
}
