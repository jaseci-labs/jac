"""Dynamic extent (#8913): a helper called under an open allocates into the
caller's region, so its drop hooks fire at the handle's death, LIFO, not at
the helper's frame exit. drop_log encodes hook order: log = log * 10 + id."""

glob drop_log: int = 0;

obj Res {
    has id: int = 0;

    def drop {
        drop_log = drop_log * 10 + self.id;
    }
}

def build(id: int) -> Res {
    return Res(id=id);
}

def read_log -> int {
    return drop_log;
}

def scenario -> int {
    drop_log = 0;
    t = 0;
    r: own Region = Region();
    in r {
        a = build(1);
        b = build(2);
        t = a.id + b.id;
    }
    return t;
}
