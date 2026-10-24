import time;
import from threading { Lock as _StateLock }

glob _state_lock = _StateLock();


obj StateBackend {
    def get(key: str) -> (str | None);
    def set(key: str, value: str, ttl_seconds: (int | None) = None);
    def delete(key: str);
    def increment(
        key: str, amount: float = 1.0, ttl_seconds: (int | None) = None
    ) -> float;

    def acquire_lock(key: str, ttl_seconds: int) -> bool;
    def release_lock(key: str);
}


obj InProcessStateBackend(StateBackend) {
    has _values: dict[str, tuple[str, float]] = {},
        _locks: dict[str, float] = {};

    def _purge_if_expired(key: str, now: float);
    def get(key: str) -> (str | None);
    def set(key: str, value: str, ttl_seconds: (int | None) = None);
    def delete(key: str);
    def increment(
        key: str, amount: float = 1.0, ttl_seconds: (int | None) = None
    ) -> float;

    def acquire_lock(key: str, ttl_seconds: int) -> bool;
    def release_lock(key: str);
}
