"""A generic archetype is erased natively: one struct serves every
instantiation, and a slot typed by the type parameter holds a tagged `any`.
A union of unrelated by-value kinds is itself a tagged `any`, so
`ContextVar[int | str]` is held the same way and reads back what CPython
reads."""

import from contextvars { ContextVar }

glob U: ContextVar[int | str] = ContextVar[int | str]("u", `default=1);

def run_probe {
    print(U.get());
}

with entry {
    run_probe();
}
