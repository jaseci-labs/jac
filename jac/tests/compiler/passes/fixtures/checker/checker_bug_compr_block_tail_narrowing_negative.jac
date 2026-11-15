"""Fixture: a comprehension at the end of a block narrows nothing.

The companion of `checker_bug_compr_block_tail_narrowing.jac`. Joining the
block's last statement to what follows must not make the name look guarded
where it is not: after the `if`, with no guard, it may still be `None`; and
on the branch where it is `None`, it is `None`.

Exactly two attribute accesses below must be reported.
"""

obj Pane {
    has area: int = 0,
        tags: list[int] = [];
}

# Both paths reach the return: one on which the name is None.
def unguarded(casing: Pane | None) -> int {
    if casing is not None {
        casing.tags = [each for each in [1, 2]];
    }
    return casing.area;
}

# The branch on which it is None, a comprehension before the use.
def wrong_branch(casing: Pane | None) -> int {
    if casing is None {
        seen = [each for each in [1, 2]];
        return casing.area + len(seen);
    }
    return 0;
}
