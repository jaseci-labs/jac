"""Fixture: `with cm() as x` binds x to __enter__'s result.

Expected: 0 errors. The alias is typed as the yielded value (str), not the
context manager, so string concatenation typechecks.
"""

import from contextlib { contextmanager }
import from typing { Iterator }

obj Lock {
    @contextmanager
    def acquire -> Iterator[str];
}

impl Lock.acquire -> Iterator[str] {
    yield "x";
}

def use_it {
    lock = Lock();
    with lock.acquire() as s {
        t = s + "y";
    }
}
