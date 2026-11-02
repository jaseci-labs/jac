import logging;
import os;
import socket;
import threading;
import uuid;

glob logger = logging.getLogger(__name__);


def _lock_owner -> str;


obj PgStateBackend(StateBackend) {
    has store: any,
        _held: dict[str, str] = {},
        _held_guard: threading.Lock = threading.Lock();

    def get(key: str) -> (str | None);
    def `set(key: str, value: str, ttl_seconds: (int | None) = None);
    def delete(key: str);
    def increment(
        key: str, amount: float = 1.0, ttl_seconds: (int | None) = None
    ) -> float;

    def acquire_lock(key: str, ttl_seconds: int) -> bool;
    def release_lock(key: str);
}
