"""An ability triggered by the base `Node` sees the concrete type of each
node it visits."""
node Room {
    has tag: int = 0;
}

node Hall {
    has size: int = 0;
}

walker Sweep {
    has seen: list[Node] = [],
        kinds: list[str] = [];

    can sweep with Node entry {
        if here in self.seen {
            return;
        }
        self.seen.append(here);
        self.kinds.append(type(here).__name__);
        visit [-->];
    }
}

with entry {
    a = Room(tag=1);
    b = Hall(size=2);
    c = Room(tag=3);
    a ++> b;
    b ++> c;
    c ++> a;
    w = a spawn Sweep();
    print(len(w.seen), sorted(w.kinds));
}
