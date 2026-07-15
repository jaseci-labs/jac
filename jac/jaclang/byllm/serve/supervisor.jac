"""Supervises `llama-server` runner subprocesses for the model daemon.

A machine-wide analog of the scale orchestrator's ServiceProcessManager, but
pointed at the machine-wide run dir and with no ServiceRegistry coupling: it
spawns one llama-server per loaded alias (crash isolation), health-checks it,
tracks last-used for idle eviction, and shuts down with SIGTERM->SIGKILL.

Thread-safety (the daemon serves from a ThreadingHTTPServer): `_lock`
serializes every spawn/evict/`runners` mutation -- concurrent first requests
for one alias must not each load a multi-GB model, and serializing cold loads
across aliases keeps peak RAM bounded. The hot path (an alive runner) takes no
lock. `_track_lock` guards only the per-runner in-flight counters, so marking
a request in flight never waits behind a cold load.
"""

import subprocess;

def _free_port -> int;

"""A running llama-server runner for one alias."""
obj RunnerHandle {
    has alias: str,
        proc: subprocess.Popen,
        port: int,
        pid: int,
        last_used: float,
        ngl: int,
        variant: str,
        inflight: int = 0;   # proxied requests currently running against it

    def base_url -> str;
    def alive -> bool;
}

obj RunnerSupervisor {
    has serve_cfg: dict,
        boot_timeout: float = 120.0,
        runners: dict = {},          # alias -> RunnerHandle
        _lock: object = None,        # serializes spawn/evict + runners mutation
        _track_lock: object = None;  # guards in-flight counters (held briefly)

    def postinit -> None;
    def ensure(alias: str, model_entry: dict, gguf_path: str) -> RunnerHandle;
    def get(alias: str) -> RunnerHandle | None;
    def touch(alias: str) -> None;
    def begin_request(alias: str) -> None;
    def end_request(alias: str) -> None;
    def running -> list[dict];
    def stop(alias: str) -> bool;
    def _stop_locked(alias: str) -> bool;
    def stop_all -> None;
    def reap_idle(idle_ttl: int) -> None;
    def _enforce_capacity_locked(keep: int) -> None;
    def _terminate(proc: subprocess.Popen) -> None;
    def _spawn(alias: str, model_entry: dict, gguf_path: str) -> RunnerHandle;
    def _wait_health(base_url: str, proc: subprocess.Popen) -> bool;
}
