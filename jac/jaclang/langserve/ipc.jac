"""Inter-process communication utilities.

Simple utilities for worker process communication.
Actual IPC uses plain dicts for pickle compatibility.
"""

import threading;

"""Generates unique request IDs for worker requests."""
obj RequestIdGenerator {
    has _counter: int = 0,
        _prefix: str = "req",
        _lock: threading.Lock | None = None;

    def postinit -> None;
    """Generate unique request ID."""
    def next_id -> str;
}
