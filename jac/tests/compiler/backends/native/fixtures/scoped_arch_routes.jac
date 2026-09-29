"""One of two modules that each define `node Passage`, `edge Holds`,
`obj Info` and `walker Tally` (see `scoped_arch_main.jac`). Here a `Passage`
is a pair of ints and a list; `scoped_arch_rooms` lays its `Passage` out as a
float, a str and an int. Every use in this module means this module's types."""

node Area {
    has index: int;
}

node Passage {
    has kind: int,
        time: int,
        hops: list[int] = [];
}

edge Holds: Area --> Passage {
    has weight: int = 1;
}

obj Info {
    has cost: int,
        tags: list[int] = [];

    def total -> int {
        s = self.cost;
        for t in self.tags {
            s += t;
        }
        return s;
    }
}

walker Tally {
    has total: int = 0,
        seen: int = 0;

    can start with Area entry {
        visit [here->:Holds:->];
    }

    can count with Passage entry {
        self.total += here.kind * 100 + here.time + len(here.hops);
        self.seen += 1;
    }
}

def build_routes -> Area {
    a = Area(index=1);
    a +>:Holds(weight=3):+> Passage(kind=2, time=7, hops=[1, 2, 3]);
    a +>:Holds(weight=4):+> Passage(kind=5, time=11);
    return a;
}

def route_sum(a: Area) -> int {
    s = 0;
    for p in [a->:Holds:->][?:Passage] {
        s += p.kind + p.time + len(p.hops);
    }
    for e in [edge a->:Holds:->] {
        s += e.weight * 1000;
    }
    return s;
}

def route_tally(a: Area) -> int {
    t = a spawn Tally();
    return t.total * 10 + t.seen;
}

def route_info -> int {
    return Info(cost=5, tags=[1, 2]).total();
}

def is_route_passage(x: any) -> bool {
    return isinstance(x, Passage);
}
