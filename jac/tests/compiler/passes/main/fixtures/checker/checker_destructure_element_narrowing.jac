"""Destructuring assignment narrows each target to its RHS element type
when the RHS has a concrete tuple type."""

def make_pair -> tuple[int, str] {
    return (5, "ok");
}


# Position 0 of a tuple literal narrows `int | None` -> `int`.
def narrow_tuple_literal_pos0(x: int | None) -> int {
    (x, _) = (5, "ok");
    return x;
}


# Position 1 of a tuple literal narrows too.
def narrow_tuple_literal_pos1(x: int | None) -> int {
    (_, x) = ("ok", 5);
    return x;
}


# Typed `tuple[int, str]` return value narrows just like a literal.
def narrow_typed_return(x: int | None) -> int {
    (x, _) = make_pair();
    return x;
}


# Nested destructuring: `b` at path [0, 1] narrows to `int`.
def narrow_nested(b: int | None) -> int {
    ((_, b), _) = ((1, 2), 3);
    return b;
}


# Regression guard: when the RHS element type does NOT strictly narrow
# the declared type, the edge still resets. Here `x: int | str` and the
# RHS element is `int | str` (same as declared), so no narrowing fires
# and `return x` correctly errors against `int`.
def no_narrow_non_strict(x: int | str, y: int | str) -> int {
    (x, _) = (y, "ok");
    return x;
}
