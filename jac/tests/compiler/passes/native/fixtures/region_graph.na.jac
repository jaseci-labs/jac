"""Region-resident topology (#7491 R3): nodes and edges allocated under an
open live in the arena; a walker traverses them while the handle is live,
and the handle's drop reclaims the whole subgraph (node drop hooks fire)."""

glob drop_log: int = 0;

node Spot {
    has v: int = 0;

    def drop {
        global drop_log;
        drop_log += 1;
    }
}

walker Sum {
    has total: int = 0;

    can s with Spot entry {
        self.total += here.v;
        visit [-->];
    }
}

def read_log -> int {
    return drop_log;
}

def scenario -> int {
    global drop_log;
    drop_log = 0;
    r: own Region = Region();
    total = 0;
    in r {
        a = Spot(v=1);
        b = Spot(v=2);
        a ++> b;
        w = a spawn Sum();
        total = w.total;
    }
    return total;
}
