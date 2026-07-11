"""Completion documentation test fixture."""

"""Cardinal directions."""
enum Direction {
    North,
    South,
}

"""A circle shape."""
obj Circle {
    """Radius of the circle."""
    has radius: float;
    has undocumented_field: int;

    """Adds two numbers."""
    def add_values(a: int, b: int) -> int {
        return a + b;
    }
}

with entry {
    z
    c = Circle(radius=1.0);
    c.
}
