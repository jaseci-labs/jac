"""Build-traverse-discard in a region under full zero-RC enforcement."""

obj Cell {
    has v: int = 0;

    def drop {
        print(f"drop {self.v}");
    }
}

def work -> int {
    t = 0;
    r: own Region = Region();
    in r {
        for i in range(3) {
            c = Cell(v=i);
            t = t + c.v;
        }
    }
    return t;
}

with entry {
    print(work());
    print("end");
}
