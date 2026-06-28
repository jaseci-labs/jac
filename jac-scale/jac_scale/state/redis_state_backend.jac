import from jac_scale.state.state_backend { StateBackend }


obj RedisStateBackend(StateBackend) {
    has client: any = None,
        url: (str | None) = None;

    def postinit {
        if self.client is None {
            try {
                import from jac_scale.persistence.db { get_redis_client }
            } except ImportError as e {
                raise RuntimeError(
                    "RedisStateBackend requires the redis client helper " + "(jac_scale.persistence.db.get_redis_client); install the optional " + "'data' dependency group. Original error: " + str(
                        e
                    )
                );
            }
            self.client = get_redis_client(self.url);
        }
    }

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

    def set(key: str, value: str, ttl_seconds: (int | None) = None) {
        if ttl_seconds is None {
            self.client.set(key, value);
        } elif ttl_seconds <= 0 {
            self.client.delete(key);
        } else {
            self.client.set(key, value, ex=ttl_seconds);
        }
    }

    def delete(key: str) {
        self.client.delete(key);
    }

    def increment(
        key: str, amount: float = 1.0, ttl_seconds: (int | None) = None
    ) -> float {
        existed = self.client.exists(key);
        updated = float(self.client.incrbyfloat(key, amount));
        if ttl_seconds is not None and not existed {
            self.client.expire(key, ttl_seconds);
        }
        return updated;
    }

    def acquire_lock(key: str, ttl_seconds: int) -> bool {
        px_ms = max(1, ttl_seconds * 1000);
        result = self.client.set(key, "1", nx=True, px=px_ms);
        return bool(result);
    }

    def release_lock(key: str) {
        self.client.delete(key);
    }
}
