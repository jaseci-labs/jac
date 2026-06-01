"""Regression fixture: function-scope assignment to a glob name must be a LOCAL.

Python — and therefore the sv (.sv.jac) pathway — scopes a bare assignment
inside a function as a NEW function-local, even when a module global of the
same name exists. Rebinding the module global requires an explicit `global x;`.

The native pathway must follow the identical rule so that any `.na.jac` program
runs with the same observable semantics in the sv pathway (the na ⊆ sv
guarantee).

Before the fix, `counter = 5` inside `bump_local()` rebound the module global,
so `read_global()` observed 5 instead of 0 — diverging from CPython/sv, where
`bump_local()` only mutates a throwaway local.

This file is pathway-neutral Jac: the cross-pathway test reads it, swaps the
empty entry block for a printing one, and runs the exact same source through
the sv pathway, asserting both pathways agree.
"""

glob counter: int = 0;

"""Bare assignment — Python semantics: a function-local; the global is untouched."""
def:pub bump_local() -> int {
    counter = 5;
    return counter;
}

"""Reads the module global; must be unaffected by bump_local()."""
def:pub read_global() -> int {
    return counter;
}

"""Explicit `global` — this DOES rebind the module global."""
def:pub bump_global() -> int {
    global counter;
    counter = 99;
    return counter;
}

with entry {}
