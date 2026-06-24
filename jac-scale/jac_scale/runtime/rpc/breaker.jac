# =============================================================================
# Per-provider circuit breaker state for sv-to-sv RPC.
#
# Each provider module gets its own CLOSED/OPEN/HALF_OPEN state machine:
#   CLOSED     - normal. Track consecutive transport failures.
#   OPEN       - tripped. Fail fast; skip httpx.post entirely until
#                cooldown elapses.
#   HALF_OPEN  - cooldown passed. Let the next call through as a probe.
#                Success -> CLOSED (and reset counters). Failure -> OPEN.
#
# Breaker trips on exhausted-retry transport failures only. Application
# envelope errors (ok=false) are deterministic and say nothing about
# whether the provider is reachable, so they do NOT count as failures.
#
# State is process-local (dict + lock). In K8s each pod has its own
# breaker; one misbehaving pod doesn't trip its siblings.
# =============================================================================
import from threading { Lock as _BreakerLock }
glob _BREAKER_TRIP_THRESHOLD: int = 5,
     _BREAKER_COOLDOWN_SECONDS: float = 30.0,
     _breaker_state: dict[str, dict] = {},
     _breaker_lock = _BreakerLock();

"""Check whether a call to `provider` should short-circuit.

Returns True when the breaker is OPEN and the cooldown hasn't elapsed
(caller must raise without hitting the network). Returns False when
CLOSED or when cooldown has elapsed (in which case this call also
transitions OPEN -> HALF_OPEN so the caller's request acts as the
probe).
"""
def breaker_should_skip(provider: str) -> bool {
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
            # Cooldown elapsed: transition to HALF_OPEN so THIS call
            # becomes the probe.
            st["state"] = "HALF_OPEN";
            return False;
        }
        # HALF_OPEN: let the probe through
        return False;
    }
}

"""Record a successful call to `provider`; resets breaker to CLOSED."""
def breaker_record_success(provider: str) {
    with _breaker_lock {
        _breaker_state[provider] = {"state": "CLOSED", "fails": 0, "opened_at": 0.0};
    }
}

"""Record a transport failure against `provider`.

From CLOSED, after N consecutive failures the breaker trips OPEN.
From HALF_OPEN, any failure re-trips OPEN immediately (probe failed).
"""
def breaker_record_failure(provider: str) {
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

"""Test-only: clear breaker state for a provider."""
def _breaker_reset(provider: str) {
    with _breaker_lock {
        if provider in _breaker_state {
            del _breaker_state[provider];
        }
    }
}

"""Test-only: snapshot the breaker state dict for a provider (or None)."""
def _breaker_peek(provider: str) -> dict | None {
    with _breaker_lock {
        st = _breaker_state.get(provider);
        return dict(st) if st is not None else None;
    }
}

"""Test-only: force the cooldown clock into the past so the next
breaker_should_skip call transitions OPEN -> HALF_OPEN without the
test having to wait _BREAKER_COOLDOWN_SECONDS.
"""
def _breaker_force_cooldown_elapsed(provider: str) {
    with _breaker_lock {
        st = _breaker_state.get(provider);
        if st is not None {
            st["opened_at"] = 0.0;
        }
    }
}
