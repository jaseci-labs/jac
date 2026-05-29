"""Consumes the @contextmanager method in a 'with' statement.

Expected: no type errors.
Actual (bug): E1091 + E1092 — type checker sees return type as NoneType
              instead of recognising the context manager protocol.

Run:  jac check contextmanager_repro_main.jac
"""

import from .contextmanager_repro_lock { SimpleLock }

def use_lock {
    lock = SimpleLock();
    with lock.acquire() {
        :> "inside lock";
    }
}
