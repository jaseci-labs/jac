"""Head module with declarations."""

obj Circle {
    has radius: float;
    def area -> float;
}

with entry {
    c = Circle(radius=5.0);
    print(c.area());
}
