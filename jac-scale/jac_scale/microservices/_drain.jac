"""Graceful drain state (ROADMAP P13). Process-singleton; one uvicorn
per service/gateway means module-level state is the right shape."""

import logging;
import threading;
import time;
import from typing { Any }
import from threading { Lock as _DrainLock }

glob logger = logging.getLogger(__name__);


def _make_preset_event -> threading.Event {
    # Pre-set: inflight starts at 0 so wait_for_zero returns True immediately.
    ev = threading.Event();
    ev.set();
    return ev;
}

glob _is_draining: bool = False,
     _drain_started_ts: float | None = None,
     _drain_timeout_s: float = 10.0,
     _inflight: int = 0,
     _drain_lock = _DrainLock(),
     _zero_event: threading.Event = _make_preset_event();


def is_draining -> bool {
    return _is_draining;
}


def drain_started_ts -> float | None {
    return _drain_started_ts;
}


def drain_timeout_s -> float {
    return _drain_timeout_s;
}


def inflight -> int {
    with _drain_lock {
        return _inflight;
    }
}


"""Idempotent so re-entrant signal handlers are safe."""
def start_drain(timeout_s: float | None = None) -> None {
    global _is_draining,_drain_started_ts,_drain_timeout_s;
    with _drain_lock {
        if _is_draining {
            return;
        }
        _is_draining = True;
        _drain_started_ts = time.time();
        if timeout_s is not None {
            _drain_timeout_s = timeout_s;
        }
        current_inflight = _inflight;
    }
    logger.warning(
        f"drain: started (timeout={_drain_timeout_s}s, inflight={current_inflight})"
    );
}


def incr_inflight -> int {
    global _inflight;
    with _drain_lock {
        _inflight += 1;
        _zero_event.clear();
        return _inflight;
    }
}


def decr_inflight -> int {
    global _inflight;
    with _drain_lock {
        if _inflight > 0 {
            _inflight -= 1;
        }
        if _inflight == 0 {
            _zero_event.set();
        }
        return _inflight;
    }
}


"""Returns True if drained, False on timeout. Threading.Event-based so
signal-handler downstream paths can call it."""
def wait_for_zero(timeout_s: float | None = None) -> bool {
    t = timeout_s if timeout_s is not None else _drain_timeout_s;
    return _zero_event.wait(timeout=t);
}


"""Reset for tests. Never call from production paths."""
def reset_drain {
    global _is_draining,_drain_started_ts,_inflight;
    with _drain_lock {
        _is_draining = False;
        _drain_started_ts = None;
        _inflight = 0;
        _zero_event.set();
    }
}


"""Build the drain HTTP middleware. `service_label` goes into the 503
envelope (e.g. "__gateway__", "cart_app")."""
def build_drain_middleware(service_label: str = "service") -> Any {
    import from jac_scale.microservices._errors { service_unavailable }

    async def drain_middleware(request: Any, call_next: Any) -> Any {
        if not _is_draining {
            incr_inflight();
            try {
                response = await call_next(request);
                return response;
            } finally {
                decr_inflight();
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
    global _drain_timeout_s;
    _drain_timeout_s = timeout_s;
    orig_handle_exit = server.handle_exit;

    def wrapped_handle_exit(sig: Any, frame: Any) {
        start_drain(timeout_s);
        orig_handle_exit(sig, frame);
    }

    server.handle_exit = wrapped_handle_exit;
}
