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
    self._threads = [];
    self._attending = {spec.name: set() for spec in self.queues};
    self._settled = threading.Condition();
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


impl JobRunner.stop(deadline_s: float = 10.0) -> None {
    import time;
    end = time.monotonic() + max(0.0, deadline_s);
    self._stop.set();
    for ev in self._wake.values() {
        ev.set();
    }
    for t in self._threads {
        t.join(timeout=max(0.0, end - time.monotonic()));
    }
    self._threads = [];
    with self._settled {
        while self.attending() {
            left = end - time.monotonic();
            if left <= 0 {
                break;
            }
            self._settled.`wait(left);
        }
    }
    left_behind = self.attending();
    if left_behind {
        logger.warning(
            f"job runner {self.owner} stopped with {len(left_behind)} job(s) still "
            "running; their leases are no longer renewed, so another runner takes "
            "them once the leases expire"
        );
    }
    self._maint_stop.set();
    if self._maint_thread is not None {
        self._maint_thread.join(timeout=max(0.0, end - time.monotonic()));
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


impl JobRunner.wake(payload: str = "") -> None {
    (service, sep, queue) = payload.partition(':');
    if not sep {
        queue = payload;
    } elif service != self.store.service {
        return;
    }
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
    self._attend(job);
    self._run_claimed(job);
    return True;
}


impl JobRunner.maintain -> None {
    for spec in self.queues {
        with self._settled {
            ids = sorted(self._attending[spec.name]);
        }
        self.store.heartbeat(ids, self.owner, spec.lease_s);
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


impl JobRunner.attending -> list[str] {
    with self._settled {
        return [job_id for ids in self._attending.values() for job_id in ids];
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


impl JobRunner._attend(job: JobInfo) -> None {
    with self._settled {
        self._attending.setdefault(job.queue, set()).add(job.id);
    }
}


impl JobRunner._release(job: JobInfo) -> None {
    with self._settled {
        self._attending.get(job.queue, set()).discard(job.id);
        self._settled.notify_all();
    }
}


impl JobRunner._run_claimed(job: JobInfo) -> None {
    try {
        self._record(job, self._await_attempt(job));
    } except Exception as e {
        logger.error(f"job {job.id} bookkeeping failed: {e}");
    } finally {
        self._release(job);
    }
}


impl JobRunner._await_attempt(job: JobInfo) -> (Exception | None) {
    if job.timeout_s <= 0 {
        try {
            self.execute(job);
        } except Exception as e {
            return e;
        }
        return None;
    }
    raised: list[Exception] = [];
    finished = threading.Event();
    def _attempt {
        try {
            self.execute(job);
        } except Exception as e {
            raised.append(e);
        } finally {
            finished.set();
        }
    }
    threading.Thread(
        target=_attempt, daemon=True, name=f"jac-job-{job.id[:8]}"
    ).start();
    if not finished.`wait(job.timeout_s) {
        return JobTimedOut(
            f"attempt {job.attempts} ran past timeout_s={job.timeout_s:g}; the "
            "runner stopped waiting for it and no longer renews its lease"
        );
    }
    return raised[0] if raised else None;
}


impl JobRunner._record(job: JobInfo, error: (Exception | None)) -> None {
    if error is None {
        if not self.store.complete(job.id, self.owner) {
            logger.warning(
                f"job {job.id} ({job.target}) finished after its lease was lost; "
                "another runner may run it again"
            );
        }
        return;
    }
    if isinstance(error, PermanentJobError) {
        self.store.fail(job, self.owner, str(error), permanent=True);
        logger.error(f"job {job.id} ({job.target}) is dead: {error}");
        return;
    }
    status = self.store.fail(job, self.owner, f"{type(error).__name__}: {error}");
    logger.warning(
        f"job {job.id} ({job.target}) attempt {job.attempts}/{job.max_attempts} "
        f"failed: {type(error).__name__}: {error}; now {status or 'no longer held'}"
    );
}


impl JobRunner._dispatch_loop(spec: QueueSpec) -> None {
    slots = self._slots[spec.name];
    wake = self._wake[spec.name];
    while not self._stop.is_set() {
        if not slots.acquire(timeout=self.poll_s) {
            continue;
        }
        job: (JobInfo | None) = None;
        if not self._stop.is_set() {
            try {
                wake.clear();
                job = self.store.claim(spec.name, self.owner, spec.lease_s);
            } except Exception as e {
                logger.warning(f"job claim on queue '{spec.name}' failed: {e}");
            }
        }
        if job is None {
            slots.release();
            wake.`wait(self.poll_s);
            continue;
        }
        claimed: JobInfo = job;
        self._attend(claimed);
        def _serve(j: JobInfo = claimed) {
            try {
                self._run_claimed(j);
            } finally {
                slots.release();
            }
        }
        threading.Thread(
            target=_serve, daemon=True, name=f"jac-jobs-{spec.name}-run"
        ).start();
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
