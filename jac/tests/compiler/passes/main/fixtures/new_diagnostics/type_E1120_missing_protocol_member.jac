"""Fixture for E1120: Type does not implement protocol."""

import from typing { Protocol }

class Drawable(Protocol) {
    def draw(self) -> None { ... }
    def resize(self, factor: float) -> None { ... }
}

obj Circle {
    def draw(self: Circle) -> None { }
    # Missing resize! -- should trigger E1120
}

def render(item: Drawable) -> None {
    item.draw();
}

with entry {
    c = Circle();
    render(c);  # <-- Error E1120: Circle missing 'resize' for Drawable
}
