"""A generic archetype is erased natively: one struct serves every
instantiation, and a slot typed by the type parameter is a pointer. Scalars,
`str`, tuples and options box into that pointer; a union of unrelated
by-value kinds is a tagged `any` value with no box, so
`ContextVar[int | str]` must be refused naming the instantiation rather than
lowered into a slot that cannot hold it."""

import from contextvars { ContextVar }

glob U: ContextVar[int | str] = ContextVar[int | str]("u", `default=1);

def run_probe {
    print(U.get());
}

with entry {
    run_probe();
}
