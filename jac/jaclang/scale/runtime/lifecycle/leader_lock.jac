import logging;
import from jaclang.scale.state.state_backend { StateBackend }

glob logger = logging.getLogger(__name__);


def run_once(
    backend: StateBackend, lock_key: str, ttl_seconds: int, task: any
) -> bool {
    if not backend.acquire_lock(lock_key, ttl_seconds) {
        logger.debug(f"leader-lock: skip, lock held: {lock_key}");
        return False;
    }
    task();
    return True;
}
