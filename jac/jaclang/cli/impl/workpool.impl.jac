impl WorkPool.postinit -> None {
    self.kids = [];
    self.crashlogs = [];
}

impl WorkPool._should_stop -> bool {
    if self.stopping {
        return True;
    }
    stop_hook = self.should_stop;
    if stop_hook is not None and stop_hook() {
        self.stopping = True;
        return True;
    }
    return False;
}

impl WorkPool._request(idx: int, path: str, crashlog: str) -> dict[(str, any)] {
    request: dict[(str, any)] = {
        "idx": idx,
        "path": path,
        "crashlog": crashlog,
        "isolate": path in (self.isolate or set())
    };
    extra_hook = self.request_extra;
    if extra_hook is not None {
        extra = extra_hook(idx, path);
        if extra {
            request.update(extra);
        }
    }
    return request;
}

impl WorkPool.run_inline -> None {
    import from traceback { format_exception }
    init_hook = self.worker_init;
    if init_hook is not None {
        init_hook();
    }
    dispatch_hook = self.on_dispatch;
    for (idx, path) in enumerate(self.items) {
        if self._should_stop() {
            break;
        }
        request = self._request(idx, path, "");
        request["inline"] = True;
        if dispatch_hook is not None {
            dispatch_hook(idx, path);
        }
        record: dict[(str, any)] = {};
        try {
            record = {"result": self.job(request)};
        } except KeyboardInterrupt {
            raise;
        } except BaseException as exc {
            record = {"error": "".join(format_exception(exc)).rstrip()};
        }
        self.on_record(idx, record);
    }
}

impl WorkPool.run -> None {
    if not self.items {
        return;
    }
    if not pool_available() {
        self.run_inline();
        return;
    }
    slots = max(1, min(self.jobs, len(self.items)));
    for slot in range(slots) {
        self.kids.append(self._spawn(slot));
    }
    try {
        for kid in list(self.kids) {
            self._dispatch(kid);
        }
        self._pump();
    } finally {
        self._shutdown();
    }
}

impl WorkPool._spawn(slot: int) -> dict[(str, any)] {
    import tempfile;
    (dispatch_r, dispatch_w) = os.pipe();
    (result_r, result_w) = os.pipe();
    pid = os.fork();
    if pid == 0 {
        try {
            os.close(dispatch_w);
            os.close(result_r);
            for other in self.kids {
                if not other["alive"] {
                    continue;
                }
                try {
                    os.close(other["dispatch_fd"]);
                } except OSError {}
                try {
                    os.close(other["result_fd"]);
                } except OSError {}
            }
            self._worker_loop(dispatch_r, result_w);
            exit_hook = self.worker_exit;
            if exit_hook is not None {
                exit_hook();
            }
        } except BaseException {}
        os._exit(0);
    }
    os.close(dispatch_r);
    os.close(result_w);
    (log_fd, log_path) = tempfile.mkstemp(prefix=self.crash_prefix);
    os.close(log_fd);
    self.crashlogs.append(log_path);
    return {
        "pid": pid,
        "slot": slot,
        "dispatch_fd": dispatch_w,
        "result_fd": result_r,
        "buf": b"",
        "inflight": None,
        "alive": True,
        "crashlog": log_path
    };
}

impl WorkPool._worker_loop(dispatch_fd: int, result_fd: int) -> None {
    import json;
    import from traceback { format_exception }
    init_hook = self.worker_init;
    if init_hook is not None {
        init_hook();
    }
    retire_hook = self.retire;
    served = 0;
    reader = os.fdopen(dispatch_fd, "r", encoding="utf-8");
    while True {
        line = reader.readline();
        if not line {
            break;
        }
        text = line.strip();
        if not text or (text == "q") {
            break;
        }
        try {
            request = json.loads(text);
        } except Exception {
            break;
        }
        record: dict[(str, any)] = {};
        try {
            record = {"result": self.job(request)};
        } except BaseException as exc {
            record = {"error": "".join(format_exception(exc)).rstrip()};
        }
        served += 1;
        rss = worker_rss_mb();
        retire_now = bool(request.get("isolate"));
        if not retire_now and retire_hook is not None {
            try {
                retire_now = bool(retire_hook(served, rss));
            } except Exception {
                retire_now = False;
            }
        }
        record["idx"] = request["idx"];
        record["retire"] = retire_now;
        record["rss"] = rss;
        record["served"] = served;
        payload = "";
        try {
            payload = json.dumps(record, `default=str);
        } except Exception as exc {
            payload = json.dumps(
                {
                    "idx": request["idx"],
                    "error": "record is not JSON-serializable: " + str(exc),
                    "retire": retire_now,
                    "rss": rss,
                    "served": served
                }
            );
        }
        try {
            os.write(result_fd, (payload + "\n").encode("utf-8"));
        } except OSError {
            break;
        }
        if retire_now {
            break;
        }
    }
}

impl WorkPool._dispatch(kid: dict[(str, any)]) -> bool {
    import json;
    if self._should_stop() or (self.cursor >= len(self.items)) {
        return False;
    }
    idx = self.cursor;
    self.cursor += 1;
    path = self.items[idx];
    kid["inflight"] = idx;
    payload = json.dumps(self._request(idx, path, str(kid["crashlog"])), `default=str);
    try {
        os.write(kid["dispatch_fd"], (payload + "\n").encode("utf-8"));
    } except OSError {
        kid["inflight"] = None;
        return False;
    }
    dispatch_hook = self.on_dispatch;
    if dispatch_hook is not None {
        dispatch_hook(idx, path);
    }
    return True;
}

impl WorkPool._log_footprint(
    kid: dict[(str, any)], record: dict[(str, any)], done: any
) -> None {
    import sys;
    if not self.rss_log_env or not os.environ.get(self.rss_log_env, "") {
        return;
    }
    rss = record.get("rss");
    if rss is None {
        return;
    }
    name = os.path.basename(self.items[done]) if isinstance(done, int) else "?";
    sys.stderr.write(
        f"[rss] slot={kid['slot']} served={record.get('served', 0)} "
        f"rss={rss}MB{' retiring' if record.get('retire') else ''} {name}\n"
    );
    sys.stderr.flush();
}

impl WorkPool._handle_record(kid: dict[(str, any)], line: str) -> None {
    import json;
    text = line.strip();
    if not text {
        return;
    }
    try {
        record = json.loads(text);
    } except Exception {
        return;
    }
    done = kid["inflight"];
    kid["inflight"] = None;
    self._log_footprint(kid, record, done);
    if done is not None {
        self.on_record(done, record);
    }
    if record.get("retire") {
        kid["retired"] = True;
        if not self._should_stop() and (self.cursor < len(self.items)) {
            replacement = self._spawn(kid["slot"]);
            self.kids.append(replacement);
            self._dispatch(replacement);
        }
        return;
    }
    self._dispatch(kid);
}

impl WorkPool._reap(kid: dict[(str, any)]) -> None {
    if not kid["alive"] {
        return;
    }
    kid["alive"] = False;
    try {
        os.close(kid["result_fd"]);
    } except OSError {}
    try {
        os.close(kid["dispatch_fd"]);
    } except OSError {}
    status = 0;
    try {
        (_, status) = os.waitpid(kid["pid"], 0);
    } except OSError {
        status = 0;
    }
    idx = kid["inflight"];
    if idx is not None {
        kid["inflight"] = None;
        detail = f"worker exited while running this item (wait status {status})";
        spilled = "";
        try {
            with open(kid["crashlog"], "rb") as f {
                spilled = f.read().decode("utf-8", "replace").strip();
            }
        } except Exception {
            spilled = "";
        }
        if spilled {
            detail += "\n--- output captured before the worker died ---\n" + spilled;
        }
        self.on_record(idx, {"crash": detail});
    }
    if (
        not kid.get("retired")
        and not self._should_stop()
        and (self.cursor < len(self.items))
    ) {
        replacement = self._spawn(kid["slot"]);
        self.kids.append(replacement);
        self._dispatch(replacement);
    }
}

impl WorkPool._pump -> None {
    import select;
    while True {
        self.kids = [
            k
            for k in self.kids
            if k["alive"]
        ];
        if not self.kids {
            break;
        }
        busy = [
            k
            for k in self.kids
            if (k["inflight"] is not None) or k.get("retired")
        ];
        if not busy {
            break;
        }
        fds = [k["result_fd"] for k in busy];
        try {
            (ready, _, _) = select.select(fds, [], []);
        } except OSError {
            break;
        }
        for fd in ready {
            owners = [
                k
                for k in busy
                if k["result_fd"] == fd
            ];
            if not owners {
                continue;
            }
            kid = owners[0];
            if not kid["alive"] {
                continue;
            }
            chunk = b"";
            try {
                chunk = os.read(fd, 65536);
            } except OSError {
                chunk = b"";
            }
            if not chunk {
                self._reap(kid);
                continue;
            }
            buf: bytes = bytes(kid["buf"]) + chunk;
            while b"\n" in buf {
                (line, _, rest) = buf.partition(b"\n");
                buf = rest;
                self._handle_record(kid, line.decode("utf-8", "replace"));
            }
            kid["buf"] = buf;
        }
    }
}

impl WorkPool._shutdown -> None {
    import signal;
    import time;
    for kid in self.kids {
        if not kid["alive"] {
            continue;
        }
        try {
            os.write(kid["dispatch_fd"], b"q\n");
        } except OSError {}
    }
    for kid in self.kids {
        if not kid["alive"] {
            continue;
        }
        kid["alive"] = False;
        for fd_key in ("dispatch_fd", "result_fd") {
            try {
                os.close(kid[fd_key]);
            } except OSError {}
        }
        reaped = False;
        deadline = time.monotonic() + 2.0;
        while time.monotonic() < deadline {
            done = 0;
            try {
                (done, _) = os.waitpid(kid["pid"], os.WNOHANG);
            } except OSError {
                reaped = True;
            }
            if reaped or done {
                reaped = True;
                break;
            }
            time.sleep(0.02);
        }
        if not reaped {
            try {
                os.kill(int(kid["pid"]), int(signal.SIGKILL));
            } except OSError {}
            try {
                os.waitpid(kid["pid"], 0);
            } except OSError {}
        }
    }
    for path in self.crashlogs {
        try {
            os.unlink(path);
        } except OSError {}
    }
    self.crashlogs = [];
}

impl pool_available -> bool {
    return hasattr(os, "fork");
}

impl worker_rss_mb -> int {
    import resource;
    import sys;
    # Retirement depends on memory still held after the job. A lifetime peak
    # cannot fall after a compilation releases its graph or native buffers.
    if sys.platform == "linux" {
        try {
            with open("/proc/self/statm") as status {
                resident_pages = int(status.read().split()[1]);
            }
            return resident_pages * os.sysconf("SC_PAGE_SIZE") // (1024 * 1024);
        } except (OSError, ValueError, IndexError) {}
    }
    peak = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss;
    return int(peak // (1024 * 1024))
        if sys.platform == "darwin"
        else int(peak // 1024);
}

impl should_retire(served: int, recycle: int, rss_mb: int, rss_cap: int) -> bool {
    if recycle > 0 and served >= recycle {
        return True;
    }
    return rss_cap > 0 and rss_mb >= rss_cap;
}

impl maybe_malloc_trim -> None {
    try {
        import ctypes;
        ctypes.CDLL("libc.so.6").malloc_trim(0);
    } except (ImportError, OSError, AttributeError, ValueError) {}
}

impl env_int(name: str, fallback: int) -> int {
    raw = os.environ.get(name, "");
    if not raw.strip() {
        return fallback;
    }
    try {
        return int(raw.strip());
    } except ValueError {
        return fallback;
    }
}

impl default_jobs(worker_bytes: int = 0, avail_bytes: int = 0) -> int {
    cpus = os.cpu_count() or 1;
    avail = int(avail_bytes or 0);
    if not avail {
        try {
            with open("/proc/meminfo", encoding="utf-8") as f {
                for line in f {
                    if line.startswith("MemAvailable:") {
                        avail = int(line.split()[1]) * 1024;
                        break;
                    }
                }
            }
        } except Exception {
            avail = 0;
        }
    }
    if not avail {
        try {
            avail = os.sysconf("SC_PHYS_PAGES") * os.sysconf("SC_PAGE_SIZE");
        } except Exception {
            avail = 0;
        }
    }

    per_worker = max(WORKER_MEM_BYTES, int(worker_bytes or 0));
    cap = cpus;
    if avail {
        cap = max(1, int((avail * MEM_HEADROOM) // per_worker));
    }
    return max(1, min(cpus, cap, MAX_AUTO_JOBS));
}

impl jobs_setting(
    command: str, requested: (str | int | None) = None, dev: any = None
) -> str {
    if requested is not None and str(requested).strip() != "" {
        return str(requested).strip();
    }
    for env_var in ("JAC_" + command.upper() + "_JOBS", "JAC_JOBS") {
        raw = os.environ.get(env_var, "");
        if raw.strip() {
            return raw.strip();
        }
    }
    if dev is not None {
        own_setting = str(getattr(dev, command + "_jobs", "") or "").strip();
        if own_setting {
            return own_setting;
        }
        shared = str(getattr(dev, "jobs", "") or "").strip();
        if shared {
            return shared;
        }
    }
    return "";
}

impl resolve_jobs(
    requested: (str | int | None) = None,
    env_var: str = "JAC_JOBS",
    worker_bytes: int = 0
) -> int {
    raw: (str | int | None) = requested;
    if (raw is None) or (str(raw).strip() == "") {
        raw = os.environ.get(env_var, "");
    }
    if (raw is None) or (str(raw).strip() == "") {
        return default_jobs(worker_bytes);
    }
    if isinstance(raw, int) {
        return max(1, raw);
    }
    text = str(raw).strip().lower();
    if text == "auto" {
        return default_jobs(worker_bytes);
    }
    try {
        return max(1, int(text));
    } except ValueError {
        return default_jobs(worker_bytes);
    }
}

impl forced_serial(requested: (str | int | None) = None) -> bool {
    if requested is None {
        return False;
    }
    return str(requested).strip() == "0";
}
