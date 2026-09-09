import logging;
import mmap;
import os;
import random;
import select;
import signal;
import struct;
import sys;
import tempfile;
import time;
import from jaclang.server.net { PORT_RETRY_LIMIT, bind_listener }
import from jaclang.server.serving.server { EXIT_OK, EXIT_RECYCLE }
import from jaclang.server.settings { ServeSettings }

glob logger: logging.Logger = logging.getLogger(__name__),
     EXIT_BOOT_FAILED: int = 4,
     POLL_SECONDS: float = 0.25,
     BOOT_FAILURE_LIMIT: int = 3,
     RESTART_BACKOFF_CAP: float = 30.0,
     METRICS_DIR_ENV: str = 'PROMETHEUS_MULTIPROC_DIR';


obj WorkerHandle {
    has index: int,
        listener: any,
        request_budget: int = 0,
        heartbeat: (Callable[[], None] | None) = None,
        notify_ready: (Callable[[], None] | None) = None;
}


obj WorkerSlot {
    has index: int,
        cell: int,
        pid: int = 0,
        ready_fd: int = -1,
        ready: bool = False,
        started_at: float = 0.0,
        restarts: int = 0,
        boot_failures: int = 0,
        retiring: bool = False;
}


obj WorkerSupervisor {
    has settings: ServeSettings,
        worker_main: Callable[[WorkerHandle], int],
        on_ready: (Callable[[int], None] | None) = None,
        listener: any = None,
        bound_port: int = 0,
        slots: list[WorkerSlot] = [],
        _beats: any = None,
        _cells: int = 0,
        _stopping: bool = False,
        _reload_requested: bool = False,
        _metrics_dir: str = '';

    def _write_beat(cell: int) {
        self._beats[cell * 8:cell * 8 + 8] = struct.pack('d', time.monotonic());
    }

    def _clear_beat(cell: int) {
        self._beats[cell * 8:cell * 8 + 8] = struct.pack('d', 0.0);
    }

    def _read_beat(cell: int) -> float {
        return struct.unpack('d', self._beats[cell * 8:cell * 8 + 8])[0];
    }

    def _free_cell -> int {
        used = {s.cell for s in self.slots};
        for cell in range(self._cells) {
            if cell not in used {
                return cell;
            }
        }
        raise RuntimeError('no free heartbeat cell');
    }

    def _install_signal_handlers {
        def _stop(signum: int, frame: any) {
            self._stopping = True;
        }
        def _reload(signum: int, frame: any) {
            self._reload_requested = True;
        }
        signal.signal(int(signal.SIGTERM), _stop);
        signal.signal(int(signal.SIGINT), _stop);
        hup = signal?.SIGHUP;
        if hup is not None {
            signal.signal(int(hup), _reload);
        }
    }

    def _request_budget -> int {
        base = self.settings.workers.max_requests;
        if base <= 0 {
            return 0;
        }
        return base
            + random.randint(0, max(0, self.settings.workers.max_requests_jitter));
    }

    def _spawn(slot: WorkerSlot) {
        budget = self._request_budget();
        self._clear_beat(slot.cell);
        (read_fd, write_fd) = os.pipe();
        pid = os.fork();
        if pid == 0 {
            os.close(read_fd);
            code = EXIT_BOOT_FAILED;
            try {
                hup = signal?.SIGHUP;
                if hup is not None {
                    signal.signal(int(hup), signal.SIG_IGN);
                }
                signal.signal(int(signal.SIGTERM), signal.SIG_DFL);
                signal.signal(int(signal.SIGINT), signal.SIG_DFL);
                import from jaclang.runtime.runtime { JacRuntime }
                JacRuntime.after_fork_in_child();
                cell = slot.cell;
                def _beat {
                    self._write_beat(cell);
                }
                def _ready {
                    try {
                        os.write(write_fd, b'1');
                        os.close(write_fd);
                    } except OSError {}
                }
                main_fn: any = self.worker_main;
                code = int(
                    main_fn(
                        WorkerHandle(
                            index=slot.index,
                            listener=self.listener,
                            request_budget=budget,
                            heartbeat=_beat,
                            notify_ready=_ready
                        )
                    )
                        or EXIT_OK
                );
            } except SystemExit as se {
                code = int(se.code) if isinstance(se.code, int) else 1;
            } except BaseException {
                logger.exception(f"worker {slot.index} crashed");
                code = EXIT_BOOT_FAILED;
            } finally {
                try {
                    sys.stdout.flush();
                    sys.stderr.flush();
                } except Exception {}
                os._exit(code);
            }
        }
        os.close(write_fd);
        slot.pid = pid;
        slot.ready_fd = read_fd;
        slot.ready = False;
        slot.started_at = time.monotonic();
        slot.retiring = False;
        logger.info(f"worker {slot.index} started (pid {pid})");
    }

    def _close_ready_fd(slot: WorkerSlot) {
        if slot.ready_fd >= 0 {
            try {
                os.close(slot.ready_fd);
            } except OSError {}
            slot.ready_fd = -1;
        }
    }

    def _poll_ready(slot: WorkerSlot, timeout: float = 0.0) -> bool {
        if slot.ready or slot.ready_fd < 0 {
            return slot.ready;
        }
        (readable, _w, _x) = select.select([slot.ready_fd], [], [], timeout);
        if not readable {
            return False;
        }
        try {
            got = os.read(slot.ready_fd, 1);
        } except OSError {
            got = b'';
        }
        self._close_ready_fd(slot);
        slot.ready = bool(got);
        if slot.ready {
            slot.boot_failures = 0;
        }
        return slot.ready;
    }

    def _terminate(slot: WorkerSlot, sig: int) {
        if slot.pid <= 0 {
            return;
        }
        try {
            os.kill(slot.pid, sig);
        } except ProcessLookupError {}
    }

    def _reap -> list[tuple[WorkerSlot, int]] {
        exited: list[tuple[WorkerSlot, int]] = [];
        while True {
            try {
                (pid, status) = os.waitpid(-1, os.WNOHANG);
            } except ChildProcessError {
                break;
            }
            if pid == 0 {
                break;
            }
            code = os.waitstatus_to_exitcode(status);
            for slot in self.slots {
                if slot.pid == pid {
                    slot.pid = 0;
                    self._close_ready_fd(slot);
                    exited.append((slot, code));
                }
            }
        }
        return exited;
    }

    def _handle_exit(slot: WorkerSlot, code: int) {
        if self._stopping or slot.retiring {
            logger.info(f"worker {slot.index} exited ({code})");
            return;
        }
        if code == EXIT_RECYCLE {
            logger.info(f"worker {slot.index} recycled; respawning");
            self._spawn(slot);
            return;
        }
        if not slot.ready or code == EXIT_BOOT_FAILED {
            slot.boot_failures += 1;
            if slot.boot_failures >= BOOT_FAILURE_LIMIT {
                logger.error(
                    f"worker {slot.index} failed to boot {slot.boot_failures} times; "
                    "stopping the fleet"
                );
                self._stopping = True;
                return;
            }
        }
        slot.restarts += 1;
        delay = min(RESTART_BACKOFF_CAP, 2.0 ** min(slot.restarts, 5) - 1.0);
        logger.warning(
            f"worker {slot.index} exited with {code}; respawning in {delay:.1f}s"
        );
        if delay > 0 {
            time.sleep(delay);
        }
        self._spawn(slot);
    }

    def _check_health {
        now = time.monotonic();
        boot_budget = self.settings.workers.boot_timeout;
        hang_budget = self.settings.workers.hang_timeout;
        for slot in self.slots {
            if slot.pid <= 0 or slot.retiring {
                continue;
            }
            if not self._poll_ready(slot) {
                if boot_budget > 0 and now - slot.started_at > boot_budget {
                    logger.error(
                        f"worker {slot.index} (pid {slot.pid}) never became ready "
                        f"within {boot_budget:.0f}s; killing"
                    );
                    self._terminate(slot, int(signal.SIGKILL));
                }
                continue;
            }
            beat = self._read_beat(slot.cell);
            if hang_budget > 0 and beat > 0.0 and now - beat > hang_budget {
                logger.error(
                    f"worker {slot.index} (pid {slot.pid}) stopped heartbeating for "
                    f"{now - beat:.0f}s; killing"
                );
                self._terminate(slot, int(signal.SIGKILL));
            }
        }
    }

    def _wait_ready(slot: WorkerSlot, budget: float) -> bool {
        deadline = time.monotonic() + max(1.0, budget);
        while time.monotonic() < deadline {
            for (done, code) in self._reap() {
                if done is slot {
                    return False;
                }
                self._handle_exit(done, code);
            }
            if self._poll_ready(slot, POLL_SECONDS) {
                return True;
            }
        }
        return False;
    }

    def _await_exit(slot: WorkerSlot, budget: float) {
        deadline = time.monotonic() + budget;
        while slot.pid > 0 and time.monotonic() < deadline {
            for (done, code) in self._reap() {
                if done is not slot {
                    self._handle_exit(done, code);
                }
            }
            time.sleep(POLL_SECONDS);
        }
        if slot.pid > 0 {
            logger.warning(
                f"worker {slot.index} (pid {slot.pid}) ignored SIGTERM; killing"
            );
            self._terminate(slot, int(signal.SIGKILL));
            deadline = time.monotonic() + 5.0;
            while slot.pid > 0 and time.monotonic() < deadline {
                self._reap();
                time.sleep(0.05);
            }
        }
    }

    def _rolling_restart {
        self._reload_requested = False;
        logger.info("SIGHUP: rolling restart");
        drain_budget = self.settings.timeouts.drain
            + self.settings.timeouts.close
            + 2.0;
        for position in range(len(self.slots)) {
            if self._stopping {
                return;
            }
            old = self.slots[position];
            fresh = WorkerSlot(
                index=old.index, cell=self._free_cell(), restarts=old.restarts
            );
            self.slots.append(fresh);
            self._spawn(fresh);
            if not self._wait_ready(fresh, self.settings.workers.boot_timeout) {
                logger.error(
                    f"replacement for worker {old.index} did not become ready; "
                    "keeping the old worker"
                );
                fresh.retiring = True;
                self._terminate(fresh, int(signal.SIGKILL));
                self._await_exit(fresh, 5.0);
                self.slots.remove(fresh);
                continue;
            }
            old.retiring = True;
            self._terminate(old, int(signal.SIGTERM));
            self._await_exit(old, drain_budget);
            self.slots.remove(old);
            self.slots.remove(fresh);
            self.slots.insert(position, fresh);
        }
    }

    def _shutdown_fleet {
        logger.info("stopping workers");
        for slot in self.slots {
            self._terminate(slot, int(signal.SIGTERM));
        }
        deadline = time.monotonic()
            + self.settings.timeouts.drain
            + self.settings.timeouts.close
            + 2.0;
        while any(s.pid > 0 for s in self.slots) and time.monotonic() < deadline {
            self._reap();
            time.sleep(POLL_SECONDS);
        }
        for slot in self.slots {
            if slot.pid > 0 {
                logger.warning(
                    f"worker {slot.index} (pid {slot.pid}) did not exit; killing"
                );
                self._terminate(slot, int(signal.SIGKILL));
            }
        }
        while any(s.pid > 0 for s in self.slots) {
            self._reap();
            time.sleep(0.05);
        }
    }

    def run(port_retries: int = PORT_RETRY_LIMIT) -> int {
        count = max(1, self.settings.workers.count);
        self.listener = bind_listener(
            self.settings.host,
            self.settings.port,
            backlog=self.settings.limits.backlog,
            port_retries=port_retries
        );
        self.bound_port = self.listener.getsockname()[1];
        self._cells = count * 2;
        self._beats = mmap.mmap(-1, 8 * self._cells);
        if not os.environ.get(METRICS_DIR_ENV) {
            self._metrics_dir = tempfile.mkdtemp(prefix='jac-metrics-');
            os.environ[METRICS_DIR_ENV] = self._metrics_dir;
        }
        self._install_signal_handlers();
        self.slots = [WorkerSlot(index=i, cell=i) for i in range(count)];
        for slot in self.slots {
            self._spawn(slot);
        }
        logger.info(
            f"supervising {count} worker(s) on {self.settings.host}:{self.bound_port} "
            f"({self.settings.workers.threads} threads each)"
        );
        if self.on_ready is not None {
            self.on_ready(self.bound_port);
        }
        try {
            while not self._stopping {
                for (slot, code) in self._reap() {
                    self._handle_exit(slot, code);
                }
                if self._stopping {
                    break;
                }
                if self._reload_requested {
                    self._rolling_restart();
                }
                self._check_health();
                time.sleep(POLL_SECONDS);
            }
        } finally {
            self._shutdown_fleet();
            for slot in self.slots {
                self._close_ready_fd(slot);
            }
            try {
                self.listener.close();
            } except Exception {}
            if self._metrics_dir {
                import shutil;
                shutil.rmtree(self._metrics_dir, ignore_errors=True);
                os.environ.pop(METRICS_DIR_ENV, None);
            }
        }
        if any(s.boot_failures >= BOOT_FAILURE_LIMIT for s in self.slots) {
            return 1;
        }
        return EXIT_OK;
    }
}
