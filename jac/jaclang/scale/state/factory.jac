import logging;
import from jaclang.scale.state.state_backend { StateBackend, InProcessStateBackend }

glob logger = logging.getLogger(__name__),
     _backend_holder: dict[str, StateBackend] = {};


def get_state_backend(scale_enabled: bool = False) -> StateBackend {
    backend = _backend_holder.get("default");
    if backend is None {
        if scale_enabled {
            try {
                import from jaclang.scale.state.redis_state_backend {
                    RedisStateBackend
                }
                backend = RedisStateBackend();
            } except Exception as e {
                logger.warning(
                    f"RedisStateBackend unavailable ({e}); falling back to " + "InProcessStateBackend. Shared state will NOT span replicas."
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


def reset_state_backend {
    _backend_holder.clear();
}
