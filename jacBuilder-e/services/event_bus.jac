"""EventBus — Thread-safe append-only event log with per-subscriber cursors.

Replaces destructive Queue.get_nowait() drains with a fan-out model:
each subscriber (identified by connection_id) maintains its own cursor
into a shared log. Multiple tabs polling the same (user_id, project_id)
each receive ALL events independently.
"""

import time;
import from threading { Lock }


obj EventBus {
    has max_size: int = 5000,
        _log: list = [],
        _cursors: dict = {},
        _last_drain: dict = {},
        _lock: Lock = Lock(),
        _stale_timeout: float = 300.0;

    """Append an event to the log. Runs GC if log exceeds max_size."""
    def publish(event: dict) -> None {
        with self._lock {
            self._log.append(event);
            if len(self._log) > self.max_size {
                self._gc();
            }
        }
    }

    """Register a subscriber at the current end of the log."""
    def subscribe(connection_id: str) -> None {
        with self._lock {
            self._cursors[connection_id] = len(self._log);
            self._last_drain[connection_id] = time.time();
        }
    }

    """Remove a subscriber."""
    def unsubscribe(connection_id: str) -> None {
        with self._lock {
            self._cursors.pop(connection_id, None);
            self._last_drain.pop(connection_id, None);
        }
    }

    """Drain events from this subscriber's cursor to the end of the log.
    Non-destructive: other subscribers still see these events.
    Auto-subscribes on first call if connection_id is unknown."""
    def drain(connection_id: str) -> list {
        with self._lock {
            cursor = self._cursors.get(connection_id);
            if cursor is None {
                self._cursors[connection_id] = len(self._log);
                self._last_drain[connection_id] = time.time();
                return [];
            }
            events = self._log[cursor:];
            self._cursors[connection_id] = len(self._log);
            self._last_drain[connection_id] = time.time();
            return list(events);
        }
    }

    """Return True if the log has any events (any subscriber could read)."""
    def has_events() -> bool {
        with self._lock {
            return len(self._log) > 0;
        }
    }

    """Clear the entire log and all cursors. Used when resetting a session."""
    def clear() -> None {
        with self._lock {
            self._log = [];
            self._cursors = {};
            self._last_drain = {};
        }
    }

    """Internal: trim log entries that all subscribers have already read.
    Also evicts stale subscribers (no drain in _stale_timeout seconds).
    Must be called while holding self._lock."""
    def _gc() -> None {
        now = time.time();
        stale_ids: list = [];
        for cid in self._last_drain {
            last_time: float = float(self._last_drain[cid]);
            if now - last_time > self._stale_timeout {
                stale_ids.append(cid);
            }
        }
        for cid in stale_ids {
            self._cursors.pop(cid, None);
            self._last_drain.pop(cid, None);
        }

        if not self._cursors {
            self._log = [];
            return;
        }
        min_cursor: int = int(min(self._cursors.values()));
        if min_cursor > 0 {
            self._log = self._log[min_cursor:];
            for cid in list(self._cursors.keys()) {
                cur_val: int = int(self._cursors[cid]);
                self._cursors[cid] = cur_val - min_cursor;
            }
        }
    }

    """Remove subscribers that haven't drained in max_age_seconds."""
    def cleanup_stale(max_age_seconds: float = 300.0) -> int {
        removed = 0;
        with self._lock {
            now = time.time();
            stale_ids: list = [];
            for cid in self._last_drain {
                last_time: float = float(self._last_drain[cid]);
                if now - last_time > max_age_seconds {
                    stale_ids.append(cid);
                }
            }
            for cid in stale_ids {
                self._cursors.pop(cid, None);
                self._last_drain.pop(cid, None);
                removed += 1;
            }
        }
        return removed;
    }
}
