"""Field reads through a reference narrowed to a *secondary* base (issue #8163).

Mirrors `Assignment(AstTypedVarNode, EnumBlockStmt, CodeBlockStmt)` from the
parser's own tree: `Item` inherits `Flagged` as its *second* base, so the
flattened layout puts `flagged` one slot later in `Item` than in `Flagged`'s
own struct. Reading `it.flagged` off a `Flagged`-narrowed reference must land
on `flagged` and not on whatever the base index happens to name in `Item` --
here slot 3, the `tag` pointer, whose low byte varies per instance exactly the
way the parser's dropped-comma gate did.
"""

obj Root {
    has depth: int = 0;
}

obj Tagged(Root) {
    has tag: (Root | None) = None;
}

obj Flagged(Root) {
    has flagged: bool = False;
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

def read_narrowed(k: int) -> int {
    it: Root = make(k);
    if isinstance(it, Flagged) and it.flagged {
        return 1;
    }
    return 0;
}

def read_direct(k: int) -> int {
    it: Root = make(k);
    if isinstance(it, Flagged) {
        return 1 if it.flagged else 0;
    }
    return 0;
}

def write_narrowed(k: int) -> int {
    it: Root = make(k);
    if isinstance(it, Flagged) {
        it.flagged = True;
    }
    if isinstance(it, Item) {
        return 1 if it.flagged else 0;
    }
    if isinstance(it, Flagged) {
        return 1 if it.flagged else 0;
    }
    return 0;
}

def tag_intact(k: int) -> int {
    it: Root = make(k);
    if isinstance(it, Flagged) {
        it.flagged = True;
    }
    if isinstance(it, Tagged) and it.tag is not None {
        return 1;
    }
    return 0;
}
