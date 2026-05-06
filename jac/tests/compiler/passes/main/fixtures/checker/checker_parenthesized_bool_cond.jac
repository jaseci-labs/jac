"""Parenthesized BoolExpr conditions must wire the short-circuit CFG."""

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
    def check_bare(shape: Shape) {
        match shape {
            case Polygon():
                if isinstance(shape.parent, (Frame, Group)) and shape.sides {
                    shape.sides;
                }

        }
    }

    def check_parens(shape: Shape) {
        match shape {
            case Polygon():
                if (isinstance(shape.parent, (Frame, Group)) and shape.sides) {
                    shape.sides;
                }

        }
    }

    def check_while_parens(shape: Shape) {
        match shape {
            case Polygon():
                while (isinstance(shape.parent, (Frame, Group)) and shape.sides) {
                    shape.sides;
                    break;
                }

        }
    }
}
