"""Fixture for the C-ABI shared-library build (`jac nacompile --shared`).

Exercises the export surface the shared-object linkers must expose: `:pub`
free functions (scalar in/out), a `:pub` global, and opaque object handles
(`make_point` returns a Point*, `point_sum` consumes it) — the latter proving
that Jac object pointers cross the C ABI as opaque handles.
"""

glob:pub counter: int = 7;

def:pub jadd(a: int, b: int) -> int {
    return a + b;
}

def:pub jmul(a: int, b: int) -> int {
    return a * b;
}

def:pub get_counter() -> int {
    return counter;
}

obj:pub Point {
    has x: int = 0,
        y: int = 0;
}

def:pub make_point(x: int, y: int) -> Point {
    return Point(x=x, y=y);
}

def:pub point_sum(p: Point) -> int {
    return p.x + p.y;
}
