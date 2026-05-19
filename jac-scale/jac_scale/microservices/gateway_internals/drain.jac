"""Graceful drain coordinator (ROADMAP P13). One uvicorn per service /
gateway means one DrainCoordinator per process; the module-level
singleton + wrapper functions preserve the prior function-call API."""

import logging;
import threading;
import time;
import from typing { Any }
import from threading { Lock as _DrainLock }

glob logger = logging.getLogger(__name__),
     # Liveness must stay 200 mid-drain; readiness has its own draining handler.
     _DRAIN_EXEMPT_PATHS: set[str] = {"/healthz/live","/healthz/ready"};


# Pre-set: inflight=0 so wait_for_zero returns True immediately.
def _make_preset_event -> threading.Event {
    ev = threading.Event();
    ev.set();
    return ev;
}


obj DrainCoordinator {
    has _is_draining: bool = False,
        _drain_started_ts: float | None = None,
        _drain_timeout_s: float = 10.0,
        _inflight: int = 0,
        _lock: Any by postinit,
        _zero_event: Any by postinit;

    def postinit {
        self._lock = _DrainLock();
        self._zero_event = _make_preset_event();
    }

    def is_draining -> bool {
        return self._is_draining;
    }

    def drain_timeout_s -> float {
        return self._drain_timeout_s;
    }

    def set_timeout(timeout_s: float) {
        self._drain_timeout_s = timeout_s;
    }

    def inflight -> int {
        self._lock.acquire();
        try {
            return self._inflight;
        } finally {
            self._lock.release();
        }
    }

    """Idempotent so re-entrant signal handlers are safe."""
    def start_drain(timeout_s: float | None = None) -> None {
        self._lock.acquire();
        try {
            if self._is_draining {
                return;
            }
            self._is_draining = True;
            self._drain_started_ts = time.time();
            if timeout_s is not None {
                self._drain_timeout_s = timeout_s;
            }
            current_inflight = self._inflight;
        } finally {
            self._lock.release();
        }
        logger.warning(
            f"drain: started (timeout={self._drain_timeout_s}s, "
            f"inflight={current_inflight})"
        );
    }

    def incr_inflight -> int {
        self._lock.acquire();
        try {
            self._inflight += 1;
            self._zero_event.clear();
            return self._inflight;
        } finally {
            self._lock.release();
        }
    }

    def decr_inflight -> int {
        self._lock.acquire();
        try {
            if self._inflight > 0 {
                self._inflight -= 1;
            }
            if self._inflight == 0 {
                self._zero_event.set();
            }
            return self._inflight;
        } finally {
            self._lock.release();
        }
    }

    """Returns True if drained, False on timeout."""
    def wait_for_zero(timeout_s: float | None = None) -> bool {
        t = timeout_s if timeout_s is not None else self._drain_timeout_s;
        return bool(self._zero_event.wait(timeout=t));
    }

    """Reset for tests; never call from production paths."""
    def reset {
        self._lock.acquire();
        try {
            self._is_draining = False;
            self._drain_started_ts = None;
            self._inflight = 0;
            self._zero_event.set();
        } finally {
            self._lock.release();
        }
    }
}


# Process-singleton coordinator backing the function-call API.
glob _default_coordinator: DrainCoordinator = DrainCoordinator();


def is_draining -> bool {
    return _default_coordinator.is_draining();
}

def drain_timeout_s -> float {
    return _default_coordinator.drain_timeout_s();
}

def inflight -> int {
    return _default_coordinator.inflight();
}

def start_drain(timeout_s: float | None = None) {
    _default_coordinator.start_drain(timeout_s);
}

def incr_inflight -> int {
    return _default_coordinator.incr_inflight();
}

def decr_inflight -> int {
    return _default_coordinator.decr_inflight();
}

def wait_for_zero(timeout_s: float | None = None) -> bool {
    return _default_coordinator.wait_for_zero(timeout_s);
}

def reset_drain {
    _default_coordinator.reset();
}


def build_drain_middleware(service_label: str = "service") -> Any {
    import from jac_scale.microservices.runtime.errors { service_unavailable }

    async def drain_middleware(request: Any, call_next: Any) -> Any {
        # `getattr` (vs attr access) keeps the unit-test bare-`object()`
        # request shape working alongside production Starlette Requests.
        url = request?.url;
        path = getattr(url, "path", "") if url is not None else "";
        if path in _DRAIN_EXEMPT_PATHS {
            return await call_next(request);
        }
        if not _default_coordinator.is_draining() {
            _default_coordinator.incr_inflight();
            try {
                response = await call_next(request);
                return response;
            } finally {
                _default_coordinator.decr_inflight();
            }
        }
        return service_unavailable(service_label, "draining");
    }
    return drain_middleware;
}


"""Wrap uvicorn.Server.handle_exit so SIGTERM/SIGINT flips the drain
flag before uvicorn's own exit handler runs. Call after constructing
the Server, before `server.run()`."""
def install_signal_drain(server: Any, timeout_s: float = 10.0) {
    _default_coordinator.set_timeout(timeout_s);
    orig_handle_exit = server.handle_exit;

    def wrapped_handle_exit(sig: Any, frame: Any) {
        _default_coordinator.start_drain(timeout_s);
        orig_handle_exit(sig, frame);
    }

    server.handle_exit = wrapped_handle_exit;
}
