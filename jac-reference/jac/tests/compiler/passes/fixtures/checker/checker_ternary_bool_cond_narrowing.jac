"""Ternary conditions with BoolExpr narrow their branches per-operand."""

class Shape {}

class Polygon(Shape) {
    has sides: list[int] = [];

    def corner_count -> int {
        return len(self.sides);
    }
}

# True branch: AND with isinstance — s must be Polygon inside the true
# branch for `.corner_count()` to resolve.
def probe_and_true(s: Shape | None) -> int {
    return s.corner_count() if s is not None and isinstance(s, Polygon) else 0;
}

# Else branch: OR with inverted predicates — inside the else, both
# operands are false, so s is not None AND isinstance(s, Polygon).
# Narrowing must flow through each operand so the else branch sees
# s as Polygon, not just Shape.
def probe_or_inverse_else(s: Shape | None) -> int {
    return 0 if s is None or not isinstance(s, Polygon) else s.corner_count();
}

# Same shape, parenthesized. Must behave identically.
def probe_or_inverse_else_parens(s: Shape | None) -> int {
    return 0 if (s is None or not isinstance(s, Polygon)) else s.corner_count();
}

# Plain if/else control: already worked before, pin the behavior here.
def probe_ifstmt_control(s: Shape | None) -> int {
    if s is None or not isinstance(s, Polygon) {
        return 0;
    }
    return s.corner_count();
}
