"""Leader lock: run a scheduled job exactly once across replicas.

Each replica's scheduler ticks independently, so without coordination a job with
N replicas fires N times. `run_once` gates a fire on a StateBackend lock keyed by
job id + fire time: the replica that wins the lock runs the task, the others skip.

The lock is intentionally NOT released on success; it is left to expire after
`ttl_seconds` so a slower peer cannot re-run the same fire within the tick window.
With the in-process backend (single replica) the lock is always free, so behavior
is unchanged; with a Redis backend under --scale it becomes real cross-pod
leader election and removes the double-fire.
"""

import logging;
import from jac_scale.state.state_backend { StateBackend }

glob logger = logging.getLogger(__name__);


"""The lock key for one scheduled fire: a job deduped per fire time."""
def fire_lock_key(job_id: str, fire_token: str) -> str {
    return f"sched:lock:{job_id}:{fire_token}";
}


"""Run `task` only if this replica wins the lock `lock_key`.

Returns True when the task ran here, False when a peer already holds the lock
(this fire is handled elsewhere). On a task exception the lock is left held so the
failed fire is not retried by a peer within the same tick window; the caller's
retry policy, not duplicate execution, owns recovery.
"""
def run_once(backend: StateBackend, lock_key: str, ttl_seconds: int, task: any) -> bool {
    if not backend.acquire_lock(lock_key, ttl_seconds) {
        logger.debug(f"leader-lock: skip, lock held: {lock_key}");
        return False;
    }
    task();
    return True;
}
