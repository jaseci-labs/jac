"""Bug #8580: mutable containers checked covariantly let numeric widening through.

Element compatibility between containers used plain subtyping, and int
widens to float, so list[int] flowed into list[float]. The native
backend then stored the appended float in an int-typed element slot and
reading it back printed raw float bits as an integer.

When both element types are numeric class instances the element relation
must also hold in reverse: the same-class branch rejects list[int] into
list[float] and dict[str, int] into dict[str, float], the derived-class
branch rejects IntBox (a Box[int]) into Box[float]. A union destination
stores any of its members, so list[int] into list[float | None] is
rejected too. Every call below must be rejected; non-numeric elements
keep covariant behavior (see the positive fixture).
"""

def take_floats(xs: list[float]) -> float {
    return xs[0];
}

def take_scores(d: dict[str, float]) -> float {
    return d["x"];
}

def take_maybe_floats(xs: list[float | None]) -> float | None {
    xs.append(1.5);
    return xs[0];
}

glob T = TypeVar('T');

obj Box(Generic[T]) {
    has v: T;
}

obj IntBox(Box[int]) {}

def take_float_box(b: Box[float]) -> float {
    return b.v;
}

with entry {
    ints: list[int] = [1, 2, 3];
    f1: float = take_floats(ints);
    ib: IntBox = IntBox(v=1);
    f2: float = take_float_box(ib);
    scores: dict[str, int] = {"x": 1};
    f3: float = take_scores(scores);
    f4: float | None = take_maybe_floats(ints);
}
