"""Fixture: in-loop narrowing must be resolved as a fixed point.

A loop body is not evaluated once but until the narrowed type of every variable
stops changing. Three cases stress the engine:

  1. Monotone recurrence (`cur = cur.next`) under a compound condition: the read
     of `cur` inside the body must stay narrowed to the non-None type even though
     the body reassigns `cur` from a nullable attribute.
  2. A guard-narrowed variable that is only *read* (never assigned) inside a loop:
     the `is None` guard established before the loop must survive into the body -
     the loop is invariant in that variable, so iterating must not widen it back.
  3. Independent recurrences in sibling and nested loops: resolving one loop's
     fixed point must not destabilize another's.

After the fix, every attribute access below must type-check with no errors.
"""

obj Node {
    has val: int = 0,
        next: Node | None = None,
        prev: Node | None = None;
}

# 1. Monotone recurrence with a compound loop condition.
def walk_to_end(head: Node | None) -> Node | None {
    cur = head;
    while cur is not None and cur.next is not None {
        cur = cur.next;
    }
    return cur;
}

# 2. Guard narrows `anchor`; the loop only reads it (never assigns), so the
#    narrowing must hold inside the body.
def sum_from(anchor: Node | None, steps: list[int]) -> int {
    if anchor is None {
        return 0;
    }
    total = 0;
    for _s in steps {
        total += anchor.val;
    }
    return total;
}

# 3. Nested loops, each with its own recurrence over a different variable.
def total_grid(rows: Node | None, start_col: Node | None) -> int {
    t = 0;
    r = rows;
    while r is not None {
        t += r.val;
        c = start_col;
        while c is not None {
            t += c.val;
            c = c.prev;
        }
        r = r.next;
    }
    return t;
}
