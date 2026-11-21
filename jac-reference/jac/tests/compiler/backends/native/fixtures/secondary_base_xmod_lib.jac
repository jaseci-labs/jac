"""Multiply-inheriting hierarchy owned by another module (issue #8163).

`Item` inherits `Flagged` as its *second* base, so the flattened layout puts
`flagged` one slot later in `Item` than in `Flagged`'s own struct -- and in
`Item` the base's slot names the `tag` pointer instead. `make` builds the
instances here, in the defining module, so the consumer also sees objects
whose vtable pointer was written by this module's code.
"""

obj Root {
    has depth: int = 0;
}

obj Tagged(Root) {
    has tag: (Root | None) = None;

    def tag_kind -> int {
        return 10;
    }
}

obj Flagged(Root) {
    has flagged: bool = False;

    def flag_kind -> int {
        return 20;
    }
}

obj Flow(Root) {
    has flow_in: int = 0;
}

obj Stmt(Flow) {
    has stmt_id: int = 0;
}

obj Item(Tagged, Flagged, Stmt) {
    has payload: int = 0;
}

def make(k: int) -> Root {
    if k == 0 {
        return Item(tag=None, flagged=False);
    } elif k == 1 {
        return Item(tag=Root(depth=9), flagged=False);
    } elif k == 2 {
        return Item(tag=None, flagged=True);
    } elif k == 3 {
        return Item(tag=Root(depth=9), flagged=True);
    }
    return Flagged(flagged=True);
}
