"""Storing an owned value into an own-typed field keeps it in the owned world."""

obj Buffer {
    has n: int = 0;
}

obj Holder {
    has ref: own Buffer = Buffer();
}

def take_holder(h: own Holder) -> int {
    return h.ref.n;
}

with entry {
    a: own Buffer = Buffer();
    h: own Holder = Holder();
    h.ref = a;
    print(take_holder(h));
}
