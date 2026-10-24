import logging;
import time;
import hashlib;
import from threading { Lock as _RLLock }

glob logger = logging.getLogger(__name__),
     _rl_lock = _RLLock(),
     NAMESPACE: str = "gateway";


obj TokenBucket {
    has rate_per_sec: float,
        capacity: float,
        tokens: float = 0.0,
        last_refill: float = 0.0;
}


obj InProcessRateLimiter {
    has rate_per_sec: float,
        capacity: float,
        buckets: dict[str, TokenBucket] = {};

    def consume(key: str) -> tuple[bool, float];
}


obj StateBackendRateLimiter {
    has backend: StateBackend,
        rate_per_sec: float,
        capacity: float,
        state_ttl_seconds: int = 300,
        lock_ttl_seconds: int = 5;

    def consume(key: str) -> tuple[bool, float];
}


def _resolve_user_key(request: any) -> str | None;


def build_rate_limit_middleware(cfg: dict[str, any]) -> any;
