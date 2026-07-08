"""Literal-index access on a fixed heterogeneous `tuple[T1, T2, ...]` types
per position (issue #7238), and variadic-tuple destructuring types every
target as the element type instead of leaking the `...` placeholder.
"""


# Per-position typing: t[0] is str, t[1] is bytes, negatives count from the end.
def per_position_ok(t: tuple[str, bytes]) -> None {
    a: str = t[0];  # <-- ok
    b: bytes = t[1];  # <-- ok
    c: bytes = t[-1];  # <-- ok
    d: str = t[-2];  # <-- ok
}


# A three-element heterogeneous tuple types each slot independently.
def three_slots_ok(t: tuple[int, str, bytes]) -> None {
    a: int = t[0];  # <-- ok
    s: str = t[1];  # <-- ok
    by: bytes = t[2];  # <-- ok
}


# The per-position type is enforced: t[1] is bytes, not str.
def per_position_mismatch(t: tuple[str, bytes]) -> None {
    bad: str = t[1];  # <-- error

}


# A variadic `tuple[int, ...]` still types indexing as its element type.
def variadic_index_ok(t: tuple[int, ...]) -> int {
    return t[0] + t[3];  # <-- ok

}


# Destructuring a variadic tuple types every target as the element type.
def variadic_destructure_ok(t: tuple[int, ...]) -> int {
    (a, b) = t;
    return a + b;  # <-- ok

}
