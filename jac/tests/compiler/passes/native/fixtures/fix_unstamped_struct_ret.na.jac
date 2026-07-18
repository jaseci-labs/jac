"""Regression fixture for issue #6822 (import-order struct-return priming).

Imports a struct type and its factory from na_struct_export and binds the
factory's result to an UNANNOTATED local (`p = make_point(...)`).  The local's
type is then known only from the imported function's `-> Point` return
annotation.  When this module is the nacompile entry, that cross-module return
annotation can be unstamped (`.type is None`), so `_resolve_jac_type` used to
fall back to i64 -- making `p` a scalar and every field access E5090
("attribute access not supported"), even though `Point` is already registered
in the native struct table.

Contrast na_struct_import.na.jac, which writes `pt: Point = make_point(...)`:
the explicit annotation stamps the local's type and sidesteps the gap.
"""

import from na_struct_export { Point, make_point }

def:pub compute(a: int) -> int {
    p = make_point(a, a + 1);
    return p.x + p.y;
}

with entry {
    print(compute(5));
}
