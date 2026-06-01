"""Fixture: @contextmanager on an annotated generator method, used in `with`.

Expected: 0 errors. Generic decorator-application types the method as a
context manager (no decorator-name special-casing), so the with statement
finds the enter/exit protocol.
"""

import from contextlib { contextmanager }
import from typing { Iterator }

obj Lock {
    @contextmanager
    def acquire -> Iterator[int];
}

impl Lock.acquire -> Iterator[int] {
    yield 1;
}

def use_it {
    lock = Lock();
    with lock.acquire() {
        print("inside");
    }
}
