"""The numeric invariance guard must not reject idiomatic covariant uses.

Non-numeric element types keep plain covariance, generic inference is
untouched (TypeVar arguments are skipped), and literal elements still
widen to the container's declared numeric element type.
"""

def take_anything(xs: list[object]) -> object {
    return xs[0];
}

def take_floats(xs: list[float]) -> float {
    return xs[0];
}

def first[T](xs: list[T]) -> T {
    return xs[0];
}

with entry {
    ints: list[int] = [1, 2, 3];
    words: list[str] = ["a"];
    o1: object = take_anything(ints);
    o2: object = take_anything(words);
    i1: int = first(ints);
    f1: float = take_floats([1, 2]);
}
