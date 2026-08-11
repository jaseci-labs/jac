"""Bug #LOOPHDR-1: back-edge detection at loop headers for same-kind nested loops.

The narrowing at a loop header merges only loop-entry predecessors; back
edges are skipped. Back-edge detection used `pred.find_parent_of_type(<kind
of header>)`, which finds the NEAREST ancestor of that kind. When the back
edge originates inside a nested loop of the SAME kind (here: the tail of the
inner loop's else clause), the nearest same-kind ancestor is the inner loop,
so the back edge was treated as a loop-entry predecessor. The widening
assignment on that edge then destroyed the entry narrowing of `cur`
(Item, from `cur = Item()`), typing `cur` as `Item | None` in the outer
body and producing a spurious "cannot access attribute" error on `cur.val`.

`single_loop_control` is the unnested equivalent: the same widening
assignment sits directly in the loop body, its nearest same-kind ancestor IS
the header, so it was always skipped correctly. The nested forms must
behave identically to it.
"""

obj Item {
    has next: Item | None = None;
    has val: int = 0;
}

def while_in_while(start: Item | None) -> int {
    total = 0;
    cur = start;
    cur = Item();
    while total < 3 {
        total += cur.val;
        while total < 10 {
            total += 1;
        } else {
            cur = start;
        }
    }
    return total;
}

def for_in_for(start: Item | None) -> int {
    total = 0;
    cur = start;
    cur = Item();
    for i in range(3) {
        total += cur.val;
        for j in range(2) {
            total += j;
        } else {
            cur = start;
        }
    }
    return total;
}

def single_loop_control(start: Item | None) -> int {
    total = 0;
    cur = start;
    cur = Item();
    while total < 3 {
        total += cur.val;
        cur = start;
    }
    return total;
}

with entry {
    print(while_in_while(Item()) + for_in_for(Item()) + single_loop_control(Item()));
}
