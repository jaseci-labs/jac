"""Implementation of synchronization primitives for JacLang LSP."""

import threading;
import time;
import sys;
import from typing { Optional }
import from contextlib { contextmanager }

"""Internal debug logging for sync primitives."""
def _sync_debug(msg: str) -> None {
    print(f"[Sync] {msg}", file=sys.stderr);
}

"""Initialize RWLock with required locks."""
impl RWLock.postinit -> None {
    self._read_count = 0;
    self._write_lock = threading.Lock();
    self._read_lock = threading.Lock();
    self._write_waiting = False;
}

"""Acquire read lock.

Multiple readers can hold the lock simultaneously.
First reader acquires the write lock to block writers.
"""
impl RWLock.acquire_read -> None {
    with self._read_lock {
        self._read_count += 1;
        if self._read_count == 1 {
            # First reader blocks writers
            self._write_lock.acquire();
        }
    }
}

"""Release read lock.

Last reader releases the write lock to allow writers.
"""
impl RWLock.release_read -> None {
    with self._read_lock {
        self._read_count -= 1;
        if self._read_count == 0 {
            # Last reader allows writers
            self._write_lock.release();
        }
    }
}

"""Acquire write lock for exclusive access."""
impl RWLock.acquire_write -> None {
    self._write_lock.acquire();
}

"""Release write lock."""
impl RWLock.release_write -> None {
    self._write_lock.release();
}

"""Initialize AnalysisGate with condition variable."""
impl AnalysisGate.postinit -> None {
    self._condition = threading.Condition();
    self._is_idle = True;
    self._pending_count = 0;
}

"""Mark analysis as busy (starting background work).

Increments pending count and sets idle to False.
Called before queuing analysis work.
"""
impl AnalysisGate.mark_busy -> None {
    with self._condition {
        self._pending_count += 1;
        self._is_idle = False;
        _sync_debug(f"AnalysisGate.mark_busy: pending_count={self._pending_count}");
    }
}

"""Mark analysis as idle (background work complete).

Decrements pending count and notifies waiters when
all pending work is complete.
"""
impl AnalysisGate.mark_idle -> None {
    with self._condition {
        self._pending_count = max(0, self._pending_count - 1);
        _sync_debug(f"AnalysisGate.mark_idle: pending_count={self._pending_count}");
        if self._pending_count == 0 {
            self._is_idle = True;
            _sync_debug("AnalysisGate: now idle, notifying waiters");
            self._condition.notify_all();
        }
    }
}

"""Wait until analysis is idle.

Args:
    timeout_ms: Maximum time to wait in milliseconds.
                None means wait indefinitely.

Returns:
    True if analysis became idle, False if timeout.
"""
impl AnalysisGate.wait_until_idle(timeout_ms: Optional[float] = None) -> bool {
    _sync_debug(f"AnalysisGate.wait_until_idle: timeout={timeout_ms}ms");
    timeout_sec = timeout_ms / 1000.0 if timeout_ms else None;
    with self._condition {
        if self._is_idle {
            _sync_debug("AnalysisGate: already idle");
            return True;
        }
        _sync_debug("AnalysisGate: waiting for idle...");
        result = self._condition.wait_for(
            predicate=lambda : self._is_idle, timeout=timeout_sec
        );
        _sync_debug(f"AnalysisGate: wait completed, result={result}");
        return result;
    }
}

"""Check if analysis is currently idle."""
impl AnalysisGate.is_idle -> bool {
    with self._condition {
        return self._is_idle;
    }
}

"""Initialize LockManager with all required locks."""
impl LockManager.postinit -> None {
    self.hub_lock = RWLock();
    self.sem_managers_lock = RWLock();
    self.analysis_gate = AnalysisGate();
}
