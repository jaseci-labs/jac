"""partition(n) sugar: unpacking an owned region into n owned child
handles, each independently affine and openable -- no diagnostics."""

obj Cell {
    has v: int = 0;
}

def use2 {
    r: own Region = Region();
    (a, b) = r.partition(2);
    in a {
        x = Cell(v=1);
        print(x.v);
    }
    in b {
        y = Cell(v=2);
        print(y.v);
    }
}

with entry {
    use2();
}
