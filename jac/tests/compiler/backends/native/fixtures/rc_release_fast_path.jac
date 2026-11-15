"""Owned references reassigned in a loop: every reassignment releases the
previous `Cell` (an acyclic archetype) and every `held` copy retains one.
The test reads the refcount helpers this module defines and the calls the
loop makes."""

obj Cell {
    has v: int = 0;
}

def churn(n: int) -> int {
    cur: Cell = Cell(v=0);
    acc: int = 0;
    i: int = 0;
    while i < n {
        held: Cell = cur;
        cur = Cell(v=i);
        acc = acc + held.v + cur.v;
        i = i + 1;
    }
    return acc;
}

with entry {
    print(churn(10));
}
