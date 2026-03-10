"""Fixture: obj with enum field."""

enum Color {
    RED,
    GREEN,
    BLUE
}

obj Colored {
    has color: Color,
        intensity: int;
}
