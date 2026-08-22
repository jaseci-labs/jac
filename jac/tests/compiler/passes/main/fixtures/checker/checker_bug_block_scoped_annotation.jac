"""Block-scoped annotated declarations must keep their annotation (#8060).

An annotated local declared inside a nested block (a `while` body, a plain
`if` block) is reassigned in each arm of an inner if/else. Every assignment
is compatible with the declared annotation, so none of them is an error; the
declaration's scoping depth must not change that.
"""

obj A {
    has x: int = 1;
}

obj B {
    has y: int = 2;
}

def pa(c: bool) -> (A | None) {
    return A() if c else None;
}

def pb(c: bool) -> (B | None) {
    return B() if c else None;
}

"""Declared at function level: the shape that already worked."""
def at_function_level(c: bool) -> int {
    out = 0;
    item: (A | B | None) = None;
    if c {
        item = pa(c);
    } else {
        item = pb(c);
    }
    if item is not None {
        out += 1;
    }
    return out;
}

"""Declared inside a while body."""
def in_while_body(c: bool, n: int) -> int {
    out = 0;
    while n > 0 {
        item: (A | B | None) = None;
        if c {
            item = pa(c);
        } else {
            item = pb(c);
        }
        if item is not None {
            out += 1;
        }
        n -= 1;
    }
    return out;
}

"""Declared inside a plain if block."""
def in_if_block(c: bool, mode: int) -> int {
    out = 0;
    if mode == 4 {
        item: (A | B | None) = None;
        if c {
            item = pa(c);
        } else {
            item = pb(c);
        }
        if item is not None {
            out += 1;
        }
    }
    return out;
}

with entry {
    print(at_function_level(True) + in_while_body(True, 2) + in_if_block(True, 4));
}
