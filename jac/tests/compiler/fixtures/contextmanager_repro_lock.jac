"""Minimal reproduction of E1091/E1092 false positive.

A @contextmanager-decorated method declared with '-> None' is treated by
the type checker as returning NoneType, which has no __enter__/__exit__.
This triggers E1091/E1092 on the 'with' statement even though at runtime
@contextmanager wraps the generator into a valid context manager object.

This is the same pattern used in ReadWriteLock.write_lock/read_lock
in jac/jaclang/langserve/rwlock.jac.
"""

import from contextlib { contextmanager }

obj SimpleLock {
    @contextmanager
    def acquire -> None;
}

impl SimpleLock.acquire -> None {
    yield ;
}
