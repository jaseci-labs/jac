"""Opening a frozen region for allocation is mutation through imm (E1309)."""

obj Cell {
    has v: int = 0;
}

with entry {
    r: own Region = Region();
    in r {
        c = Cell(v=4);
        print(c.v);
    }
    fr = imm r;
    in fr {
        d = Cell(v=9);
        print(d.v);
    }
}
