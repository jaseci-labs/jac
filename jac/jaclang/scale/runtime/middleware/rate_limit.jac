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


impl InProcessRateLimiter.consume(key: str) -> tuple[bool, float] {
    now: float = time.time();
    with _rl_lock {
        bucket = self.buckets.get(key);
        if bucket is None {
            bucket = TokenBucket(
                rate_per_sec=self.rate_per_sec,
                capacity=self.capacity,
                tokens=self.capacity,
                last_refill=now
            );
            self.buckets[key] = bucket;
        }
        elapsed: float = now - bucket.last_refill;
        if elapsed > 0 {
            bucket.tokens = min(
                bucket.capacity, bucket.tokens + elapsed * bucket.rate_per_sec
            );
            bucket.last_refill = now;
        }
        if bucket.tokens >= 1.0 {
            bucket.tokens -= 1.0;
            return (True, 0.0);
        }
        retry = (1.0 - bucket.tokens) / bucket.rate_per_sec;
        return (False, retry);
    }
}


obj StateBackendRateLimiter {
    has backend: StateBackend,
        rate_per_sec: float,
        capacity: float,
        state_ttl_seconds: int = 300,
        lock_ttl_seconds: int = 5;

    def consume(key: str) -> tuple[bool, float];
}


impl StateBackendRateLimiter.consume(key: str) -> tuple[bool, float] {
    now: float = time.time();
    state_key: str = f"rl:{key}";
    lock_key: str = f"rl:lock:{key}";

    acquired: bool = False;
    for _ in range(50) {
        if self.backend.acquire_lock(lock_key, self.lock_ttl_seconds) {
            acquired = True;
            break;
        }
        time.sleep(0.001);
    }
    try {
        raw = self.backend.get(state_key);
        if raw is None {
            tokens: float = self.capacity;
            last_refill: float = now;
        } else {
            parts = raw.split(":");
            tokens = float(parts[0]);
            last_refill = float(parts[1]);
        }
        elapsed: float = now - last_refill;
        if elapsed > 0 {
            tokens = min(self.capacity, tokens + elapsed * self.rate_per_sec);
            last_refill = now;
        }
        if tokens >= 1.0 {
            tokens -= 1.0;
            allowed: bool = True;
            retry: float = 0.0;
        } else {
            allowed = False;
            retry = (1.0 - tokens) / self.rate_per_sec;
        }
        self.backend.set(
            state_key, f"{tokens}:{last_refill}", ttl_seconds=self.state_ttl_seconds
        );
        return (allowed, retry);
    } finally {
        if acquired {
            self.backend.release_lock(lock_key);
        }
    }
}


def _resolve_user_key(request: any) -> str | None;


def build_rate_limit_middleware(cfg: dict[str, any]) -> any;
