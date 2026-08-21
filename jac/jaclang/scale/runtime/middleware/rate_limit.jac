import ipaddress;
import logging;
import threading;
import time;
import hashlib;
import itertools;
import from threading { Lock as _RLLock }
import from jaclang.scale.state.state_backend { StateBackend }
import from jaclang.scale.state.factory { get_state_backend }

glob _mw_seq = itertools.count();

glob logger = logging.getLogger(__name__),
     _rl_lock = _RLLock();

glob _untrusted_xff_warned = threading.Event();


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


def _parse_trusted_proxies(entries: list) -> list {
    networks: list = [];
    for item in entries {
        try {
            networks.append(ipaddress.ip_network(str(item).strip(), strict=False));
        } except ValueError {
            logger.warning(
                f"Ignoring invalid rate_limit trusted_proxies entry {item!r}; "
                "expected an IP address or CIDR network."
            );
        }
    }
    return networks;
}


def _parse_forwarded_ip(raw: str) -> any {
    s: str = raw.strip();
    if s.startswith("[") {
        s = s[1:].split("]")[0];
    } elif s.count(":") == 1 and "." in s {
        s = s.split(":")[0];
    }
    try {
        return ipaddress.ip_address(s);
    } except ValueError {
        return None;
    }
}


def _is_trusted(ip: any, networks: list) -> bool {
    return any(ip in net for net in networks);
}


def _warn_dropped_xff_once(request: any) -> None {
    if _untrusted_xff_warned.is_set() {
        return;
    }
    if request.headers.get("X-Forwarded-For") is None {
        return;
    }
    _untrusted_xff_warned.set();
    peer: str = request.client_host or "unknown";
    logger.warning(
        f"Ignoring X-Forwarded-For from peer {peer!r}: no trusted_proxies "
        "are configured, so requests are rate-limited by TCP peer address. "
        "If a proxy or ingress fronts this server, set "
        "[scale.microservices.rate_limit] trusted_proxies to its address."
    );
}


def _resolve_client_ip(request: any, trusted_networks: list | None = None) -> str {
    peer: str = request.client_host or "unknown";
    if not trusted_networks {
        return peer;
    }
    peer_ip = _parse_forwarded_ip(peer);
    if peer_ip is None or not _is_trusted(peer_ip, trusted_networks) {
        return peer;
    }
    raw_values = request.headers.getlist("X-Forwarded-For");
    hops: list = [];
    for value in raw_values {
        hops.extend(str(value).split(","));
    }
    for hop in reversed(hops) {
        hop_ip = _parse_forwarded_ip(hop);
        if hop_ip is None {
            return peer;
        }
        if not _is_trusted(hop_ip, trusted_networks) {
            return str(hop_ip);
        }
    }
    return peer;
}


def _resolve_user_key(request: any) -> str | None {
    auth = request.headers.get("Authorization");
    if not auth {
        return None;
    }
    return hashlib.sha256(auth.encode("utf-8")).hexdigest()[:32];
}


def build_rate_limit_middleware(cfg: dict[str, any]) -> any {
    if not cfg.get("enabled") {
        return None;
    }
    per_ip_rpm: int = int(cfg.get("per_ip_rpm", 60));
    per_user_rpm: int = int(cfg.get("per_user_rpm", 0));
    burst: float = float(cfg.get("burst_multiplier", 2.0));
    exempt: set[str] = set(cfg.get("exempt_paths", []));
    trusted_networks: list = _parse_trusted_proxies(
        cfg.get("trusted_proxies", []) or []
    );

    backend: StateBackend = get_state_backend(bool(cfg.get("scale_enabled", False)));

    ns: str = f"mw{next(_mw_seq)}";

    ip_limiter: StateBackendRateLimiter | None = None;
    if per_ip_rpm > 0 {
        ip_limiter = StateBackendRateLimiter(
            backend=backend,
            rate_per_sec=per_ip_rpm / 60.0,
            capacity=max(1.0, per_ip_rpm * burst / 60.0)
        );
    }
    user_limiter: StateBackendRateLimiter | None = None;
    if per_user_rpm > 0 {
        user_limiter = StateBackendRateLimiter(
            backend=backend,
            rate_per_sec=per_user_rpm / 60.0,
            capacity=max(1.0, per_user_rpm * burst / 60.0)
        );
    }

    import from jaclang.scale.runtime.context.errors { error_response }

    async def rate_limit_middleware(request: any, call_next: any) -> any {
        path: str = request.url.path;
        if path in exempt {
            return await call_next(request);
        }
        retry_after: float = 0.0;
        if ip_limiter is not None {
            if not trusted_networks {
                _warn_dropped_xff_once(request);
            }
            key = f"{ns}:ip:{_resolve_client_ip(request, trusted_networks)}";
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
                (ok, ra) = user_limiter.consume(f"{ns}:user:{user_key}");
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
