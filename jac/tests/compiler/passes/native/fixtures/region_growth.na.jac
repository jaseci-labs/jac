"""Growth rule (#7491 OQ1): an ability allocating mid-traversal lands its
nodes/edges in region_of(here) with no &Region field on the walker; the
grown subgraph is reclaimed wholesale at the handle's drop."""

glob drop_log: int = 0;

node Spot {
    has v: int = 0;

    def drop {
        global drop_log;
        drop_log += 1;
    }
}

walker Grower {
    has made: int = 0;

    can g with Spot entry {
        if here.v < 3 {
            here ++> Spot(v=here.v + 1);
            self.made += 1;
            visit [-->];
        }
    }
}

def read_log -> int {
    return drop_log;
}

def scenario -> int {
    global drop_log;
    drop_log = 0;
    r: own Region = Region();
    made = 0;
    in r {
        seed = Spot(v=1);
        w = seed spawn Grower();
        made = w.made;
    }
    return made;
}
