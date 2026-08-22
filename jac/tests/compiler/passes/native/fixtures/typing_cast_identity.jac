"""`typing.cast` is a type-checker directive, so it lowers to its own argument.

`cast(T, x)` has no run-time effect in Python either -- `typing.cast` returns
its second argument unchanged -- so a native unit that lowers it to `x` and a
Python unit that calls the real function agree by construction.
"""

import from typing { cast }


def widen(n: int) -> int {
    v = cast(int, n);
    return v + 1;
}


def run -> int {
    return cast(int, widen(cast(int, 20)));
}
