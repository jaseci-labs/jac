"""Native OSP fixture: walker spawns on nodes, a typed entry ability reads
`here` and mutates walker `self` state, and `spawn` returns the walker."""

node Item {
    has val: int;
}

walker Collector {
    has total: int = 0;

    can grab with Item entry {
        self.total = self.total + here.val;
    }
}

def collect_two(a: int, b: int) -> int {
    c = Collector();
    c spawn Item(val=a);
    c spawn Item(val=b);
    return c.total;
}

def collect_one(v: int) -> int {
    return (Collector() spawn Item(val=v)).total;
}
