impl breaker_should_skip(provider: str) -> bool {
    import time;
    with _breaker_lock {
        st = _breaker_state.get(provider);
        if st is None or st.get("state") == "CLOSED" {
            return False;
        }
        if st.get("state") == "OPEN" {
            elapsed = time.time() - st.get("opened_at", 0.0);
            if elapsed < _BREAKER_COOLDOWN_SECONDS {
                return True;
            }

            st["state"] = "HALF_OPEN";
            return False;
        }
        return False;
    }
}

impl breaker_record_success(provider: str) {
    with _breaker_lock {
        _breaker_state[provider] = {"state": "CLOSED", "fails": 0, "opened_at": 0.0};
    }
}

impl breaker_record_failure(provider: str) {
    import time;
    with _breaker_lock {
        st = _breaker_state.get(provider)
            or {"state": "CLOSED", "fails": 0, "opened_at": 0.0};
        current = st.get("state", "CLOSED");
        if current == "HALF_OPEN" {
            st["state"] = "OPEN";
            st["opened_at"] = time.time();
        } else {
            st["fails"] = st.get("fails", 0) + 1;
            if st["fails"] >= _BREAKER_TRIP_THRESHOLD {
                st["state"] = "OPEN";
                st["opened_at"] = time.time();
            }
        }
        _breaker_state[provider] = st;
    }
}

impl _breaker_reset(provider: str) {
    with _breaker_lock {
        if provider in _breaker_state {
            del _breaker_state[provider];
        }
    }
}

impl _breaker_peek(provider: str) -> dict[str, any] | None {
    with _breaker_lock {
        st = _breaker_state.get(provider);
        return dict(st) if st is not None else None;
    }
}

impl _breaker_force_cooldown_elapsed(provider: str) {
    with _breaker_lock {
        st = _breaker_state.get(provider);
        if st is not None {
            st["opened_at"] = 0.0;
        }
    }
}
