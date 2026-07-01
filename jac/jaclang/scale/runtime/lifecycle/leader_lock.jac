import logging;
import from jaclang.scale.state.state_backend { StateBackend }

glob logger = logging.getLogger(__name__);


def fire_lock_key(job_id: str, fire_token: str) -> str {
    return f"sched:lock:{job_id}:{fire_token}";
}


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
