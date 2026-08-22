"""A generic archetype is erased natively, so a scalar type argument has no
sound layout. `ContextVar[int]` must be refused naming the instantiation
rather than lowered into a pointer slot that cannot hold an unboxed int."""

import from contextvars { ContextVar }

glob N: ContextVar[int] = ContextVar[int]("n", `default=7);

def run_probe {
    print(N.get());
}

with entry {
    run_probe();
}
