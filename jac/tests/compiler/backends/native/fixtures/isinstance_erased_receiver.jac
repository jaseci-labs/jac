"""`isinstance` against a module-level tuple of classes, on nodes popped from a list."""

node Base {
    has label: str = "";
}

node Leaf(Base) {}

node Other(Base) {}

glob REJECT: tuple[type[Leaf]] = (Leaf, );

def count_rejected(xs: list[Base]) -> int {
    n = 0;
    work: list[Base] = list(xs);
    while work {
        nd = work.pop();
        if isinstance(nd, REJECT) {
            n += 1;
            continue;
        }
    }
    return n;
}

with entry {
    print(count_rejected([Leaf(), Other(), Leaf(), Base()]));
}
