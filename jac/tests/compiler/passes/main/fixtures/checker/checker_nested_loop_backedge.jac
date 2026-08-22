"""Bug #LOOPHDR-1: back-edge detection at loop headers for same-kind nested loops.

The narrowing at a loop header merges only loop-entry predecessors; back
edges are skipped. Back-edge detection used `pred.find_parent_of_type(<kind
of header>)`, which finds the NEAREST ancestor of that kind. When the back
edge originates inside a nested loop of the SAME kind (here: the tail of the
inner loop's else clause, which links straight to the outer header), the
nearest same-kind ancestor is the inner loop, so the back edge was mistaken
for a loop-entry predecessor. Merging it destroys the entry narrowing of
`cur` (Item, from `cur = Item()`), leaving `cur` at its declared
`Item | None` in the outer body and producing a spurious "cannot access
attribute" error on `cur.val`.

No loop here reassigns `cur`: it is bound to `Item()` once, before the outer
loop, and never written again. The entry narrowing is therefore valid on
every iteration, so a correct checker reports nothing anywhere in this file.
That is what makes the fixture discriminating -- the errors that appear when
back-edge detection breaks are not merely the wrong count, they are errors a
sound checker has no reason to raise at all.

`single_loop_control` is the unnested equivalent: its back edge originates
directly in the loop body, whose nearest same-kind ancestor IS the header, so
it was always skipped correctly even by the buggy detection. It stays clean
under both, which is exactly why it is the control -- the nested forms must
match it.
"""

obj Item {
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
            total += 1;
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
            total += 1;
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
        total += 1;
    }
    return total;
}

with entry {
    print(while_in_while(Item()) + for_in_for(Item()) + single_loop_control(Item()));
}
