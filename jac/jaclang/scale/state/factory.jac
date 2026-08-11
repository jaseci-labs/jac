import logging;
import from jaclang.scale.state.state_backend { StateBackend, InProcessStateBackend }
import from jaclang.scale.persistence.pg { shared_store }
import from jaclang.scale.state.pg_state_backend { PgStateBackend }

glob logger = logging.getLogger(__name__),
     _backend_holder: dict[str, StateBackend] = {};


def get_state_backend(scale_enabled: bool = False) -> StateBackend {
    backend = _backend_holder.get("default");
    if backend is None {
        if scale_enabled {
            try {
                store = shared_store();
                assert store is not None , "no reachable database";
                backend = PgStateBackend(store=store);
            } except Exception as e {
                logger.warning(
                    f"PgStateBackend unavailable ({e}); falling back to "
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
