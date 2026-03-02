"""Native module that exports a struct and constructor function.

Used by na_struct_import.na.jac to test cross-module struct types.
"""

obj Point {
    has x: int;
    has y: int;
}

def:pub make_point(x: int, y: int) -> Point {
    return Point(x=x, y=y);
}

def:pub get_x(p: Point) -> int {
    return p.x;
}
