"""Seal adoption at runtime: a region-built subgraph attached to a
managed anchor is promoted -- traversable from the anchor after the open
closes, no region teardown ever runs (the drop hooks stay silent,
exactly like a graph built managed)."""

node Anchor {}

node Item {
    has v: int;

    def drop {
        print(f"drop {self.v}");
    }
}

walker Sum {
    can start with Anchor entry {
        visit [-->];
    }

    can add with Item entry {
        print(here.v);
        visit [-->];
    }
}

with entry {
    anchor = Anchor();
    r: own Region = Region();
    in r {
        a = Item(v=1);
        b = Item(v=2);
        a ++> b;
        anchor ++> a;
    }
    Sum() spawn anchor;
    print("end");
}
