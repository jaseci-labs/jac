"""Page sharing under partition: children draw default-size pages from
the parent (runs amortize the mallocs), a grandchild's runs splice to
its parent at reabsorb, and teardown frees runs exactly once -- digest
identical across gc modes."""

obj Cell {
    has a: int = 0,
        b: int = 0,
        c: int = 0;
}

def run -> int {
    total = 0;
    r: own Region = Region();
    (c1, c2) = r.partition(2);
    in c1 {
        for i in range(3000) {
            x = Cell(a=i, b=i * 2, c=i * 3);
            total = (total + x.a + x.b + x.c) % 1000000007;
        }
    }
    g1: own Region = c1.partition();
    in g1 {
        for i in range(3000) {
            y = Cell(a=i, b=1, c=2);
            total = (total + y.a + y.c) % 1000000007;
        }
    }
    in c2 {
        for i in range(3000) {
            z = Cell(a=1, b=i, c=2);
            total = (total + z.b) % 1000000007;
        }
    }
    return total;
}

with entry {
    print("pgshare:" + str(run()));
    print("end");
}
