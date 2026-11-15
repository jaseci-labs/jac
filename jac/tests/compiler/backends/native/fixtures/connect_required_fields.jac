# A typed connect's attribute assignments build an edge whose constructor
# requires them: `a +>:E:f=v:+> b` passes the names `E` requires to its
# constructor, as `E(f=v)` would, and sets every other named field on the
# built edge afterwards, so a defaulted field still lands after `postinit`.
# Every value is evaluated in source order before the edge is built, and a
# value read from a field outlives a later value that replaces that field.
node Spot {
    has index: int;
}

edge Step: Spot --> Spot {
    has kind: int,
        target: int;
}

edge Named: Spot --> Spot {
    has label: str,
        weight: int = 1;

    def postinit {
        self.weight += 100;
    }
}

edge Span: Spot --> Spot {
    has lo: int = 0,
        hi: int = 0,
        note: str = "";

    def init(lo: int, width: int = 5) {
        self.lo = lo;
        self.hi = lo + width;
    }
}

edge Tagged: Spot --> Spot {
    has kind: int,
        note: str = "";
}

obj Holder {
    has text: str;
}

glob calls: int = 0,
     pads: list[str] = [];

def bump -> int {
    calls += 1;
    return calls;
}

def swap(h: Holder) -> int {
    h.text = "new" + str(len(h.text));
    pads.append("pad" + str(len(h.text)));
    return 9;
}

def link(a: Spot, b: Spot, kind: int) {
    a +>:Step:target=b.index, kind=kind:+> b;
}

with entry {
    a = Spot(index=0);
    b = Spot(index=1);
    a +>:Step:kind=2, target=b.index:+> b;
    for s in [edge a->:Step:->] {
        print("step", s.kind, s.target);
    }

    c = Spot(index=2);
    link(c, a, 4);
    print("in a function", [edge c->:Step:->][0].kind, [c->:Step:->][0].index);

    d = Spot(index=3);
    d <+:Step:kind=5, target=d.index:<+ c;
    print("backward", [edge c->:Step:->][1].kind, [edge c->:Step:->][1].target);

    e = Spot(index=4);
    e +>:Named:weight=7, label="n"+str(e.index):+> a;
    named = [edge e->:Named:->][0];
    print("named", named.label, named.weight);

    f = Spot(index=5);
    f +>:Named:label="kept":+> a;
    print("postinit kept", [edge f->:Named:->][0].weight);

    hub = Spot(index=6);
    hub +>:Step:kind=bump(), target=7:+> [Spot(index=7), Spot(index=8), Spot(index=9)];
    print("fan out", calls, len([edge hub->:Step:kind==1:->]));

    many = Spot(index=10);
    many +>:Named:label="fan"+str(bump()):+> [Spot(index=11), Spot(index=12)];
    labels = [n.label for n in [edge many->:Named:->]];
    print("fan out labels", calls, labels);

    g = Spot(index=13);
    g +>:Span:lo=3, note="custom":+> a;
    span = [edge g->:Span:->][0];
    print("custom init", span.lo, span.hi, span.note);

    h = Spot(index=14);
    h +>:Named:weight=bump(), label=str(bump()):+> a;
    ordered = [edge h->:Named:->][0];
    print("source order", ordered.weight, ordered.label);

    held = Holder(text="old" + str(calls));
    p = Spot(index=15);
    p +>:Tagged:note=held.text, kind=swap(held):+> a;
    tagged = [edge p->:Tagged:->][0];
    print("kept alive", tagged.note, tagged.kind, held.text);

    fan = Holder(text="old" + str(calls));
    q = Spot(index=16);
    q +>:Tagged:note=fan.text, kind=swap(fan):+> [Spot(index=17), Spot(index=18)];
    print("fan kept alive", [t.note for t in [edge q->:Tagged:->]], fan.text);
}
