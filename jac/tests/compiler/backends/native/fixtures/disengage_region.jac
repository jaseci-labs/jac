node Box {
    has n: int = 0;
}

walker Visit {
    has seen: int = 0;

    can go with Box entry {
        self.seen += here.n;
        if here.n > 1 {
            disengage;
        }
        self.seen += 100;
    }
}

def:pub spawn_disengaging_in_region -> int {
    r = Region();
    total = 0;
    in r {
        b = Box(n=5);
        v = Visit();
        b spawn v;
        total = v.seen;
    }
    return total;
}

def:pub spawn_finishing_in_region -> int {
    r = Region();
    total = 0;
    in r {
        b = Box(n=1);
        v = Visit();
        b spawn v;
        total = v.seen;
    }
    return total;
}
