"""Transitive module: the function the entry actually uses does not touch the
clib-bearing dependency; the only reference to it is a body-scoped import in a
separate element, so whether that library reaches the native link line depends
entirely on where that element is placed."""

def:pub plain_add(n: int) -> int {
    return n + 1;
}

def:pub gated_path(n: int) -> int {
    import from clib_ctx_gated_dep { gated_call }
    return gated_call(n);
}
