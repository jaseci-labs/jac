"""Regression fixture for jaseci-labs/jac#9487.

The old native time intercept emitted its timespec alloca at the call site,
so inside a loop each iteration burned 16 bytes of stack and ~524288 calls
overflowed the default 8MiB limit. `__alloca` positions the allocation in the
function entry block; this fixture iterates 1M times through both a direct
`__alloca` caller and the bundled `time.monotonic_ns`, which would need 16MiB
of stack under the old emission.
"""

import time;


def churn -> int {
    acc: int = 0;
    i: int = 0;
    while i < 1000000 {
        ts: int = __alloca(16);
        __mem_store_i64(ts, i);
        acc += __mem_load_i64(ts) % 65536;
        i += 1;
    }
    return acc;
}

with entry {
    acc: int = churn();
    i: int = 0;
    while i < 1000000 {
        acc += time.monotonic_ns() % 65536;
        i += 1;
    }
    print("done", acc);
}
