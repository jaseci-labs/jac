"""Read-Write Lock for concurrent reader access with exclusive writer access."""

import threading;
import from contextlib { contextmanager }

"""A Read-Write Lock that allows concurrent readers but exclusive writers.

Multiple threads can hold the read lock simultaneously.
Only one thread can hold the write lock, and it excludes all readers.
Writers have priority: once a writer is waiting, new readers block.
NOT reentrant: a thread must not attempt to acquire the same lock twice.
"""
obj ReadWriteLock {
    has _cond: threading.Condition by postinit,
        _readers: int = 0,
        _writer: bool = False,
        _writers_waiting: int = 0;

    def postinit -> None;
    def acquire_read -> None;
    def release_read -> None;
    def acquire_write -> None;
    def release_write -> None;
    @contextmanager
    def read_lock -> None;

    @contextmanager
    def write_lock -> None;
}

impl ReadWriteLock.postinit -> None {
    self._cond = threading.Condition(threading.Lock());
}

"""Acquire the read lock. Blocks while a writer is active or waiting."""
impl ReadWriteLock.acquire_read -> None {
    with self._cond {
        while self._writer or self._writers_waiting > 0 {
            self._cond.wait();
        }
        self._readers += 1;
    }
}

"""Release the read lock."""
impl ReadWriteLock.release_read -> None {
    with self._cond {
        self._readers -= 1;
        if self._readers == 0 {
            self._cond.notify_all();
        }
    }
}

"""Acquire the write lock. Blocks while readers or another writer are active."""
impl ReadWriteLock.acquire_write -> None {
    with self._cond {
        self._writers_waiting += 1;
        while self._writer or self._readers > 0 {
            self._cond.wait();
        }
        self._writers_waiting -= 1;
        self._writer = True;
    }
}

"""Release the write lock."""
impl ReadWriteLock.release_write -> None {
    with self._cond {
        self._writer = False;
        self._cond.notify_all();
    }
}

"""Context manager for acquiring/releasing the read lock."""
impl ReadWriteLock.read_lock -> None {
    self.acquire_read();
    try {
        yield ;
    } finally {
        self.release_read();
    }
}

"""Context manager for acquiring/releasing the write lock."""
impl ReadWriteLock.write_lock -> None {
    self.acquire_write();
    try {
        yield ;
    } finally {
        self.release_write();
    }
}
