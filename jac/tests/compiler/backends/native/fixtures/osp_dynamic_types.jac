"""Graph code that names its edge type or walker only at run time.

A connect (with field assignments), an edge filter or a delete through a `type[Edge]` value, and a spawn of a
walker typed `Walker`, lower natively: the edge type tag comes from the class
value, and the walker's own type tag and reports slot from its header.
"""
node Item {
    has n: int = 0;
}

edge Kid: Item --> Item {}

edge Link: Item --> Item {}

edge Weighted: Item --> Item {
    has w: int = 1;
}

edge Heavy(Weighted): Item --> Item {}

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

def link(a: Item, b: Item, role: type[Edge]) {
    a +>:(role):+> b;
}

def weigh(a: Item, b: Item, role: type[Weighted]) {
    a +>:(role):w=7:+> b;
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
    link(b, c, Kid);
    print(len([edge b->:Kid:->]), len([edge b->:Link:->]), len([b-->]));
    d = Item(n=4);
    weigh(c, d, Weighted);
    weigh(c, b, Heavy);
    print([e.w for e in [edge c->:Weighted:->]], len([edge c->:Heavy:->]));
    clear(a, Kid);
    print(len([edge a-->]), len([a-->]));
}
