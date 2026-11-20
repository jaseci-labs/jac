"""Tuple-unpacking assignment is a narrowing barrier."""

def reset_pair -> tuple[int | None, str] {
    return (None, "reset");
}

# After `if x is not None` narrows `x` to int, unpacking from a source
# that produces `int | None` for `x` must reset `x` back to the declared
# type, so `return x` fails against the `int` return type.
def widen_via_unpack(x: int | None) -> int {
    if x is not None {
        (x, _) = reset_pair();
        return x;
    }
    return 0;
}
