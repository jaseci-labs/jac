import os;
import socket;
import threading;
import time;
import subprocess;

import from jaclang.byllm.serve.runner { resolve_runner, llama_server_argv }
import from jaclang.byllm.serve.paths { runner_log, runner_pidfile }
import from jaclang.byllm.llama_server { llama_server_unavailable_message }
import from jaclang.byllm.config_loader { get_byllm_config }

"""Bind :0 on loopback and hand back the OS-assigned free port."""
impl _free_port -> int {
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM);
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1);
    s.bind(("127.0.0.1", 0));
    port = s.getsockname()[1];
    s.close();
    return int(port);
}

impl RunnerHandle.base_url -> str {
    return f"http://127.0.0.1:{self.port}";
}

impl RunnerHandle.alive -> bool {
    return self.proc.poll() is None;
}

impl RunnerSupervisor.postinit -> None {
    self._lock = threading.Lock();
    self._track_lock = threading.Lock();
}

"""Return a healthy runner for `alias`, spawning one if needed."""
impl RunnerSupervisor.ensure(alias: str, model_entry: dict, gguf_path: str) -> RunnerHandle {
    # Hot path: no lock (a dict get and a float store are safe under the GIL).
    existing = self.runners.get(alias);
    if existing is not None and existing.alive() {
        self.touch(alias);
        return existing;
    }
    with self._lock {
        # Re-check under the lock: a concurrent request may have just
        # spawned this alias while we waited.
        existing = self.runners.get(alias);
        if existing is not None and existing.alive() {
            self.touch(alias);
            return existing;
        }
        if existing is not None {
            self._stop_locked(alias);   # dead -> clean up before respawning
        }
        # Make room BEFORE loading (max_loaded is a memory bound; evicting
        # after the spawn would hold both models in RAM at once), then spawn.
        # max_loaded includes the one we're about to add.
        self._enforce_capacity_locked(int(self.serve_cfg.get("max_loaded", 1)) - 1);
        handle = self._spawn(alias, model_entry, gguf_path);
        self.runners[alias] = handle;
        return handle;
    }
}

impl RunnerSupervisor.get(alias: str) -> RunnerHandle | None {
    return self.runners.get(alias);
}

impl RunnerSupervisor.touch(alias: str) -> None {
    handle = self.runners.get(alias);
    if handle is not None {
        handle.last_used = time.time();
    }
}

"""Mark a proxied request in flight (blocks eviction of its runner)."""
impl RunnerSupervisor.begin_request(alias: str) -> None {
    with self._track_lock {
        handle = self.runners.get(alias);
        if handle is not None {
            handle.inflight += 1;
            handle.last_used = time.time();
        }
    }
}

"""Mark a proxied request finished; idle time counts from request end."""
impl RunnerSupervisor.end_request(alias: str) -> None {
    with self._track_lock {
        handle = self.runners.get(alias);
        if handle is not None {
            handle.inflight = max(0, handle.inflight - 1);
            handle.last_used = time.time();
        }
    }
}

"""One status row per runner (for `jac model ps` / /api/ps)."""
impl RunnerSupervisor.running -> list[dict] {
    rows: list[dict] = [];
    for (alias, handle) in list(self.runners.items()) {
        rows.append({
            "alias": alias,
            "pid": handle.pid,
            "port": handle.port,
            "variant": handle.variant,
            "ngl": handle.ngl,
            "idle_s": round(time.time() - handle.last_used, 1),
            "inflight": handle.inflight,
            "alive": handle.alive()
        });
    }
    return rows;
}

"""Terminate and forget the runner for `alias`."""
impl RunnerSupervisor.stop(alias: str) -> bool {
    with self._lock {
        return self._stop_locked(alias);
    }
}

impl RunnerSupervisor._stop_locked(alias: str) -> bool {
    handle = self.runners.pop(alias, None);
    try {
        runner_pidfile(alias).unlink(missing_ok=True);
    } except Exception {}
    if handle is None {
        return False;
    }
    self._terminate(handle.proc);
    return True;
}

impl RunnerSupervisor.stop_all -> None {
    with self._lock {
        for alias in list(self.runners.keys()) {
            self._stop_locked(alias);
        }
    }
}

"""Evict runners idle longer than `idle_ttl` seconds (0 disables).

A runner with a request in flight is never idle-evicted, no matter how stale
its last_used looks (a generation can legitimately outlast the TTL).
"""
impl RunnerSupervisor.reap_idle(idle_ttl: int) -> None {
    if idle_ttl <= 0 {
        return;
    }
    now = time.time();
    with self._lock {
        for (alias, handle) in list(self.runners.items()) {
            if handle.inflight > 0 and handle.alive() {
                continue;
            }
            if (not handle.alive()) or (now - handle.last_used > idle_ttl) {
                self._stop_locked(alias);
            }
        }
    }
}

"""Evict runners until at most `keep` remain (lock held by the caller).

Victims are picked LRU-first among idle runners; in-flight runners go last --
but they do go, because max_loaded is a hard memory bound and exceeding it
risks OOM-killing every runner.
"""
impl RunnerSupervisor._enforce_capacity_locked(keep: int) -> None {
    if keep < 0 {
        keep = 0;
    }
    while len(self.runners) > keep {
        victim = None;
        victim_key = None;
        for (alias, handle) in self.runners.items() {
            key = (1 if handle.inflight > 0 else 0, handle.last_used);
            if victim_key is None or key < victim_key {
                victim = alias;
                victim_key = key;
            }
        }
        if victim is None {
            break;
        }
        self._stop_locked(victim);
    }
}

impl RunnerSupervisor._terminate(proc: subprocess.Popen) -> None {
    try {
        if proc.poll() is not None {
            return;
        }
        proc.terminate();
        try {
            proc.wait(timeout=10);
        } except subprocess.TimeoutExpired {
            proc.kill();
            proc.wait();
        }
    } except Exception {}
}

impl RunnerSupervisor._spawn(alias: str, model_entry: dict, gguf_path: str) -> RunnerHandle {
    chosen = resolve_runner(self.serve_cfg);
    binary = chosen["bin"];
    if binary is None {
        raise RuntimeError(llama_server_unavailable_message());
    }
    use_gpu = bool(chosen["use_gpu"]);
    local_cfg = get_byllm_config().get_local_config();
    port = _free_port();
    argv = llama_server_argv(
        binary, alias, gguf_path, port, local_cfg, model_entry, use_gpu
    );
    logf = open(runner_log(alias), "ab");
    proc = subprocess.Popen(
        argv, stdout=logf, stderr=logf, stdin=subprocess.DEVNULL,
        start_new_session=True
    );
    try {
        runner_pidfile(alias).write_text(str(proc.pid));
    } except Exception {}
    ngl_cfg = int(local_cfg.get("n_gpu_layers", 0));
    ngl = ngl_cfg if ngl_cfg != 0 else (999 if use_gpu else 0);
    handle = RunnerHandle(
        alias=alias, proc=proc, port=port, pid=proc.pid,
        last_used=time.time(), ngl=ngl,
        variant=("vulkan" if use_gpu else "cpu")
    );
    if not self._wait_health(handle.base_url(), proc) {
        self._terminate(proc);
        raise RuntimeError(
            f"llama-server for '{alias}' failed to become healthy; see "
            f"{runner_log(alias)}"
        );
    }
    return handle;
}

"""Poll llama-server /health until 200, the process dies, or timeout."""
impl RunnerSupervisor._wait_health(base_url: str, proc: subprocess.Popen) -> bool {
    import urllib.request;
    deadline = time.time() + self.boot_timeout;
    while time.time() < deadline {
        if proc.poll() is not None {
            return False;
        }
        try {
            with urllib.request.urlopen(f"{base_url}/health", timeout=1) as resp {
                if resp.status == 200 {
                    return True;
                }
            }
        } except Exception {
            time.sleep(0.2);
        }
    }
    return False;
}
