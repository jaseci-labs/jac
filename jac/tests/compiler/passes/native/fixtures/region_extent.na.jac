"""Dynamic extent (#7491 R2): a handle is created in one function, extended
through a Region-typed parameter in another, and dropped by the caller at
scope exit. drop_log encodes hook order: log = log * 10 + id."""

glob drop_log: int = 0;

obj Res {
    has id: int = 0;

    def drop {
        global drop_log;
        drop_log = drop_log * 10 + self.id;
    }
}

def read_log -> int {
    return drop_log;
}

def make -> Region {
    r = Region();
    in r {
        a: own Res = Res(id=1);
    }
    return r;
}

def grow(r: Region, id: int) {
    in r {
        a: own Res = Res(id=id);
    }
}

def scenario -> int {
    global drop_log;
    drop_log = 0;
    r = make();
    grow(r, 2);
    grow(r, 3);
    return drop_log;
}
