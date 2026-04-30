"""Implementation of ServiceProcessManager methods."""

import from pathlib { Path as _Path }

"""Path to the pidfile for a service.

We use `.jac/run/{name}.pid` so `jac scale stop/restart/destroy` can
find running processes from a fresh CLI invocation, where
`self.processes` is always empty (each `jac` command runs in its own
Python process).
"""
def _pidfile_path(name: str) -> _Path {
    return _Path(".jac/run") / f"{name}.pid";
}

"""Write a service's pid to its pidfile."""
def _write_pidfile(name: str, pid: int) {
    run_dir = _Path(".jac/run");
    run_dir.mkdir(parents=True, exist_ok=True);
    _pidfile_path(name).write_text(str(pid));
}

"""Read a service's recorded pid, or None if no pidfile or unreadable."""
def _read_pidfile(name: str) -> int | None {
    path = _pidfile_path(name);
    try {
        if not path.exists() {
            return None;
        }
        content: str = path.read_text().strip();
        if not content {
            return None;
        }
        return int(content);
    } except (ValueError, OSError) {
        return None;
    }
}

"""Remove a service's pidfile (idempotent)."""
def _remove_pidfile(name: str) {
    path = _pidfile_path(name);
    try {
        if path.exists() {
            path.unlink();
        }
    } except OSError {
        ;
    }
}

"""Check whether a pid refers to a live process.

Uses `os.kill(pid, 0)`, which delivers no signal but raises
ProcessLookupError if the pid doesn't exist. Returns False for
invalid pids or permission errors (both indicate "can't signal it,
treat as dead from our point of view").
"""
def _pid_alive(pid: int) -> bool {
    import os;
    if pid <= 0 {
        return False;
    }
    try {
        os.kill(pid, 0);
        return True;
    } except ProcessLookupError {
        return False;
    } except OSError {
        return False;
    }
}

"""Resolve a service's base URL via the owning deployer.

Falls back to the loopback shape used by LocalDeployer so tests that
instantiate ServiceProcessManager directly (without a deployer wired
in) keep working without a mock. K8sDeployer callers will always go
through the deployer branch.
"""
impl ServiceProcessManager._url_for(service_entry: ServiceEntry) -> str {
    if self.deployer is not None {
        # `deployer` is typed `Any | None` to avoid a circular import with
        # deployer.jac; getattr dispatches to the concrete url_for impl.
        url_fn = self.deployer?.url_for;
        if url_fn is not None {
            result: str = url_fn(service_entry);
            return result;
        }
    }
    return f"http://127.0.0.1:{service_entry.port}";
}

"""Assign a port to a service.

Delegates to `_util.pick_free_port` so our deployer URLs stay consistent
with core's `ensure_sv_service` port strategy and with the plugin's own
hookimpl. Respects a pre-assigned `service_entry.port` if > 0.
"""
impl ServiceProcessManager._assign_port(service_entry: ServiceEntry) -> int {
    if service_entry.port > 0 {
        return service_entry.port;
    }
    import from jac_scale.microservices._util { pick_free_port }
    return pick_free_port(service_entry.name);
}

"""Start a single service subprocess. Returns True on success."""
impl ServiceProcessManager.start_service(name: str) -> bool {
    if name not in self.registry.entries {
        logger.error(f"Service '{name}' not found in registry");
        return False;
    }

    entry = self.registry.entries[name];
    port = self._assign_port(entry);

    import from jac_scale.microservices._util { resolve_jac_binary }
    jac_bin: str = resolve_jac_binary();

    cmd = [jac_bin, "start", entry.file, "--port", str(port), "--no_client"];
    logger.info(f"Starting {name}: {' '.join(cmd)}");

    try {
        import os;
        import from pathlib { Path }
        child_env = dict(os.environ);
        # Prevent child process from re-triggering the orchestrator
        child_env["JAC_SV_SIBLING"] = "1";

        # Inject peer URLs so children resolve sv-imported siblings via
        # sv_client._ensure_available's JAC_SV_{NAME}_URL fast-path
        # instead of falling through to ensure_sv_service and spawning
        # duplicate grandchildren. Peer URLs come from the deployer so
        # K8s siblings will get DNS names automatically.
        for (peer_name, peer_entry) in self.registry.entries.items() {
            if peer_name != name and peer_entry.port > 0 {
                peer_url: str = peer_entry.url or self._url_for(peer_entry);
                child_env[f"JAC_SV_{peer_name.upper()}_URL"] = peer_url;
            }
        }

        # Write service logs to .jac/logs/{name}.log
        log_dir = Path(".jac/logs");
        log_dir.mkdir(parents=True, exist_ok=True);
        log_path = str(log_dir / f"{name}.log");
        log_fd = os.open(log_path, os.O_WRONLY | os.O_CREAT | os.O_APPEND);

        proc = subprocess.Popen(
            cmd, stdout=log_fd, stderr=log_fd, stdin=subprocess.DEVNULL, env=child_env
        );
        os.close(log_fd);
        self.processes[name] = proc;
        entry.pid = proc.pid;
        entry.port = port;
        entry.url = self._url_for(entry);
        entry.status = ServiceStatus.STARTING;
        self._failure_counts[name] = 0;

        # Persist the pid so future `jac scale stop/restart/destroy`
        # invocations (each of which runs in a separate Python process
        # with an empty self.processes) can still signal the service.
        _write_pidfile(name, proc.pid);

        # Register URL in sv_client so sv import calls can resolve it
        import from jaclang.runtimelib { sv_client }
        sv_client.register(name, entry.url);

        logger.info(f"Started {name} (pid={proc.pid}, port={port})");
        return True;
    } except OSError as e {
        logger.error(f"Failed to start {name}: {e}");
        entry.status = ServiceStatus.STOPPED;
        return False;
    }
}

"""Start all registered services.

Two passes:

  1. Pre-assign a port + URL to every service so the peer-URL env-var
     loop in start_service sees a complete picture. Without this, the
     first service would spawn with no peer URLs, and its own sv
     imports would fall through to ensure_sv_service and spawn
     grandchildren.

  2. Spawn each service sequentially and wait for /healthz before the
     next. Serializing startup avoids CREATE TABLE races on the shared
     identity_users sqlite table when every service's SQLAlchemy
     engine calls create_all() simultaneously.
"""
impl ServiceProcessManager.start_all -> None {
    import from jac_scale.microservices._util { wait_for_health }

    for (name, entry) in self.registry.entries.items() {
        if entry.port == 0 {
            entry.port = self._assign_port(entry);
            entry.url = self._url_for(entry);
        }
    }

    for name in self.registry.entries {
        self.start_service(name);
        entry = self.registry.entries[name];
        proc = self.processes.get(name);
        if proc and entry.url {
            ok = wait_for_health(entry.url, lambda : proc.poll() is None, timeout=20.0);
            if not ok {
                logger.warning(f"{name} did not become healthy within 20s; proceeding");
            }
        }
    }
}

"""Stop a single service (graceful SIGTERM, then SIGKILL).

Works in two modes:

  In-process (orchestrator called us): we have the Popen handle in
  `self.processes`, use it directly. subprocess.Popen.terminate() +
  wait() is cleaner than raw os.kill because it reaps the child.

  Cross-process (`jac scale stop <name>` in a separate shell): no
  Popen handle; read the pidfile and os.kill the recorded pid. Clean
  up the pidfile either way so stale state doesn't accumulate.
"""
impl ServiceProcessManager.stop_service(name: str) -> bool {
    import os;
    import time;
    import signal;

    entry = self.registry.entries.get(name);
    proc = self.processes.get(name);

    if proc {
        # In-process: use the Popen handle (reaps the zombie too).
        logger.info(f"Stopping {name} (pid={proc.pid})...");
        proc.terminate();
        try {
            proc.wait(timeout=10);
        } except subprocess.TimeoutExpired {
            logger.warning(f"{name} did not exit gracefully, force killing");
            proc.kill();
            proc.wait();
        }
        del self.processes[name];
    } else {
        # Cross-process: read pidfile and signal by pid.
        pid = _read_pidfile(name);
        if pid is None {
            logger.warning(f"Cannot stop {name}: no pidfile at .jac/run/{name}.pid");
            return False;
        }
        if not _pid_alive(pid) {
            logger.info(
                f"{name} pid {pid} is not running (stale pidfile); cleaning up"
            );
            _remove_pidfile(name);
            if entry {
                entry.status = ServiceStatus.STOPPED;
                entry.pid = None;
            }
            return True;
        }
        logger.info(f"Stopping {name} (pid={pid}) via pidfile...");
        try {
            os.kill(pid, int(signal.SIGTERM));
        } except ProcessLookupError {
            ;  # already dead between the alive check and now
        }
        deadline = time.time() + 10.0;
        while time.time() < deadline and _pid_alive(pid) {
            time.sleep(0.2);
        }
        if _pid_alive(pid) {
            logger.warning(f"{name} did not exit gracefully, force killing");
            try {
                os.kill(pid, int(signal.SIGKILL));
            } except ProcessLookupError {
                ;
            }
        }
    }

    _remove_pidfile(name);

    if entry {
        entry.status = ServiceStatus.STOPPED;
        entry.pid = None;
    }

    # Unregister from sv_client so sv import calls get fresh resolution
    import from jaclang.runtimelib { sv_client }
    sv_client.unregister(name);

    logger.info(f"Stopped {name}");
    return True;
}

"""Stop all running services."""
impl ServiceProcessManager.stop_all -> None {
    names = list(self.processes.keys());
    for name in names {
        self.stop_service(name);
    }
}

"""Restart a service (stop + start)."""
impl ServiceProcessManager.restart_service(name: str) -> bool {
    self.stop_service(name);
    return self.start_service(name);
}

"""Check /health on a single service. Returns True if healthy."""
impl ServiceProcessManager.check_health(name: str) -> bool {
    entry = self.registry.entries.get(name);
    if not entry or not entry.url {
        return False;
    }

    try {
        req = URLRequest(f"{entry.url}/healthz", method="GET");
        resp = urlopen(req, timeout=self._health_check_timeout);
        return getattr(resp, "status", 0) == 200;
    } except URLError {
        return False;
    } except OSError {
        return False;
    }
}

"""Run health checks on all services. Returns per-service results."""
impl ServiceProcessManager.check_all_health -> dict[str, bool] {
    results: dict[str, bool] = {};

    for (name, entry) in self.registry.entries.items() {
        healthy = self.check_health(name);
        results[name] = healthy;

        if healthy {
            entry.status = ServiceStatus.HEALTHY;
            self._failure_counts[name] = 0;
        } else {
            self._failure_counts[name] = self._failure_counts.get(name, 0) + 1;
            if self._failure_counts[name] >= self._max_failures {
                entry.status = ServiceStatus.UNHEALTHY;
                logger.warning(
                    f"{name} is UNHEALTHY ({self._failure_counts[
                        name
                    ]} consecutive failures)"
                );
            }
        }
    }

    return results;
}
