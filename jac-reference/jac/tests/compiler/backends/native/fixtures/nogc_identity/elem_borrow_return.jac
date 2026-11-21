"""A function returning a borrow of a list element under a `-> &T` return
type (#8984 A4)."""

obj Item { has v: int = 0; }

def biggest(xs: &list[Item]) -> &Item {
    best = 0;
    for i in range(len(xs)) {
        if xs[i].v > xs[best].v { best = i; }
    }
    return &xs[best];
}

def run -> int {
    xs: list[own Item] = [];
    xs.append(Item(v=1));
    xs.append(Item(v=9));
    xs.append(Item(v=4));
    return biggest(&xs).v;
}

with entry { print(run()); }
