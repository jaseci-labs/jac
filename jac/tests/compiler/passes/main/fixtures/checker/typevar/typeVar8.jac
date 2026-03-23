"""Tests TypeVar union widening on conflict.

When the same TypeVar is inferred as two incompatible types from
different arguments, the solver widens to a union instead of failing.
Previously, merge(1, "hello") would fail because the solver couldn't
reconcile T=int with T=str. Now it widens to T=int|str.
"""

def merge[T](a: T, b: T) -> list[T] {
    return [a, b];
}

def pair[T](x: T, y: T) -> T {
    return x;
}

with entry {
    # Same type: no conflict, T = int
    same = merge(1, 2);
    good_same: list[int] = same;  # Ok

    # Different types: T should widen to int | str (not Unknown/error)
    mixed = merge(1, "hello");
    good_mixed: list[int | str] = mixed;  # Ok

    # Subtype: T should be int (bool is subtype of int)
    sub = merge(1, True);
    good_sub: list[int] = sub;  # Ok

    # Widening with pair
    p = pair(3.14, "hi");
    good_pair: float | str = p;  # Ok
}
