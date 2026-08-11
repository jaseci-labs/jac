"""Escaping member: a node local passed to a call may be retained
anywhere -- the anonymous-region inference must decline."""

node Item {
    has v: int;
}

walker Sum {
    can add with Item entry {
        print(here.v);
        visit [-->];
    }
}

def stash(n: Item) -> int {
    return n.v;
}

with entry {
    a = Item(v=1);
    b = Item(v=2);
    a ++> b;
    stash(a);
    Sum() spawn a;
    print("done");
}
