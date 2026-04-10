"""Starred-unpack assignment is a narrowing barrier."""

# After `if rest is not None` narrows `rest` to list[int], unpacking
# into the starred slot `*rest` must reset it back to the declared
# type. The typed-local assignment then fails because list[int] | None
# is not assignable to list[int].
def widen_via_star(rest: list[int] | None) -> int {
    if rest is not None {
        (head, *rest) = (1, 2, 3);
        wrong: list[int] = rest;
        return 0;
    }
    return 0;
}
