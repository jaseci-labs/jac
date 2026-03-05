"""Test cross-module struct type usage.

Imports Point and make_point from na_struct_export.na.jac, then uses
the imported struct type as a function parameter and for field access.
Expected output: x = 3
"""

import from na_struct_export { Point, make_point, get_x }

def use_imported_point(x: int, y: int) -> int {
    pt: Point = make_point(x, y);
    return get_x(pt);
}

with entry {
    result: int = use_imported_point(3, 4);
    print("x =", result);
}
