"""Fixture: @contextmanager method used directly in a with statement.

Expected: 0 errors — the type checker must recognise that a
@contextmanager-decorated ability returns a context manager, not NoneType.
Previously produced false-positive E1091/E1092.
"""

import from contextlib { contextmanager }

obj SimpleLock {
    @contextmanager
    def acquire -> None;
}

impl SimpleLock.acquire -> None {
    yield ;
}

def use_direct {
    lock = SimpleLock();
    with lock.acquire() {
        :> "inside";
    }
}
