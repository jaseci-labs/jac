"""Fixture: a statement that ends a block with a comprehension must flow on.

`CFGBuildPass` links a statement to the first clause of a comprehension it
holds, so that narrowing reaches the comprehension. When such a statement was
the last of an `if` body, that link was taken for the statement's way out,
and the body was never joined to what follows the `if`: the only path into
the next statement was the one on which the condition was false. A guard
that tested the same name again was then checked as if the name were still
`None`, and every use under it was reported.

After the fix, every attribute access below must type-check.
"""

obj Pane {
    has area: int = 0,
        tags: list[int] = [];
}

obj Holder {
    has window: Pane | None = None;
}

# The comprehension ends the guarded block; the guard is asked again after it.
def after_if(casing: Pane | None) -> int {
    if casing is not None {
        casing.tags = [each for each in [1, 2]];
    }
    if casing is not None {
        return casing.area;
    }
    return 0;
}

# A comprehension with a filter of its own, and the second guard an `and` chain.
def after_if_filtered(casing: Pane | None, items: list[Holder]) -> int {
    total = 0;
    if casing is not None {
        casing.tags = [
            above.window.area
            for above in items
            if above.window is not None
        ];
    }
    if casing is not None and total >= 0 and casing.area > 3 {
        total += casing.area;
    }
    return total;
}

# Dict and set comprehensions ending both branches.
def after_else(casing: Pane | None, flag: bool) -> int {
    if flag {
        seen = {
            each
            for each in [1, 2]
            if each > 1
        };
    } else {
        seen = set({each: each for each in [1, 2]}.keys());
    }
    if casing is not None {
        return casing.area + len(seen);
    }
    return 0;
}

# The comprehension ends an inner block that ends the outer one.
def after_nested(casing: Pane | None, flag: bool) -> int {
    if casing is not None {
        if flag {
            casing.tags = [each for each in [1, 2]];
        }
    }
    if casing is not None {
        return casing.area;
    }
    return 0;
}

# Inside a loop body, where the block's tail joins the next statement of the body.
def in_loop(items: list[Holder]) -> int {
    total = 0;
    for port in items {
        casing = port.window;
        if casing is not None {
            casing.tags = [
                above.window.area
                for above in items
                if above.window is not None
            ];
        }
        if casing is not None and total >= 0 and casing.area != 3 {
            casing.area = 4;
            total += 1;
        }
    }
    return total;
}

# After a loop whose body ends with one, and a `while` whose body is one.
def after_loops(casing: Pane | None) -> int {
    total = 0;
    for step in range(3) {
        if casing is not None {
            casing.tags = [each + step for each in [1, 2]];
        }
        if casing is not None {
            total += casing.area;
        }
    }
    while total < 3 {
        total += sum([each for each in [1, 2]]);
    }
    if casing is not None {
        total += casing.area;
    }
    return total;
}
