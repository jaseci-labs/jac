"""Bug #LOOPWIDEN-1: the first statement of a loop body is not iteration one.

When a loop body reassigns a symbol, the narrowing in force at the top of the
body is the merge over the back edge as well as over loop entry. Loop-header
narrowing deliberately skips back edges, so a body node that reads such a
symbol must instead fall back to the conservative (declared) type. `body[0]`
used to be exempted from that fallback, which handed it the iteration-one
view: the pre-loop assignment's narrow type, leaked into every later
iteration.

`while_body_reassigns` and `for_body_reassigns` are the unsound cases. `cur`
enters as `Item` (`cur = Item()`), but the tail of each body rebinds it to
`start`, which is `Item | None`. On iteration two and later `cur.val` at the
top of the body really can run on `None`, so both must be diagnosed.

The two clean functions keep the fallback honest in the other direction. In
`condition_renarrows` the loop condition tests the same symbol, so entry into
the body is narrowed by the condition applied over the conservative merge --
the body reassigns `cur`, but `while cur is not None` re-establishes the
narrowing on every iteration. In `body_preserves_narrowing` nothing in the
body writes `cur` at all, so there is no back-edge widening to merge and the
pre-loop narrowing holds throughout. Neither may be swept up by a blanket
"any loop body is conservative" rule.
"""

obj Item {
    has val: int = 0;
}

def while_body_reassigns(start: Item | None) -> int {
    total = 0;
    cur = start;
    cur = Item();
    while total < 3 {
        total += cur.val;
        cur = start;
    }
    return total;
}

def for_body_reassigns(start: Item | None) -> int {
    total = 0;
    cur = start;
    cur = Item();
    for i in range(3) {
        total += cur.val;
        cur = start;
    }
    return total;
}

def condition_renarrows(start: Item | None) -> int {
    total = 0;
    cur = start;
    while cur is not None {
        total += cur.val;
        cur = start;
    }
    return total;
}

def body_preserves_narrowing(start: Item | None) -> int {
    total = 0;
    cur = start;
    cur = Item();
    while total < 3 {
        total += cur.val;
        total += 1;
    }
    return total;
}

with entry {
    print(
        while_body_reassigns(Item())
            + for_body_reassigns(Item())
            + condition_renarrows(Item())
            + body_preserves_narrowing(Item())
    );
}
