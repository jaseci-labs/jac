impl JobRunner.postinit -> None {
    if not self.owner {
        self.owner = f"{socket.gethostname()}-{os.getpid()}-{uuid.uuid4().hex[:6]}";
    }
    self._stop = threading.Event();
    self._maint_stop = threading.Event();
    self._maint_thread = None;
    self._wake = {spec.name: threading.Event() for spec in self.queues};
    self._slots = {
        spec.name: threading.BoundedSemaphore(max(1, spec.concurrency))
        for spec in self.queues
    };
    self._pools = {};
    self._threads = [];
    shortest = min([spec.lease_s for spec in self.queues] or [DEFAULT_LEASE_S]);
    self._maintain_s = max(0.05, min(MAINTAIN_CAP_S, shortest / 3.0));
    self._listening = False;
}


impl JobRunner.start -> None {
    self._stop.clear();
    self._maint_stop.clear();
    try {
        self.store.store.listen(JOBS_CHANNEL, self.wake);
        self._listening = True;
    } except Exception as e {
        logger.warning(
            f"job runner could not listen on {JOBS_CHANNEL} ({e}); "
            f"new jobs are picked up by polling every {self.poll_s}s"
        );
    }
    for spec in self.queues {
        self._pools[spec.name] = ThreadPoolExecutor(
            max_workers=max(1, spec.concurrency),
            thread_name_prefix=f"jac-job-{spec.name}"
        );
        t = threading.Thread(
            target=self._dispatch_loop,
            args=(spec, ),
            daemon=True,
            name=f"jac-jobs-{spec.name}"
        );
        self._threads.append(t);
        t.start();
    }
    m = threading.Thread(
        target=self._maintain_loop, daemon=True, name="jac-jobs-maint"
    );
    self._maint_thread = m;
    m.start();
    logger.info(
        "job runner %s serving %s",
        self.owner,
        ", ".join(f"{s.name} (x{s.concurrency})" for s in self.queues)
    );
}


impl JobRunner.stop(timeout_s: float = 10.0) -> None {
    self._stop.set();
    for ev in self._wake.values() {
        ev.set();
    }
    for t in self._threads {
        t.join(timeout=timeout_s);
    }
    self._threads = [];
    for pool in self._pools.values() {
        pool.shutdown(`wait=True, cancel_futures=True);
    }
    self._pools = {};
    self._maint_stop.set();
    if self._maint_thread is not None {
        self._maint_thread.join(timeout=timeout_s);
        self._maint_thread = None;
    }
    if self._listening {
        try {
            self.store.store.unlisten(JOBS_CHANNEL);
        } except Exception as e {
            logger.debug(f"job runner unlisten failed: {e}");
        }
        self._listening = False;
    }
}


impl JobRunner.wake(queue: str = "") -> None {
    ev = self._wake.get(queue);
    if ev is not None {
        ev.set();
        return;
    }
    for other in self._wake.values() {
        other.set();
    }
}


impl JobRunner.run_once(queue: str) -> bool {
    spec = self._spec(queue);
    job = self.store.claim(spec.name, self.owner, spec.lease_s);
    if job is None {
        return False;
    }
    self._run_claimed(job);
    return True;
}


impl JobRunner.maintain -> None {
    for spec in self.queues {
        self.store.heartbeat(spec.name, self.owner, spec.lease_s);
    }
    reaped = self.store.reap();
    if reaped {
        logger.warning(
            f"re-queued {len(reaped)} job(s) whose runner stopped holding its lease"
        );
        self.wake();
    }
    if self.retention_s > 0 {
        self.store.prune(self.retention_s);
    }
    if self.on_counts is not None {
        self.on_counts(self.store.counts());
    }
}


impl JobRunner._spec(queue: str) -> QueueSpec {
    for spec in self.queues {
        if spec.name == queue {
            return spec;
        }
    }
    raise KeyError(f"job runner does not serve queue '{queue}'");
}


impl JobRunner._run_claimed(job: JobInfo) -> None {
    try {
        self.execute(job);
    } except JobTargetMissing as e {
        self.store.fail(job, self.owner, str(e), permanent=True);
        logger.error(f"job {job.id} ({job.target}) is dead: {e}");
        return;
    } except Exception as e {
        status = self.store.fail(job, self.owner, f"{type(e).__name__}: {e}");
        logger.warning(
            f"job {job.id} ({job.target}) attempt {job.attempts}/{job.max_attempts} "
            f"failed: {type(e).__name__}: {e}; now {status or 'no longer held'}"
        );
        return;
    }
    if not self.store.complete(job.id, self.owner) {
        logger.warning(
            f"job {job.id} ({job.target}) finished after its lease was lost; "
            "another runner may run it again"
        );
    }
}


impl JobRunner._dispatch_loop(spec: QueueSpec) -> None {
    slots = self._slots[spec.name];
    wake = self._wake[spec.name];
    pool = self._pools[spec.name];
    while not self._stop.is_set() {
        if not slots.acquire(timeout=self.poll_s) {
            continue;
        }
        job: (JobInfo | None) = None;
        try {
            wake.clear();
            job = self.store.claim(spec.name, self.owner, spec.lease_s);
        } except Exception as e {
            logger.warning(f"job claim on queue '{spec.name}' failed: {e}");
        }
        if job is None {
            slots.release();
            wake.`wait(self.poll_s);
            continue;
        }
        claimed: JobInfo = job;
        def _run_and_release(j: JobInfo = claimed) {
            try {
                self._run_claimed(j);
            } except Exception as e {
                logger.error(f"job {j.id} bookkeeping failed: {e}");
            } finally {
                slots.release();
            }
        }
        try {
            pool.submit(_run_and_release);
        } except RuntimeError {
            slots.release();
            return;
        }
    }
}


impl JobRunner._maintain_loop -> None {
    while not self._maint_stop.is_set() {
        try {
            self.maintain();
        } except Exception as e {
            logger.warning(f"job runner maintenance pass failed: {e}");
        }
        self._maint_stop.`wait(self._maintain_s);
    }
}
