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
    } except OSError {}
    _remove_portfile(name);
}

def _portfile_path(name: str) -> _Path {
    return _Path(".jac/run") / f"{name}.port";
}

def _write_portfile(name: str, port: int) {
    run_dir = _Path(".jac/run");
    run_dir.mkdir(parents=True, exist_ok=True);
    _portfile_path(name).write_text(str(port));
}

def _read_portfile(name: str) -> int | None {
    path = _portfile_path(name);
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

def _remove_portfile(name: str) {
    path = _portfile_path(name);
    try {
        if path.exists() {
            path.unlink();
        }
    } except OSError {}
}

def _log_size(name: str) -> int {
    try {
        return (_Path(".jac/logs") / f"{name}.log").stat().st_size;
    } except OSError {
        return 0;
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

def _owns_group(pid: int) -> bool {
    import os;
    try {
        pgid = os.getpgid(pid);
    } except (ProcessLookupError, OSError) {
        return False;
    }
    return pgid == pid and pgid != os.getpgrp();
}


def _signal_group(pid: int, sig: int) -> None {
    import os;
    if pid <= 0 {
        return;
    }
    if _owns_group(pid) {
        try {
            os.killpg(pid, sig);
            return;
        } except (ProcessLookupError, PermissionError, OSError) {}
    }
    try {
        os.kill(pid, sig);
    } except (ProcessLookupError, OSError) {}
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

impl ServiceProcessManager._ports_in_use -> set[int] {
    taken: set[int] = set();
    for peer in self.registry.entries.values() {
        if peer.port > 0 {
            taken.add(peer.port);
        }
        if peer.page_port > 0 {
            taken.add(peer.page_port);
        }
    }
    return taken;
}

impl ServiceProcessManager._assign_port(service_entry: ServiceEntry) -> int {
    if service_entry.port > 0 {
        return service_entry.port;
    }
    import from jaclang.scale.runtime.context.util { pick_free_port }
    return pick_free_port(service_entry.name, avoid=self._ports_in_use());
}

impl ServiceProcessManager._assign_free_port(service_entry: ServiceEntry) -> int {
    import from jaclang.scale.runtime.context.util { pick_free_port }
    return pick_free_port(f"{service_entry.name}-api", avoid=self._ports_in_use());
}

impl ServiceProcessManager._prepare_ports(service_entry: ServiceEntry) -> None {
    if service_entry.port > 0 {
        return;
    }
    first: int = self._assign_port(service_entry);
    if service_entry.serves_client and self.dev_mode {
        service_entry.page_port = first;
        service_entry.page_url = f"http://127.0.0.1:{first}";
        service_entry.port = self._assign_free_port(service_entry);
    } else {
        service_entry.port = first;
    }
    service_entry.url = self._url_for(service_entry);
}

impl ServiceProcessManager.start_service(name: str) -> bool {
    if name not in self.registry.entries {
        logger.error(f"Service '{name}' not found in registry");
        return False;
    }

    `entry = self.registry.entries[name];
    self._prepare_ports(`entry);
    port: int = `entry.port;

    import from jaclang.scale.runtime.context.util { jac_executable }
    import from jaclang.server.sv_client {
        app_start_args,
        headless_start_args,
        peer_url_env_key
    }
    jac_bin: str = jac_executable();

    if `entry.page_port > 0 {
        cmd = [jac_bin] + app_start_args(`entry.file, `entry.page_port, True, port);
    } elif `entry.serves_client {
        cmd = [jac_bin] + app_start_args(`entry.file, port);
    } else {
        cmd = [jac_bin] + headless_start_args(`entry.file, port);
    }
    logger.info(f"Starting {name}: {' '.join(cmd)}");

    try {
        import os;
        import from pathlib { Path }
        child_env = dict(os.environ);

        child_env["JAC_SV_SIBLING"] = "1";
        child_env["JAC_SV_NAME"] = name;
        for (env_key, env_value) in `entry.env.items() {
            child_env[str(env_key)] = str(env_value);
        }

        for (peer_name, peer_entry) in self.registry.entries.items() {
            if peer_name != name and peer_entry.port > 0 {
                peer_url: str = peer_entry.url or self._url_for(peer_entry);
                child_env[peer_url_env_key(peer_name)] = peer_url;
            }
        }

        log_dir = Path(".jac/logs");
        log_dir.mkdir(parents=True, exist_ok=True);
        log_path = str(log_dir / f"{name}.log");
        log_fd = os.open(log_path, os.O_WRONLY | os.O_CREAT | os.O_APPEND);

        proc = subprocess.Popen(
            cmd,
            stdout=log_fd,
            stderr=log_fd,
            stdin=subprocess.DEVNULL,
            env=child_env,
            start_new_session=True
        );
        os.close(log_fd);
        self.processes[name] = proc;
        self._own_sessions[proc.pid] = True;
        `entry.pid = proc.pid;
        `entry.url = self._url_for(`entry);
        `entry.status = ServiceStatus.STARTING;
        self._failure_counts[name] = 0;

        _write_pidfile(name, proc.pid);
        _write_portfile(name, port);

        import from jaclang.server { sv_client }
        sv_client.register(name, `entry.url);

        logger.info(f"Started {name} (pid={proc.pid}, port={port})");
        return True;
    } except OSError as e {
        logger.error(f"Failed to start {name}: {e}");
        `entry.status = ServiceStatus.STOPPED;
        return False;
    }
}

impl ServiceProcessManager._boot_order -> list[str] {
    lead: list[str] = [];
    rest: list[str] = [];
    for (name, `entry) in self.registry.entries.items() {
        if `entry.serves_client {
            lead.append(name);
        } else {
            rest.append(name);
        }
    }
    return lead + rest;
}

impl ServiceProcessManager._await_lead(name: str) -> None {
    import time;
    import from jaclang.scale.runtime.context.util { wait_for_health }
    `entry = self.registry.entries[name];
    proc = self.processes.get(name);
    if proc is None or not `entry.url {
        return;
    }
    live: subprocess.Popen = proc;
    logger.info(
        f"Waiting for {name} to compile its client before starting the rest of "
        f"the fleet; a module analyzed for another service first reaches the "
        f"client backend with its calls unresolved"
    );
    started: float = time.time();
    spoke: list[float] = [started];

    def _compile_progress -> int {
        marker: int = _log_size(name);
        now: float = time.time();
        if now - spoke[0] >= _LEAD_HEARTBEAT_SECONDS {
            spoke[0] = now;
            logger.info(
                f"  {name} still building its client "
                f"({now - started:.0f}s elapsed, {marker} bytes logged)"
            );
        }
        return marker;
    }
    ok = wait_for_health(
        `entry.url,
        lambda { live.poll() is None; },
        timeout=self.app_boot_timeout,
        progress=_compile_progress
    );
    if ok {
        `entry.status = ServiceStatus.HEALTHY;
        return;
    }
    exit_code = live.poll();
    if exit_code is not None {
        `entry.status = ServiceStatus.STOPPED;
        `entry.pid = None;
        _report_exit(name, exit_code, "during startup");
        return;
    }
    logger.warning(
        f"{name} is still starting after {self.app_boot_timeout:.0f}s; the rest "
        f"of the fleet starts now and its client bundle may be built from a "
        f"cache another service warmed"
    );
}

impl ServiceProcessManager.start_all -> None {
    self._booting = True;
    for (_name, `entry) in self.registry.entries.items() {
        self._prepare_ports(`entry);
    }

    order: list[str] = self._boot_order();
    for name in order {
        self.start_service(name);
        if self.registry.entries[name].serves_client and len(order) > 1 {
            self._await_lead(name);
        }
    }
}

impl ServiceProcessManager.stop_service(name: str) -> bool {
    import os;
    import time;
    import signal;

    `entry = self.registry.entries.get(name);
    proc = self.processes.get(name);

    if proc {
        logger.info(f"Stopping {name} (pid={proc.pid})...");
        own_session = bool(self._own_sessions.pop(proc.pid, False));
        proc.terminate();
        if own_session {
            _signal_group(proc.pid, int(signal.SIGTERM));
        }
        try {
            proc.`wait(timeout=10);
        } except subprocess.TimeoutExpired {
            logger.warning(f"{name} did not exit gracefully, force killing");
            proc.kill();
            if own_session {
                _signal_group(proc.pid, int(signal.SIGKILL));
            }
            proc.`wait();
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
            if `entry {
                `entry.status = ServiceStatus.STOPPED;
                `entry.pid = None;
            }
            return True;
        }
        logger.info(f"Stopping {name} (pid={pid}) via pidfile...");
        try {
            os.kill(pid, int(signal.SIGTERM));
        } except (ProcessLookupError, OSError) {}
        deadline = time.time() + 10.0;
        while time.time() < deadline and _pid_alive(pid) {
            time.sleep(0.2);
        }
        if _pid_alive(pid) {
            logger.warning(f"{name} did not exit gracefully, force killing");
            try {
                os.kill(pid, int(signal.SIGKILL));
            } except (ProcessLookupError, OSError) {}
        }
    }

    _remove_pidfile(name);

    if `entry {
        `entry.status = ServiceStatus.STOPPED;
        `entry.pid = None;
    }

    import from jaclang.server { sv_client }
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
    `entry = self.registry.entries.get(name);
    if not `entry or not `entry.url {
        return False;
    }

    try {
        req = URLRequest(f"{`entry.url}/healthz", method="GET");
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

    for (name, `entry) in self.registry.entries.items() {
        proc = self.processes.get(name);
        exit_code = proc.poll() if proc else None;
        if exit_code is not None {
            if `entry.status != ServiceStatus.STOPPED {
                `entry.status = ServiceStatus.STOPPED;
                `entry.pid = None;
                _report_exit(name, exit_code, "and will not become healthy");
            }
            results[name] = False;
            continue;
        }

        healthy = self.check_health(name);
        results[name] = healthy;

        if healthy {
            `entry.status = ServiceStatus.HEALTHY;
            self._failure_counts[name] = 0;
        } else {
            if self._booting {
                continue;
            }
            self._failure_counts[name] = self._failure_counts.get(name, 0) + 1;
            if self._failure_counts[name] >= self._max_failures {
                if `entry.status != ServiceStatus.UNHEALTHY {
                    logger.warning(
                        f"{name} is UNHEALTHY ({self._failure_counts[
                            name
                        ]} consecutive failures)"
                    );
                }
                `entry.status = ServiceStatus.UNHEALTHY;
            }
        }
    }

    return results;
}


def _health_monitor_loop(pm: any, stop_event: any, interval: float) -> None {
    while not stop_event.is_set() {
        settled: bool = False;
        try {
            results = pm.check_all_health();
            settled = bool(results) and all(results.values());
        } except Exception as e {
            logger.warning(f"health monitor iteration failed: {e}");
        }
        current: float = pm._health_monitor_interval
            if settled
            else min(pm._health_monitor_interval, interval);
        if stop_event.`wait(current) {
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
    self.end_boot();
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


impl ServiceProcessManager.end_boot -> None {
    self._booting = False;
    for name in list(self._failure_counts.keys()) {
        self._failure_counts[name] = 0;
    }
}
