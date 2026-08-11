"""Rooted graph: one connect touches root, so the component may reach
managed state -- the anonymous-region inference must decline."""

node Item {
    has v: int;
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
    root ++> a;
    a ++> b;
    Sum() spawn a;
    print("done");
}
