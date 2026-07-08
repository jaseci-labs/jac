import from pathlib { Path as _Path }

def _pidfile_path(name: str) -> _Path {
    return _Path(".jac/run") / f"{name}.pid";
}

def _write_pidfile(name: str, pid: int) {
    run_dir = _Path(".jac/run");
    run_dir.mkdir(parents=True, exist_ok=True);
    _pidfile_path(name).write_text(str(pid));
}

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

def _log_tail(name: str, lines: int = 8) -> str {
    try {
        content = (_Path(".jac/logs") / f"{name}.log").read_text(
            encoding="utf-8", errors="replace"
        );
        return "\n".join(content.strip().splitlines()[-lines:]);
    } except OSError {
        return "";
    }
}

def _report_exit(name: str, exit_code: int, context: str) {
    tail = _log_tail(name);
    suffix = f"; last log lines:\n{tail}" if tail else "";
    logger.error(f"{name} exited with code {exit_code} {context}{suffix}");
}

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

impl ServiceProcessManager._url_for(service_entry: ServiceEntry) -> str {
    if self.deployer is not None {
        url_fn = self.deployer?.url_for;
        if url_fn is not None {
            result: str = url_fn(service_entry);
            return result;
        }
    }
    return f"http://127.0.0.1:{service_entry.port}";
}

impl ServiceProcessManager._assign_port(service_entry: ServiceEntry) -> int {
    if service_entry.port > 0 {
        return service_entry.port;
    }
    import from jaclang.scale.runtime.context.util { pick_free_port }
    return pick_free_port(service_entry.name);
}

impl ServiceProcessManager.start_service(name: str) -> bool {
    if name not in self.registry.entries {
        logger.error(f"Service '{name}' not found in registry");
        return False;
    }

    entry = self.registry.entries[name];
    port = self._assign_port(entry);

    import from jaclang.scale.runtime.context.util { jac_executable }
    jac_bin: str = jac_executable();

    cmd = [jac_bin, "start", entry.file, "--port", str(port), "--no_client"];
    logger.info(f"Starting {name}: {' '.join(cmd)}");

    try {
        import os;
        import from pathlib { Path }
        child_env = dict(os.environ);

        child_env["JAC_SV_SIBLING"] = "1";

        for (peer_name, peer_entry) in self.registry.entries.items() {
            if peer_name != name and peer_entry.port > 0 {
                peer_url: str = peer_entry.url or self._url_for(peer_entry);
                child_env[f"JAC_SV_{peer_name.upper()}_URL"] = peer_url;
            }
        }

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

        _write_pidfile(name, proc.pid);

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

impl ServiceProcessManager.start_all -> None {
    import from jaclang.scale.runtime.context.util { wait_for_health }

    for (name, entry) in self.registry.entries.items() {
        if entry.port == 0 {
            entry.port = self._assign_port(entry);
            entry.url = self._url_for(entry);
        }
    }

    timeout: float = self._boot_health_timeout;
    for name in self.registry.entries {
        self.start_service(name);
        entry = self.registry.entries[name];
        proc = self.processes.get(name);
        if proc and entry.url {
            ok = wait_for_health(
                entry.url, lambda : proc.poll() is None, timeout=timeout
            );
            if not ok {
                exit_code = proc.poll();
                if exit_code is not None {
                    entry.status = ServiceStatus.STOPPED;
                    entry.pid = None;
                    _report_exit(name, exit_code, "during startup");
                } else {
                    logger.warning(
                        f"{name} did not become healthy within {timeout:.0f}s; "
                        "proceeding"
                    );
                }
            }
        }
    }
}

impl ServiceProcessManager.stop_service(name: str) -> bool {
    import os;
    import time;
    import signal;

    entry = self.registry.entries.get(name);
    proc = self.processes.get(name);

    if proc {
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
            ;
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

    import from jaclang.runtimelib { sv_client }
    sv_client.unregister(name);

    logger.info(f"Stopped {name}");
    return True;
}

impl ServiceProcessManager.stop_all -> None {
    self.stop_health_monitor();
    names = list(self.processes.keys());
    for name in names {
        self.stop_service(name);
    }
}

impl ServiceProcessManager.restart_service(name: str) -> bool {
    self.stop_service(name);
    return self.start_service(name);
}

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

impl ServiceProcessManager.check_all_health -> dict[str, bool] {
    results: dict[str, bool] = {};

    for (name, entry) in self.registry.entries.items() {
        proc = self.processes.get(name);
        exit_code = proc.poll() if proc else None;
        if exit_code is not None {
            if entry.status != ServiceStatus.STOPPED {
                entry.status = ServiceStatus.STOPPED;
                entry.pid = None;
                _report_exit(name, exit_code, "and will not become healthy");
            }
            results[name] = False;
            continue;
        }

        healthy = self.check_health(name);
        results[name] = healthy;

        if healthy {
            entry.status = ServiceStatus.HEALTHY;
            self._failure_counts[name] = 0;
        } else {
            self._failure_counts[name] = self._failure_counts.get(name, 0) + 1;
            if self._failure_counts[name] >= self._max_failures {
                if entry.status != ServiceStatus.UNHEALTHY {
                    logger.warning(
                        f"{name} is UNHEALTHY ({self._failure_counts[
                            name
                        ]} consecutive failures)"
                    );
                }
                entry.status = ServiceStatus.UNHEALTHY;
            }
        }
    }

    return results;
}


def _health_monitor_loop(pm: any, stop_event: any, interval: float) -> None {
    while not stop_event.is_set() {
        try {
            pm.check_all_health();
        } except Exception as e {
            logger.warning(f"health monitor iteration failed: {e}");
        }
        if stop_event.wait(interval) {
            return;
        }
    }
}


impl ServiceProcessManager.start_health_monitor(interval: float | None = None) -> None {
    if (
        self._health_monitor_thread is not None
        and self._health_monitor_thread.is_alive()
    ) {
        return;
    }
    poll_interval: float = (
        interval if interval is not None else self._health_monitor_interval
    );
    self._health_monitor_stop = threading.Event();
    self._health_monitor_thread = threading.Thread(
        target=_health_monitor_loop,
        args=(self, self._health_monitor_stop, poll_interval),
        daemon=True,
        name="jac-scale-health-monitor"
    );
    self._health_monitor_thread.start();
    logger.info(f"Health monitor started (interval={poll_interval}s)");
}


impl ServiceProcessManager.stop_health_monitor -> None {
    if self._health_monitor_stop is not None {
        self._health_monitor_stop.set();
    }
    if self._health_monitor_thread is not None {
        self._health_monitor_thread.join(timeout=2);
    }
    self._health_monitor_thread = None;
    self._health_monitor_stop = None;
}
