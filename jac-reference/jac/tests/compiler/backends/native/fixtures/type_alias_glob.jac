"""A module-level `TypeAlias` glob is a declaration, not a runtime value.

The native pathway must read it as the compile-time construct it is rather
than trying to give the alias name a layout.
"""

import from typing { TypeAlias }

glob Transfer: TypeAlias = Callable[[int], int];


def apply_twice(f: Transfer, n: int) -> int {
    return f(f(n));
}


def inc(n: int) -> int {
    return n + 1;
}


def run -> int {
    return apply_twice(inc, 1);
}
