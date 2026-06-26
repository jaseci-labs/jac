obj Node {
    has val: int = 0,
        nxt: Node | None = None;
}

# A genuine error inside a loop body must still be reported (the narrowing
# walk re-evaluates this RHS against a seed, but that must not swallow it).
def real_error(start: Node | None) -> int | None {
    cur = start;
    acc: int | None = None;
    while cur {
        acc = cur.val;
        bad = cur.nxt.val;
        cur = cur.nxt;
    }
    return acc;
}
