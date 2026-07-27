"""Regression fixture: typed shadow vs implicit rebind of a glob name.

Under Jac scoping a TYPED declaration (`counter: int = 5;`) inside a function
creates a fresh function-local that shadows the module glob, while a BARE
assignment implicitly rebinds the nearest enclosing binding — here the
module-level `glob counter`.

The native pathway must follow the identical rule so that any `.na.jac` program
runs with the same observable semantics in the sv pathway (the na ⊆ sv
guarantee).

This file is pathway-neutral Jac: the cross-pathway test reads it, swaps the
empty entry block for a printing one, and runs the exact same source through
the sv pathway, asserting both pathways agree.
"""

glob counter: int = 0;

"""Typed declaration — a function-local shadow; the global is untouched."""
def:pub bump_local() -> int {
    counter: int = 5;
    return counter;
}

"""Reads the module global; must be unaffected by bump_local()."""
def:pub read_global() -> int {
    return counter;
}

"""Bare assignment — this DOES rebind the module global."""
def:pub bump_global() -> int {
    counter = 99;
    return counter;
}

with entry {}
