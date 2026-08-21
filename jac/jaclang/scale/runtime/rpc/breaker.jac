import from threading { Lock as _BreakerLock }
glob _BREAKER_TRIP_THRESHOLD: int = 5,
     _BREAKER_COOLDOWN_SECONDS: float = 30.0,
     _BREAKER_PROBE_GRACE_SECONDS: float = 30.0,
     _BREAKER_NO_PROBE: int = 0,
     _breaker_state: dict[str, dict] = {},
     _breaker_lock = _BreakerLock();

def _breaker_new_state -> dict {
    return {
        "state": "CLOSED",
        "fails": 0,
        "opened_at": 0.0,
        "probe": _BREAKER_NO_PROBE,
        "probe_expires_at": 0.0
    };
}

def _breaker_open(st: dict, now: float) {
    st["state"] = "OPEN";
    st["opened_at"] = now;
    st["probe_expires_at"] = 0.0;
}

def _breaker_close(st: dict) {
    st["state"] = "CLOSED";
    st["fails"] = 0;
    st["opened_at"] = 0.0;
    st["probe_expires_at"] = 0.0;
}

def _breaker_lease_probe(st: dict, now: float, ttl: float) -> int {
    st["state"] = "HALF_OPEN";
    st["probe"] = st.get("probe", _BREAKER_NO_PROBE) + 1;
    st["probe_expires_at"] = now + ttl;
    return st["probe"];
}

def _breaker_holds_probe(st: dict, probe: int) -> bool {
    return probe != _BREAKER_NO_PROBE
        and st.get("state") == "HALF_OPEN"
        and st.get("probe") == probe;
}

def _breaker_verdict_is_current(st: dict, probe: int) -> bool {
    state = st.get("state", "CLOSED");
    if state == "HALF_OPEN" {
        return _breaker_holds_probe(st, probe);
    }
    if state == "OPEN" {
        return False;
    }
    return probe == _BREAKER_NO_PROBE;
}

def _breaker_is_shedding(st: dict, now: float) -> bool {
    state = st.get("state", "CLOSED");
    if state == "OPEN" {
        return (now - st.get("opened_at", 0.0)) < _BREAKER_COOLDOWN_SECONDS;
    }
    if state == "HALF_OPEN" {
        return now < st.get("probe_expires_at", 0.0);
    }
    return False;
}

def breaker_should_skip(provider: str) -> bool {
    import time;
    with _breaker_lock {
        st = _breaker_state.get(provider);
        return st is not None and _breaker_is_shedding(st, time.time());
    }
}

def breaker_admit(provider: str, probe_ttl: float) -> tuple[bool, int] {
    import time;
    with _breaker_lock {
        st = _breaker_state.get(provider);
        if st is None or st.get("state") == "CLOSED" {
            return (True, _BREAKER_NO_PROBE);
        }
        now = time.time();
        if _breaker_is_shedding(st, now) {
            return (False, _BREAKER_NO_PROBE);
        }
        return (True, _breaker_lease_probe(st, now, probe_ttl));
    }
}

def breaker_still_admitted(provider: str, probe: int) -> bool {
    with _breaker_lock {
        st = _breaker_state.get(provider);
        if st is None or st.get("state") == "CLOSED" {
            return True;
        }
        return _breaker_holds_probe(st, probe);
    }
}

def breaker_release_probe(provider: str, probe: int) {
    import time;
    if probe == _BREAKER_NO_PROBE {
        return;
    }
    with _breaker_lock {
        st = _breaker_state.get(provider);
        if st is not None and _breaker_holds_probe(st, probe) {
            _breaker_open(st, time.time());
        }
    }
}

def breaker_record_success(provider: str, probe: int = _BREAKER_NO_PROBE) {
    with _breaker_lock {
        st = _breaker_state.get(provider);
        if st is None {
            _breaker_state[provider] = _breaker_new_state();
            return;
        }
        if _breaker_verdict_is_current(st, probe) {
            _breaker_close(st);
        }
    }
}

def breaker_record_failure(provider: str, probe: int = _BREAKER_NO_PROBE) {
    import time;
    with _breaker_lock {
        st = _breaker_state.get(provider);
        if st is None {
            st = _breaker_new_state();
            _breaker_state[provider] = st;
        }
        if not _breaker_verdict_is_current(st, probe) {
            return;
        }
        if st.get("state") == "HALF_OPEN" {
            _breaker_open(st, time.time());
            return;
        }
        st["fails"] = st.get("fails", 0) + 1;
        if st["fails"] >= _BREAKER_TRIP_THRESHOLD {
            _breaker_open(st, time.time());
        }
    }
}

def _breaker_reset(provider: str) {
    with _breaker_lock {
        if provider in _breaker_state {
            del _breaker_state[provider];
        }
    }
}

def _breaker_peek(provider: str) -> dict | None {
    with _breaker_lock {
        st = _breaker_state.get(provider);
        return dict(st) if st is not None else None;
    }
}

def _breaker_force_cooldown_elapsed(provider: str) {
    with _breaker_lock {
        st = _breaker_state.get(provider);
        if st is not None {
            st["opened_at"] = 0.0;
        }
    }
}

def _breaker_force_probe_expired(provider: str) {
    with _breaker_lock {
        st = _breaker_state.get(provider);
        if st is not None {
            st["probe_expires_at"] = 0.0;
        }
    }
}
