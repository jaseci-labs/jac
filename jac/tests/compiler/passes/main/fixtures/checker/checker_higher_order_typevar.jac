"""Fixture: a TypeVar is bound through a function-typed argument.

Expected: 0 errors. `apply` returns T inferred from the passed callable's
return type, so `n + 1` typechecks as int arithmetic.
"""

import from typing { Callable, TypeVar }

glob T = TypeVar("T");

def apply(f: Callable[[], T]) -> T {
    return f();
}

def make_int() -> int {
    return 5;
}

def use_it {
    n = apply(make_int);
    m = n + 1;
}
