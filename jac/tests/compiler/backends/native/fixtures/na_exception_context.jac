"""A function that owns a reference: it registers an unwind record, so the
module defines `__jac_exception_context`, the lookup the test reads."""

obj Box {
    has v: int = 0;
}

def hold(k: int) -> int {
    box: Box = Box(v=k);
    return box.v + 1;
}

with entry {
    print(hold(2));
}
