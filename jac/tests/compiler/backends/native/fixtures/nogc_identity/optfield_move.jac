"""A named `own` local moved into an `own T | None` field: the field owns the
value afterwards and the source binding is consumed, so exactly one drop fires,
at the parent's drop, under every memory profile (#8984 A1)."""

obj Node {
    has v: int = 0,
        next: own Node | None = None;

    def drop { print("drop node " + str(self.v)); }
}

obj Holder { has slot: own Node | None = None; }

def set_via_param(h: &mut Holder) {
    b: own Node = Node(v=3);
    h.slot = b;
}

def run -> int {
    a: own Node = Node(v=1);
    b: own Node = Node(v=2);
    a.next = b;
    if a.next is not None { print("a.next.v=" + str(a.next.v)); }
    h: own Holder = Holder();
    set_via_param(&mut h);
    if h.slot is not None { print("h.slot.v=" + str(h.slot.v)); }
    return 0;
}

with entry { run(); print("done"); }
