"""Sub-arena partition: children draw from the parent conceptually --
in the v1 runtime each child is its own arena whose death reabsorbs its
chunks and dtor log into the parent, so every drop fires exactly once,
at the parent's death, and a child outliving its parent (zombie parent)
defers the whole teardown to the last reabsorb."""

obj Cell {
    has v: int = 0;

    def drop {
        print(f"drop {self.v}");
    }
}

def straight {
    r: own Region = Region();
    in r {
        a = Cell(v=0);
        print(a.v);
    }
    c1: own Region = r.partition();
    in c1 {
        b = Cell(v=1);
        print(b.v);
    }
    c2: own Region = r.partition();
    in c2 {
        d = Cell(v=2);
        print(d.v);
    }
}

def _mk -> Region {
    r: own Region = Region();
    in r {
        f = Cell(v=8);
        print(f.v);
    }
    return r.partition();
}

def zombie {
    c = _mk();
    in c {
        e = Cell(v=9);
        print(e.v);
    }
    print("before-c-drop");
}

with entry {
    straight();
    print("mid");
    zombie();
    print("end");
}
