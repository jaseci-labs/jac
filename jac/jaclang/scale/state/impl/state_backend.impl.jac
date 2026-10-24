impl StateBackend.get(key: str) -> (str | None) {
    raise NotImplementedError("get() must be implemented by a StateBackend");
}

impl StateBackend.set(key: str, value: str, ttl_seconds: (int | None) = None) {
    raise NotImplementedError("set() must be implemented by a StateBackend");
}

impl StateBackend.delete(key: str) {
    raise NotImplementedError("delete() must be implemented by a StateBackend");
}

impl StateBackend.increment(
    key: str, amount: float = 1.0, ttl_seconds: (int | None) = None
) -> float {
    raise NotImplementedError("increment() must be implemented by a StateBackend");
}

impl StateBackend.acquire_lock(key: str, ttl_seconds: int) -> bool {
    raise NotImplementedError("acquire_lock() must be implemented by a StateBackend");
}

impl StateBackend.release_lock(key: str) {
    raise NotImplementedError("release_lock() must be implemented by a StateBackend");
}

impl InProcessStateBackend._purge_if_expired(key: str, now: float) {
    `entry = self._values.get(key);
    if `entry is not None {
        (_, expiry) = `entry;
        if expiry != 0.0 and now >= expiry {
            self._values.pop(key, None);
        }
    }
}

impl InProcessStateBackend.get(key: str) -> (str | None) {
    now = time.time();
    with _state_lock {
        self._purge_if_expired(key, now);
        `entry = self._values.get(key);
        if `entry is None {
            return None;
        }
        (value, _) = `entry;
        return value;
    }
}

impl InProcessStateBackend.set(key: str, value: str, ttl_seconds: (int | None) = None) {
    expiry = (time.time() + ttl_seconds) if ttl_seconds is not None else 0.0;
    with _state_lock {
        self._values[key] = (value, expiry);
    }
}

impl InProcessStateBackend.delete(key: str) {
    with _state_lock {
        self._values.pop(key, None);
    }
}

impl InProcessStateBackend.increment(
    key: str, amount: float = 1.0, ttl_seconds: (int | None) = None
) -> float {
    now = time.time();
    with _state_lock {
        self._purge_if_expired(key, now);
        `entry = self._values.get(key);
        if `entry is not None {
            (raw, keep_expiry) = `entry;
            current = float(raw);
        } else {
            current = 0.0;
            keep_expiry = (now + ttl_seconds) if ttl_seconds is not None else 0.0;
        }
        updated = current + amount;
        self._values[key] = (str(updated), keep_expiry);
        return updated;
    }
}

impl InProcessStateBackend.acquire_lock(key: str, ttl_seconds: int) -> bool {
    now = time.time();
    with _state_lock {
        held_until = self._locks.get(key);
        if held_until is not None and now < held_until {
            return False;
        }
        self._locks[key] = now + ttl_seconds;
        return True;
    }
}

impl InProcessStateBackend.release_lock(key: str) {
    with _state_lock {
        self._locks.pop(key, None);
    }
}
