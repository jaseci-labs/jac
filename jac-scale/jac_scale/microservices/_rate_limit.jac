"""Token-bucket rate limiter for the microservice gateway (ROADMAP P17).

Two optional buckets per request:
  per-IP  keyed on X-Forwarded-For / request.client.host
  per-user keyed on SHA256(Authorization) (unauthenticated requests
          skip this bucket)

Both buckets must have a token for the request to proceed. 429 with
`Retry-After` + standard error envelope otherwise.

In-process dict backend only. A Redis-backed `RateLimiterBackend` can
slot in behind the same interface for K8s horizontal scaling.
"""

import logging;
import threading;
import time;
import hashlib;
import from typing { Any }
import from threading { Lock as _RLLock }

glob logger = logging.getLogger(__name__),
     _rl_lock = _RLLock();


obj TokenBucket {
    has rate_per_sec: float,
        capacity: float,
        tokens: float = 0.0,
        last_refill: float = 0.0;
}


"""In-process rate limiter. Buckets share a module-level lock - contention
is negligible because state per bucket is tiny (two floats)."""
obj InProcessRateLimiter {
    has rate_per_sec: float,
        capacity: float,
        buckets: dict[str, TokenBucket] = {};

    """Try to consume one token for `key`. Returns (allowed, retry_after_s)."""
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
        # Seconds until a full token is available again.
        retry = (1.0 - bucket.tokens) / bucket.rate_per_sec;
        return (False, retry);
    }
}


def _resolve_client_ip(request: Any) -> str {
    xff = request.headers.get("X-Forwarded-For");
    if xff {
        return xff.split(",")[0].strip();
    }
    client = request?.client;
    return getattr(client, "host", "unknown") if client else "unknown";
}


def _resolve_user_key(request: Any) -> str | None {
    auth = request.headers.get("Authorization");
    if not auth {
        return None;
    }
    return hashlib.sha256(auth.encode("utf-8")).hexdigest()[:32];
}


"""Build the rate-limit middleware from a config dict. Returns None when
disabled so the caller can skip registration entirely."""
def build_rate_limit_middleware(cfg: dict[str, Any]) -> Any {
    if not cfg.get("enabled") {
        return None;
    }
    per_ip_rpm: int = int(cfg.get("per_ip_rpm", 60));
    per_user_rpm: int = int(cfg.get("per_user_rpm", 0));
    burst: float = float(cfg.get("burst_multiplier", 2.0));
    exempt: set[str] = set(cfg.get("exempt_paths", []));

    ip_limiter: InProcessRateLimiter | None = None;
    if per_ip_rpm > 0 {
        ip_limiter = InProcessRateLimiter(
            rate_per_sec=per_ip_rpm / 60.0, capacity=max(1.0, per_ip_rpm * burst / 60.0)
        );
    }
    user_limiter: InProcessRateLimiter | None = None;
    if per_user_rpm > 0 {
        user_limiter = InProcessRateLimiter(
            rate_per_sec=per_user_rpm / 60.0,
            capacity=max(1.0, per_user_rpm * burst / 60.0)
        );
    }

    import from jac_scale.microservices._errors { error_response }

    async def rate_limit_middleware(request: Any, call_next: Any) -> Any {
        path: str = request.url.path;
        if path in exempt {
            return await call_next(request);
        }
        retry_after: float = 0.0;
        if ip_limiter is not None {
            key = f"ip:{_resolve_client_ip(request)}";
            (ok, ra) = ip_limiter.consume(key);
            if not ok {
                retry_after = max(retry_after, ra);
                return error_response(
                    code="RATE_LIMITED",
                    message="Too many requests; slow down.",
                    status=429,
                    retry_after_seconds=int(retry_after) + 1
                );
            }
        }
        if user_limiter is not None {
            user_key = _resolve_user_key(request);
            if user_key is not None {
                (ok, ra) = user_limiter.consume(f"user:{user_key}");
                if not ok {
                    return error_response(
                        code="RATE_LIMITED",
                        message="Per-user rate limit exceeded.",
                        status=429,
                        retry_after_seconds=int(ra) + 1
                    );
                }
            }
        }
        return await call_next(request);
    }

    return rate_limit_middleware;
}
