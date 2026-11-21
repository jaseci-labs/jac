"""Destructuring assignment narrows each target to its RHS element type
when the RHS has a concrete tuple type."""
import from typing { NamedTuple }


class Point(NamedTuple) {
    has x: int,
        y: int;
}


def make_pair -> tuple[int, str] {
    return (5, "ok");
}


# Position 0 of a tuple literal narrows `int | None` -> `int`.
def narrow_tuple_literal_pos0(x: int | None) -> int {
    (x, _) = (5, "ok");
    return x;  # <-- ok

}


# Position 1 of a tuple literal narrows too.
def narrow_tuple_literal_pos1(x: int | None) -> int {
    (_, x) = ("ok", 5);
    return x;  # <-- ok

}


# Typed `tuple[int, str]` return value narrows just like a literal.
def narrow_typed_return(x: int | None) -> int {
    (x, _) = make_pair();
    return x;  # <-- ok

}


# Nested destructuring: `b` at path [0, 1] narrows to `int`.
def narrow_nested(b: int | None) -> int {
    ((_, b), _) = ((1, 2), 3);
    return b;  # <-- ok

}


# NamedTuple destructure narrows via the shared element-extraction helper.
def narrow_named_tuple(x: int | None, p: Point) -> int {
    (x, _) = p;
    return x;  # <-- ok

}


# Regression guard: when the RHS element type does NOT strictly narrow
# the declared type, the edge still resets. Here `x: int | str` and the
# RHS element is `int | str` (same as declared), so no narrowing fires
# and `return x` correctly errors against `int`.
def no_narrow_non_strict(x: int | str, y: int | str) -> int {
    (x, _) = (y, "ok");
    return x;  # <-- error

}
