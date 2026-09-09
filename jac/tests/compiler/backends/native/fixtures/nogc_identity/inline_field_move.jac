"""A named `own` local moved into a non-optional own field that headerless
codegen flattens inline: the payload moves, the source shell is released once,
and the source binding is consumed (#8984, found while narrowing A1)."""

obj Node {
    has v: int = 0;

    def drop { print("drop node " + str(self.v)); }
}

obj Holder { has slot: own Node = Node(); }

def run -> int {
    h: own Holder = Holder();
    b: own Node = Node(v=2);
    h.slot = b;
    print("h.slot.v=" + str(h.slot.v));
    return 0;
}

with entry { run(); print("done"); }
