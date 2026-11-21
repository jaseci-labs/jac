"""flow for over lent collections: element writes through &mut, scalar
and callee captures -- no diagnostics."""

obj P {
    has x: int = 0;
}

with entry {
    ps: list[P] = [P(x=1), P(x=2)];
    flow for m in &mut ps {
        m.x = m.x + 1;
    }
}

glob xs = [3, 4],
     n = 10;

with entry {
    flow for v in &xs {
        print(v + n);
    }
    print(ps[0].x + ps[1].x);
}
