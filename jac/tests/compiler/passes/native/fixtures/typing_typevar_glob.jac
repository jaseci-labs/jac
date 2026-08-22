"""A module-scope `TypeVar` glob is a typing declaration, not a runtime value.

The generic parameter it binds is erased at every use site already; only the
glob initializer used to demand a run-time `TypeVar` object. The explicit
import later escalated to E1125 (the name is ambient); the run-time object
now arrives through the ambient auto-import.
"""

glob T = TypeVar('T', bound=int);


def pick(a: int, b: int) -> int {
    return a if a > b else b;
}


def run -> int {
    return pick(4, 9);
}
