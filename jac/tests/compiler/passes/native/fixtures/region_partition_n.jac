"""partition(n) sugar over the same reabsorb contract: n children by
tuple unpack, each its own arena; drops fire once, at the parent's
death, child entries first, byte-identical across gc modes."""

obj Cell {
    has v: int = 0;

    def drop {
        print(f"drop {self.v}");
    }
}

def sugar {
    r: own Region = Region();
    in r {
        a0 = Cell(v=0);
        print(a0.v);
    }
    (c1, c2) = r.partition(2);
    in c1 {
        b = Cell(v=1);
        print(b.v);
    }
    in c2 {
        d = Cell(v=2);
        print(d.v);
    }
}

with entry {
    sugar();
    print("end");
}
