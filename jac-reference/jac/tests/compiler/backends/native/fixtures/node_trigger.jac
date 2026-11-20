"""`Node` as a trigger and as a collection element natively: an ability
triggered by `Node` runs at every node, and nodes held as `Node` keep their
identity in lists, sets and dicts (they used to lower to the string layout,
so two nodes of a type compared and hashed equal)."""

node Room {
    has tag: int = 0;
}

node Hall {
    has size: int = 0;
}

edge Door: Room --> Hall {}

walker Sweep {
    has starts: int = 0,
        visits: int = 0,
        seen: set[Node] = set();

    can begin with entry {
        self.starts += 1;
    }

    can sweep with Node entry {
        self.visits += 1;
        if here in self.seen {
            return;
        }
        self.seen.add(here);
        visit [-->];
        visit [<--];
    }
}

"""starts * 100 + distinct nodes swept."""
def sweep -> int {
    a = Room(tag=1);
    b = Hall(size=2);
    c = Room(tag=3);
    a +>:Door:+> b;
    b ++> c;
    c ++> a;
    w = a spawn Sweep();
    return w.starts * 100 + len(w.seen);
}

"""One digit per check, 1 when it holds."""
def identity -> int {
    a = Room(tag=1);
    c = Room(tag=1);
    h = Hall(size=1);
    s: set[Node] = set();
    s.add(a);
    l: list[Node] = [a];
    d: dict[Node, int] = {};
    d[a] = 1;
    d[c] = 2;
    s.add(c);
    s.add(h);
    got = 0;
    for ok in [a in s, len(s) == 3, not (c in l), a in l, len(d) == 2, d[a] == 1] {
        got = got * 10 + (1 if ok else 0);
    }
    return got;
}
