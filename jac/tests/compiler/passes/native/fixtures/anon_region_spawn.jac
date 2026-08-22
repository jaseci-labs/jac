"""Unrooted spawn: the whole graph is local, connected only among locals,
and traversed by an expression-statement spawn -- the anonymous-region
inference anchors it to an implicit arena."""

node Item {
    has v: int;

    def drop {
        print(f"drop {self.v}");
    }
}

walker Sum {
    can add with Item entry {
        print(here.v);
        visit [-->];
    }
}

with entry {
    a = Item(v=1);
    b = Item(v=2);
    c = Item(v=3);
    a ++> b;
    b ++> c;
    Sum() spawn a;
    print("done");
}
