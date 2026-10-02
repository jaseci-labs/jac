"""Owned `own` locals stored into an own field that is held by pointer.

`Node` has a subclass, so it carries a vtable and headerless codegen cannot
flatten it inline. Each store replaces the object the field held; the
replaced object is dropped then, exactly as the flattened field and the
managed profiles do, instead of leaking with its `drop` never run."""

obj Node {
    has v: int = 0;

    def drop {
        print("drop node " + str(self.v));
    }
}

obj Leaf(Node) {}

obj Holder {
    has slot: own Node = Node();
}

def run -> int {
    h: own Holder = Holder();
    print("before=" + str(h.slot.v));
    b: own Node = Node(v=2);
    h.slot = b;
    print("h.slot.v=" + str(h.slot.v));
    c: own Node = Node(v=3);
    h.slot = c;
    print("h.slot.v=" + str(h.slot.v));
    return 0;
}

with entry {
    run();
    print("done");
}
