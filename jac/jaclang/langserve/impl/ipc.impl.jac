"""Implementation of IPC utilities."""

import time;
import threading;

impl RequestIdGenerator.postinit -> None {
    self._counter = 0;
    self._lock = threading.Lock();
}

impl RequestIdGenerator.next_id -> str {
    with self._lock {
        self._counter += 1;
        return f"{self._prefix}_{self._counter}_{int(time.time() * 1000)}";
    }
}
