"""A walker ability triggered by `Node` runs at every node, whatever its
type; a bare `with entry` runs once, when the walk starts."""

node Room {
    has tag: int = 0;
}

node Hall {
    has size: int = 0;
}

edge Door: Room --> Hall {}

walker Sweep {
    has starts: int = 0,
        seen: list[Node] = [],
        kinds: list[str] = [];

    can begin with entry {
        self.starts += 1;
    }

    can sweep with Node entry {
        if here in self.seen {
            return;
        }
        self.seen.append(here);
        self.kinds.append(type(here).__name__);
        visit [-->];
        visit [<--];
    }
}

with entry {
    a = Room(tag=1);
    b = Hall(size=2);
    c = Room(tag=3);
    a +>:Door:+> b;
    b ++> c;
    c ++> a;
    w = a spawn Sweep();
    print("starts", w.starts, "seen", len(w.seen), sorted(w.kinds));
}
