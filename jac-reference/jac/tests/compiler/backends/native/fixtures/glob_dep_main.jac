"""From-import of a plain .jac dep whose glob type tag has no checker type.

Pins the adjacent bug: the dep's `glob G: int` tag arrives with .type=None
and must fall back to the primitive type_map instead of demoting with E5092.
"""

import from glob_dep { getg }

def:pub use_dep_glob -> int {
    return getg();
}

with entry {}
