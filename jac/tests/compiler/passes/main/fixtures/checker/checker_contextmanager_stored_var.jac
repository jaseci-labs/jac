"""Fixture: @contextmanager result stored in a variable then used in with.

Expected: 0 errors — the variable must be typed as AbstractContextManager,
not NoneType, so the with statement passes the protocol check.
This is the edge case that a call-site-only workaround could never fix.
"""

import from contextlib { contextmanager }

obj SimpleLock {
    @contextmanager
    def acquire -> None;
}

impl SimpleLock.acquire -> None {
    yield ;
}

def use_stored {
    lock = SimpleLock();
    ctx = lock.acquire();
    with ctx {
        :> "inside";
    }
}
