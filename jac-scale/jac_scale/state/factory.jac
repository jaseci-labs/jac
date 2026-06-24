"""Selects and caches the process-wide StateBackend from the deployment dial.

`--scale` (multi-replica k8s) will select a RedisStateBackend so shared state
spans pods; every other cell uses the in-process default. Centralizing the
choice here keeps every consumer (rate limiting, scheduler locks, token store)
agnostic to which backend is wired.

When `scale_enabled` is set the Redis adapter is selected so shared state spans
pods; if redis cannot be imported or connected the factory logs a warning and
falls back to the in-process backend, so local and test paths never crash.
"""

import logging;
import from jac_scale.state.state_backend { StateBackend, InProcessStateBackend }

glob logger = logging.getLogger(__name__);

"""Single-slot holder so the backend is created once per process. A dict avoids
reassigning a module global from inside the function."""
glob _backend_holder: dict[str, StateBackend] = {};


"""Return the process-wide StateBackend, creating it on first use.

Args:
    scale_enabled: reflects the --scale dial. When True the Redis adapter is
        used so shared state spans replicas; otherwise the in-process default.
        A failed redis import/connect falls back to the in-process backend.
"""
def get_state_backend(scale_enabled: bool = False) -> StateBackend {
    backend = _backend_holder.get("default");
    if backend is None {
        if scale_enabled {
            try {
                import from jac_scale.state.redis_state_backend { RedisStateBackend }
                backend = RedisStateBackend();
            } except Exception as e {
                logger.warning(
                    f"RedisStateBackend unavailable ({e}); falling back to "
                    + "InProcessStateBackend. Shared state will NOT span replicas."
                );
                backend = InProcessStateBackend();
            }
        } else {
            backend = InProcessStateBackend();
        }
        _backend_holder["default"] = backend;
    }
    return backend;
}


"""Reset the cached backend. Test helper; not used in production paths."""
def reset_state_backend() -> None {
    _backend_holder.clear();
}
