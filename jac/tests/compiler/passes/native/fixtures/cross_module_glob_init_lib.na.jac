"""Library module with a glob list initializer.

Verifies that when imported by another .na.jac file, the _TABLE glob is
properly initialized (not left as a null pointer) thanks to the
__jac_glob_init cross-module linking introduced in the compiler fix.
"""

glob _TABLE: list[int] = [];

def:pub table_len() -> int {
    return len(_TABLE);
}

def:pub table_push(v: int) -> None {
    _TABLE.append(v);
}

def:pub table_get(i: int) -> int {
    return _TABLE[i];
}
