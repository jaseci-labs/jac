"""Regression: the assignment barrier resets narrowing in all three cases.

An assignment whose target matches the reference being narrowed is a
control-flow barrier. On that edge, exactly one of two things happens:

1. Strict narrowing: the assigned type is a proper subtype of the
   declared type (e.g. `int | None` -> `int`). Use the assigned type.
2. Reset: the assigned type is the declared type, a wider type, or an
   invalid type. Fall back to the declared type.

In neither case does the pre-assignment narrowing propagate past the
assignment. This file pins down the three shapes.
"""

def maybe_int -> int | None {
    return 5;
}

# (1) Strict narrowing: `x = 5` where `x: int | None` -> int.
def widen_via_narrow(x: int | None) -> int {
    x = 5;
    return x;  # OK: narrowed to int.

}

# (2) Valid widening: even if a prior check narrowed `x` to int,
# reassigning from a source that returns `int | None` must reset to the
# declared type, not keep the narrowed one.
def widen_via_reassign(x: int | None) -> int {
    if x is not None {
        # Here `x` is narrowed to int.
        x = maybe_int();
        # Barrier resets: `x` is back to `int | None`.
        return x;  # <-- Error: cannot return int | None as int.

    }
    return 0;
}

# (3) Narrowed assignment inside a branch stays narrowed on that branch.
def narrow_in_branch(x: int | str) -> int {
    if isinstance(x, int) {
        x = x + 1;  # Still int.
        return x;  # OK.

    }
    return 0;
}
