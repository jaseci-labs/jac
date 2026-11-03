"""Graph code that names its edge type or walker only at run time.

An edge filter or a delete through a `type[Edge]` value, and a spawn of a
walker typed `Walker`, lower natively: the edge type tag comes from the class
value, and the walker's own type tag and reports slot from its header.
"""
node Item {
    has n: int = 0;
}

edge Kid: Item --> Item {}

edge Link: Item --> Item {}

walker Counter {
    has seen: int = 0;

    can visit_item with Item entry {
        self.seen += here.n;
        visit [-->];
    }
}

def attach(a: Item, b: Item, role: type[Edge]) -> int {
    return len([edge a->:role:->]);
}

def run(start: Item, w: Walker) -> Walker {
    start spawn w;
    return w;
}

def clear(a: Item, role: type[Edge]) {
    del [edge a->:role:->];
}

with entry {
    a = Item(n=1);
    b = Item(n=2);
    c = Item(n=3);
    a +>:Kid:+> b;
    a +>:Link:+> c;
    print(attach(a, b, Kid), attach(a, c, Link), len([edge a-->]));
    w = Counter();
    run(a, w);
    print(w.seen);
    clear(a, Kid);
    print(len([edge a-->]), len([a-->]));
}
