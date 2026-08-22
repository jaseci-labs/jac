"""Negative counterpart of #8060: the declared annotation still constrains.

Each function reassigns a block-scoped annotated local with a value the
annotation does not admit. Widening the declaration to Unknown would silence
these, so they pin the fix to "use the declared type", not "use no type".
"""

obj A {
    has x: int = 1;
}

obj B {
    has y: int = 2;
}

obj C {
    has z: int = 3;
}

def pc(c: bool) -> (C | None) {
    return C() if c else None;
}

"""Declared inside a while body: C is outside the annotation."""
def in_while_body(c: bool, n: int) -> int {
    out = 0;
    while n > 0 {
        item: (A | B | None) = None;
        if c {
            item = A();
        } else {
            item = pc(c);
        }
        if item is not None {
            out += 1;
        }
        n -= 1;
    }
    return out;
}

"""Declared inside a plain if block: C is outside the annotation."""
def in_if_block(c: bool, mode: int) -> int {
    out = 0;
    if mode == 4 {
        item: (A | B | None) = None;
        if c {
            item = A();
        } else {
            item = pc(c);
        }
        if item is not None {
            out += 1;
        }
    }
    return out;
}

with entry {
    print(in_while_body(True, 2) + in_if_block(True, 4));
}
