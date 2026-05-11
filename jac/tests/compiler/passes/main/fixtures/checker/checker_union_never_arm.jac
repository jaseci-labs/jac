"""`Never` / `NoReturn` resolved to NeverType and accepted as `|` arms."""

import from typing { Any, Never, NoReturn }


# Chain-collapse case: without the fix, `int | type[Any] | Never` collapses
# to `UnionType | type[Any]` (the inner `type[Any].__or__` return type wins
# magic dispatch), so passing 42 is rejected with E1053.
def take_chain(x: int | type[Any] | Never) -> int {
    return 0;
}


def call_chain -> int {
    return take_chain(42);
}


# `Never` as a bottom type: a Never-returning call must be assignable to
# any expected param type.
def boom -> Never {
    raise ValueError("never");
}


def consume(x: int) -> int {
    return x;
}


def call_boom -> int {
    return consume(boom());
}


# `NoReturn` is a synonym for `Never` (PEP 484). Same shape works.
def take_noreturn(x: int | NoReturn) -> int {
    return 0;
}


def call_noreturn -> int {
    return take_noreturn(42);
}
