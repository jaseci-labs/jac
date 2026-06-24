"""Redis-backed StateBackend for multi-replica deployments.

Implements the same `StateBackend` port as `InProcessStateBackend` over a Redis
client, so rate-limit buckets, scheduler leader locks, and the token store stay
coherent across pods. The redis client is reused from `jac_scale.db`
(`get_redis_client`, which reads `[plugins.scale.database].redis_url`); redis is
an optional dependency, so the import is guarded and a missing/unreachable redis
surfaces as a clear error in postinit rather than an obscure failure later.
"""

import from jac_scale.state.state_backend { StateBackend }


"""StateBackend over a Redis client. Network adapter for the --scale path."""
obj RedisStateBackend(StateBackend) {
    # Concrete redis.Redis client; resolved in postinit when not injected.
    has client: any = None,
        url: (str | None) = None;

    def postinit {
        if self.client is None {
            try {
                import from jac_scale.db { get_redis_client }
            } except ImportError as e {
                raise RuntimeError(
                    "RedisStateBackend requires the redis client helper "
                    + "(jac_scale.db.get_redis_client); install the optional "
                    + "'data' dependency group. Original error: "
                    + str(e)
                );
            }
            self.client = get_redis_client(self.url);
        }
    }

    """Decode a redis GET result (bytes|str|None) to str|None."""
    def _decode(raw: any) -> (str | None) {
        if raw is None {
            return None;
        }
        if isinstance(raw, bytes) {
            return raw.decode("utf-8");
        }
        return str(raw);
    }

    def get(key: str) -> (str | None) {
        return self._decode(self.client.get(key));
    }

    def set(key: str, value: str, ttl_seconds: (int | None) = None) -> None {
        if ttl_seconds is not None {
            self.client.set(key, value, ex=ttl_seconds);
        } else {
            self.client.set(key, value);
        }
    }

    def delete(key: str) -> None {
        self.client.delete(key);
    }

    def increment(key: str, amount: float = 1.0, ttl_seconds: (int | None) = None) -> float {
        # INCRBYFLOAT creates the key at 0 on first use; set the expiry only then
        # so a TTL is not refreshed on every increment.
        existed = self.client.exists(key);
        updated = float(self.client.incrbyfloat(key, amount));
        if ttl_seconds is not None and not existed {
            self.client.expire(key, ttl_seconds);
        }
        return updated;
    }

    def acquire_lock(key: str, ttl_seconds: int) -> bool {
        # SET key 1 NX PX ttl: atomic test-and-set with auto-expiry.
        result = self.client.set(key, "1", nx=True, px=ttl_seconds * 1000);
        return bool(result);
    }

    def release_lock(key: str) -> None {
        self.client.delete(key);
    }
}
