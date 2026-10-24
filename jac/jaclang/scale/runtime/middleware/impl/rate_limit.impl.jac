impl _resolve_user_key(request: any) -> str | None {
    auth = request.headers.get("Authorization");
    if not auth {
        return None;
    }
    return hashlib.sha256(auth.encode("utf-8")).hexdigest()[:32];
}

impl build_rate_limit_middleware(cfg: dict[str, any]) -> any {
    if not cfg.get("enabled") {
        return None;
    }
    per_ip_rpm: int = int(cfg.get("per_ip_rpm", 60));
    per_user_rpm: int = int(cfg.get("per_user_rpm", 0));
    burst: float = float(cfg.get("burst_multiplier", 2.0));
    exempt: set[str] = set(cfg.get("exempt_paths", []));

    backend: StateBackend = get_state_backend(shared=bool(cfg.get("shared", False)));

    ns: str = NAMESPACE;

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

    async def rate_limit_middleware(request: any, call_next: any) -> any {
        path: str = request.url.path;
        if path in exempt {
            return await call_next(request);
        }
        retry_after: float = 0.0;
        if ip_limiter is not None {
            key = f"{ns}:ip:{request.client_host or 'unknown'}";
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
