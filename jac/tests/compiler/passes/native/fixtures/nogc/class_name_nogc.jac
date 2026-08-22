"""`__class__.__name__` under headerless `--gc none --enforce-nogc`.

A headerless allocation is a bare `malloc` with no rc header in front of it,
and nothing stamps a class name anywhere, so the header probe that resolves a
runtime class in every other gc mode has nothing to read here. Reading it
anyway is not merely a fault risk: if the bytes before the allocation happen
to satisfy the sentinel or the magic check, the probe returns whatever sits at
the tag offset *as a class name*, which is a wrong answer with no diagnostic.

Everything here resolves without the header, and has to keep doing so.
`Tagged` has a subclass, so its name comes from the class-name constant in
vtable slot 0 -- a slot inside the struct, which a headerless allocation still
has. `Lone` has no hierarchy, so its name is frozen at compile time. The open
receiver that genuinely needs the header lives in `sem_token_shape.jac`, and
under this mode it has to be refused rather than answered.
"""

obj Tagged {
    has n: int = 0;
}

obj Marked(Tagged) {
    has m: int = 1;
}

obj Lone {
    has k: int = 2;
}


"""A vtabled receiver: the name is in slot 0 of the struct, not in a header.

The name is never bound to a local: a class name is a borrowed pointer into a
static constant, so it has no ownership state to declare under this mode.
"""
def vtable_rank(pick: int) -> int {
    base: own Tagged = Tagged();
    sub: own Marked = Marked();
    if pick == 1 {
        if sub.__class__.__name__ == "Marked" {
            return 1;
        }
        return 0;
    }
    if base.__class__.__name__ == "Tagged" {
        return 2;
    }
    return 0;
}


"""A class with no hierarchy: the name is a compile-time constant."""
def lone_rank(pick: int) -> int {
    solo: own Lone = Lone();
    if solo.__class__.__name__ == "Lone" {
        return 3;
    }
    return 0;
}
