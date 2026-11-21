"""Pre-statement narrowing must reach inside expression sub-CFGs.

Ternary, walrus, and comprehension expressions introduce sub-CFG nodes
that aren't directly linked from the surrounding statement flow. The
walker must fall back to the enclosing statement's narrowing when it
hits an empty `bb_in` at a sub-CFG entry, otherwise narrowing
established by an earlier guard is lost inside the expression.
"""

class Shape {
    has name: str = "shape";
}

class Polygon(Shape) {
    has sides: list[int] = [];
}

# Pre-narrowing via early-return guard, then ternary in the body.
# After `if s is None: return ""`, s is Shape (not None).
# Both branches of the ternary access s.name, which is valid on Shape.
# Without the fallback, the walker widens s back to Shape | None and
# the .name access errors against the NoneType arm.
def f(s: Shape | None) -> str {
    if s is None {
        return "";
    }
    return s.name if isinstance(s, Polygon) else s.name;
}

# Same shape but the early return narrows further (to Polygon).
# Both branches of the ternary should see p as Polygon.
def g(p: Shape | None) -> int {
    if p is None or not isinstance(p, Polygon) {
        return 0;
    }
    return p.sides[0] if p.sides else 0;
}

# Pre-narrowing via if-then-narrowing pattern (no early return).
def h(s: Shape | None) -> str {
    result: str = "";
    if s is not None {
        result = s.name if isinstance(s, Polygon) else s.name;
    }
    return result;
}
