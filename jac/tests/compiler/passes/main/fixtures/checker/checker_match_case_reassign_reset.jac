"""Match-case narrowing must be killed by a later assignment."""

class Node {
    has parent: Node | None = None;
}

class Shape(Node) {}

class Polygon(Shape) {
    has sides: list[int] = [];
}

class Frame(Node) {}
class Group(Node) {}

obj Checker {
    def check(shape: Shape) {
        match shape {
            case Polygon():
                # shape is narrowed to Polygon here.
                if isinstance(shape.parent, (Frame, Group)) {
                    shape.sides;
                }
                shape = 90;  # error: cannot assign int to Shape
                # The barrier resets shape to the declared type for the
                # rest of this case body, so each access below errors.
                shape.sides;  # error
                if (
                    isinstance(shape.parent, (Frame, Group)) and shape.sides  # error
                ) {
                    shape.sides;  # error
                }

        }
    }
}
