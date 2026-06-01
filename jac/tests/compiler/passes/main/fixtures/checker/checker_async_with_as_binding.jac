"""Fixture: `async with cm() as x` checks the async protocol and binds x.

Expected: 0 errors. The checker verifies __aenter__/__aexit__ and binds the
alias to the awaited __aenter__ result (int).
"""

import from contextlib { asynccontextmanager }
import from typing { AsyncIterator }

obj Lock {
    @asynccontextmanager
    async def acquire -> AsyncIterator[int];
}

impl Lock.acquire -> AsyncIterator[int] {
    yield 1;
}

async def use_it {
    lock = Lock();
    async with lock.acquire() as x {
        y = x + 1;
    }
}
