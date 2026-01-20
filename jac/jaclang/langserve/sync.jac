"""Thread synchronization primitives for JacLang LSP."""

import threading;
import time;
import from typing { Optional, ContextManager }
import from contextlib { contextmanager }

"""Read-Write Lock implementation.

Allows multiple readers to hold the lock simultaneously,
but writers have exclusive access. This enables foreground
handlers to read state without blocking each other, while
background analysis gets exclusive write access.
"""
obj RWLock {
    has _read_count: int = 0,
        _write_lock: threading.Lock | None = None,
        _read_lock: threading.Lock | None = None,
        _write_waiting: bool = False;

    def postinit -> None;
    def acquire_read -> None;
    def release_read -> None;
    def acquire_write -> None;
    def release_write -> None;
}

"""Condition variable wrapper for analysis completion.

Used to signal foreground handlers when background analysis
is idle, allowing them to wait for fresh results when needed
(e.g., for completion requests).
"""
obj AnalysisGate {
    has _condition: threading.Condition | None = None,
        _is_idle: bool = True,
        _pending_count: int = 0;

    def postinit -> None;
    def mark_busy -> None;
    def mark_idle -> None;
    def wait_until_idle(timeout_ms: Optional[float] = None) -> bool;
    def is_idle -> bool;
}

"""Central lock manager for all LSP synchronization.

Ensures consistent lock ordering to prevent deadlocks:
1. hub_lock (first)
2. sem_managers_lock (second)
3. analysis_gate (last)

Usage:
- For read operations: use acquire_for_query()
- For write operations: use acquire_for_update()
"""
obj LockManager {
    has hub_lock: RWLock | None = None,
        sem_managers_lock: RWLock | None = None,
        analysis_gate: AnalysisGate | None = None;

    def postinit -> None;
}
