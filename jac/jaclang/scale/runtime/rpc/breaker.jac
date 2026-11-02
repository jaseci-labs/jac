import from threading { Lock as _BreakerLock }
glob _BREAKER_TRIP_THRESHOLD: int = 5,
     _BREAKER_COOLDOWN_SECONDS: float = 30.0,
     _breaker_state: dict[str, dict[str, any]] = {},
     _breaker_lock = _BreakerLock();

def breaker_should_skip(provider: str) -> bool;

def breaker_record_success(provider: str);

def breaker_record_failure(provider: str);

def _breaker_reset(provider: str);

def _breaker_peek(provider: str) -> dict[str, any] | None;

def _breaker_force_cooldown_elapsed(provider: str);
