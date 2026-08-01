"""Module B for third-module-struct fix test (FIX 3b).

Imports DataA from fix_third_a and exports functions that accept DataA
as a parameter.  The entry module imports from both A and B, so DataA is
a "third module" type from B's perspective when seen from the entry.
"""

import from fix_third_a { DataA }

"""Return the value field of a DataA struct."""
def:pub read_value(d: DataA) -> int {
    return d.value;
}

"""Return value + tag, checking both fields are accessible."""
def:pub read_sum(d: DataA) -> int {
    return d.value + d.tag;
}
