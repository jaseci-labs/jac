"""Region arena behavior fixtures (#7491 R1): dtor-log LIFO order, named
handle drop points (reassignment and scope exit), early return inside an
open, and managed values crossing an open safely.

`drop_log` encodes hook firing order in base 10: log = log * 10 + id.
"""

glob drop_log: int = 0;

obj Res {
    has id: int = 0;

    def drop {
        drop_log = drop_log * 10 + self.id;
    }
}

obj Box {
    has v: int = 0;
}

def read_log -> int {
    return drop_log;
}

def dtor_order -> int {
    drop_log = 0;
    in Region() {
        a: own Res = Res(id=1);
        b: own Res = Res(id=2);
        c: own Res = Res(id=3);
    }
    return drop_log;
}

def named_handle -> int {
    drop_log = 0;
    r = Region();
    in r {
        a: own Res = Res(id=7);
    }
    before = drop_log;
    r = Region();
    mid = drop_log;
    in r {
        b: own Res = Res(id=9);
    }
    return (before * 10000) + (mid * 100) + drop_log;
}

def early_return(flag: int) -> int {
    drop_log = 0;
    in Region() {
        a: own Res = Res(id=5);
        if flag > 0 {
            return drop_log;
        }
    }
    return 100 + drop_log;
}

def mixed_managed(n: int) -> int {
    total = 0;
    acc = [];
    i = 0;
    while i < n {
        in Region() {
            b: own Box = Box(v=i);
            acc.append(b.v);
        }
        i = i + 1;
    }
    for v in acc {
        total = total + v;
    }
    return total;
}
