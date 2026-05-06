"""Assignment barrier: narrowing on the edge past an assignment."""

def maybe_int -> int | None {
    return 5;
}

# Strict narrowing: `int | None` narrowed to `int` by the assigned literal.
def widen_via_narrow(x: int | None) -> int {
    x = 5;
    return x;
}

# Widening reset: after `if x is not None` narrows `x` to int, reassigning
# from an `int | None` source must reset `x` back to the declared type.
def widen_via_reassign(x: int | None) -> int {
    if x is not None {
        x = maybe_int();
        return x;  # error: `x` is `int | None` again.

    }
    return 0;
}

# In-branch re-assignment keeps the isinstance-narrowed type.
def narrow_in_branch(x: int | str) -> int {
    if isinstance(x, int) {
        x = x + 1;
        return x;
    }
    return 0;
}
