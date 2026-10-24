"""Reaches `ct_facade` through a comptime import before a runtime one.

The comptime path is walked first; `ct_leaf`, which the facade re-exports
`twice` from, is still reached at run time and must stay a link unit.
"""

comptime import from ct_facade { Num }
import from ct_facade { twice }


def run(x: Num) -> int {
    return twice(x);
}
