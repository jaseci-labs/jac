impl Scheduler.instance -> Scheduler {
    if _scheduler_instance is not None {
        return _scheduler_instance;
    }
    _scheduler_instance = Scheduler();
    return _scheduler_instance;
}

impl Scheduler.register(
    name: str, target: Callable, spec: ScheduleSpec, is_walker: bool
) -> None {
    problems = schedule_problems(spec);
    if problems {
        raise ValueError(f"@schedule on '{name}': {'; '.join(problems)}");
    }
    now = datetime.datetime.now(datetime.timezone.utc);
    next_run = self._compute_next_run(spec, now);
    if next_run is None {
        if spec.date is not None {
            logger.warning(
                f"@schedule on '{name}': date {spec.date} has already passed, "
                "so it is not registered and will not run"
            );
        }
        return;
    }
    self._tasks.append(
        ScheduledTask(
            name=name, target=target, spec=spec, is_walker=is_walker, next_run=next_run
        )
    );
}

impl tick_of(when: datetime.datetime) -> int {
    epoch = datetime.datetime(1970, 1, 1, tzinfo=datetime.timezone.utc);
    moment = when
        if when.tzinfo is not None
        else when.replace(tzinfo=datetime.timezone.utc);
    return (moment - epoch) // datetime.timedelta(microseconds=1);
}

impl schedule_namespace(module_name: str) -> str {
    service = os.environ.get('JAC_SV_NAME', '').strip();
    if service and service != '__gateway__' {
        return service;
    }
    return module_name;
}

impl schedule_problems(spec: ScheduleSpec) -> list[str] {
    timing = [
        name
        for (name, value) in [
            ("interval", spec.interval),
            ("cron", spec.cron),
            ("date", spec.date)
        ]
        if value is not None
    ];
    if spec.trigger == ScheduleTrigger.DYNAMIC {
        if timing {
            return [
                f"a DYNAMIC schedule takes no {' or '.join(timing)}; its timing "
                "comes from each POST /jobs request"
            ];
        }
        return [];
    }
    if not timing {
        return ["needs one of interval, cron or date"];
    }
    if len(timing) > 1 {
        return [f"takes one of interval, cron or date, not {' and '.join(timing)}"];
    }
    if spec.interval is not None {
        raw: any = spec.interval;
        seconds = 0.0;
        if not isinstance(raw, bool) and isinstance(raw, (int, float)) {
            try {
                seconds = float(raw);
            } except OverflowError {
                return [f"interval {raw!r} seconds is too long to schedule"];
            }
        }
        if not (math.isfinite(seconds) and seconds > 0.0) {
            return [f"interval must be a positive number of seconds, got {raw!r}"];
        }
        try {
            if datetime.timedelta(seconds=seconds) <= datetime.timedelta(0) {
                return [
                    f"interval must be at least a microsecond, got {raw!r} seconds"
                ];
            }
            next_interval_run(seconds, datetime.datetime.now(datetime.timezone.utc));
        } except OverflowError {
            return [
                f"interval {raw!r} seconds is too long to schedule: its next run "
                "falls outside the dates the scheduler can represent"
            ];
        }
    }
    if spec.cron is not None {
        try {
            CronSchedule.parse(str(spec.cron));
        } except ValueError as e {
            return [str(e)];
        }
    }
    if spec.date is not None {
        try {
            datetime.datetime.fromisoformat(str(spec.date));
        } except (ValueError, TypeError) {
            return [
                f"date {spec.date!r} is not an ISO date-time such as "
                "'2026-12-31 09:00:00+00:00'"
            ];
        }
    }
    return [];
}

impl next_interval_run(seconds: float, now: datetime.datetime) -> datetime.datetime {
    step = datetime.timedelta(seconds=seconds);
    if step <= datetime.timedelta(0) {
        return now + step;
    }
    epoch = datetime.datetime(1970, 1, 1, tzinfo=now.tzinfo);
    return epoch + step * ((now - epoch) // step + 1);
}

impl CronSchedule.parse(expr: str) -> CronSchedule {
    fields = str(expr).strip().split();
    if len(fields) != 5 {
        raise ValueError(
            f"cron {expr!r} needs 5 fields (minute hour day month weekday), "
            f"got {len(fields)}"
        );
    }
    found: list[set[int]] = [];
    for (index, (label, lo, hi)) in enumerate(CRON_FIELDS) {
        found.append(_cron_values(expr, fields[index], label, lo, hi));
    }
    schedule = CronSchedule(
        minutes=found[0],
        hours=found[1],
        days=found[2],
        months=found[3],
        weekdays=found[4]
    );
    if not any(
        day <= MONTH_DAYS[month] for month in schedule.months for day in schedule.days
    ) {
        raise ValueError(
            f"cron {expr!r} never fires: none of its days exists in its months"
        );
    }
    return schedule;
}

impl _cron_values(expr: str, text: str, label: str, lo: int, hi: int) -> set[int] {
    values: set[int] = set();
    for part in text.split(',') {
        if part == '*' {
            values.update(range(lo, hi + 1));
        } elif part.startswith('*/') {
            step = _cron_number(expr, part[2:], label, 1, hi - lo + 1);
            values.update(range(lo, hi + 1, step));
        } elif '-' in part {
            (first_text, last_text) = part.split('-', 1);
            first = _cron_number(expr, first_text, label, lo, hi);
            last = _cron_number(expr, last_text, label, lo, hi);
            if first > last {
                raise ValueError(
                    f"cron {expr!r}: {label} range {part!r} runs backwards"
                );
            }
            values.update(range(first, last + 1));
        } else {
            values.add(_cron_number(expr, part, label, lo, hi));
        }
    }
    return values;
}

impl _cron_number(expr: str, text: str, label: str, lo: int, hi: int) -> int {
    if not text.isdigit() {
        raise ValueError(
            f"cron {expr!r}: {label} field has {text!r}; each entry must be *, "
            "*/n, a-b or a number"
        );
    }
    value = int(text);
    if value < lo or value > hi {
        raise ValueError(f"cron {expr!r}: {label} value {value} is outside {lo}-{hi}");
    }
    return value;
}

impl CronSchedule.next_after(now: datetime.datetime) -> datetime.datetime {
    moment = now.replace(second=0, microsecond=0) + datetime.timedelta(minutes=1);
    last_year = moment.year + 400;
    while moment.year <= last_year {
        if moment.month not in self.months {
            if moment.month == 12 {
                moment = moment.replace(
                    year=moment.year + 1, month=1, day=1, hour=0, minute=0
                );
            } else {
                moment = moment.replace(
                    month=moment.month + 1, day=1, hour=0, minute=0
                );
            }
        } elif moment.day not in self.days or moment.weekday() not in self.weekdays {
            moment = (moment + datetime.timedelta(days=1)).replace(hour=0, minute=0);
        } elif moment.hour not in self.hours {
            moment = (moment + datetime.timedelta(hours=1)).replace(minute=0);
        } elif moment.minute not in self.minutes {
            moment = moment + datetime.timedelta(minutes=1);
        } else {
            return moment;
        }
    }
    raise ValueError(f"no run within 400 years of {now.isoformat()}");
}

impl Scheduler.start -> None {
    if self._running {
        return;
    }
    now = datetime.datetime.now(datetime.timezone.utc);
    for task in self._tasks {
        if task.next_run is not None {
            task.next_run = self._compute_next_run(task.spec, now);
        }
    }
    self._running = True;
    self._stop_event = threading.Event();
    self._done_event = threading.Event();
    self._thread = threading.Thread(target=self._run_loop, daemon=True);
    self._thread.start();
}

impl Scheduler.on_run(name: str, listener: Callable[[RunOutcome], None]) -> None {
    self._listeners[name] = listener;
}

impl Scheduler.start_if_pending -> None {
    if self.has_pending() {
        self.start();
    }
}

impl Scheduler._tick(task: ScheduledTask, due: datetime.datetime) -> None {
    if self.drain is not None and self.drain.draining {
        self._skip(task, due, "draining");
    } elif self._still_running(task) {
        self._skip(task, due, "still_running");
    } elif not self._hold_run(task) {
        failed = self._run_key(task) in self._failing_claims;
        self._skip(task, due, "hold_failed" if failed else "running_elsewhere");
    } elif self._may_fire(task, due) {
        self._launch(task, due);
    } else {
        self._release_run(task);
        failed = self._claim_key(task) in self._failing_claims;
        self._skip(task, due, "claim_failed" if failed else "claimed_elsewhere");
    }
}

impl Scheduler._claim_key(task: ScheduledTask) -> str {
    return f"sched:{self.namespace}:{task.name}";
}

impl Scheduler._may_fire(task: ScheduledTask, due: datetime.datetime) -> bool {
    if self.claim is None {
        return True;
    }
    claim_fn: any = self.claim;
    key = self._claim_key(task);
    try {
        won = bool(claim_fn(key, tick_of(due)));
    } except Exception as e {
        if key not in self._failing_claims {
            self._failing_claims.add(key);
            logger.warning(
                f"could not claim the {due.isoformat()} tick of '{task.name}': {e}; "
                "skipping its ticks until a claim succeeds"
            );
        }
        return False;
    }
    if key in self._failing_claims {
        self._failing_claims.discard(key);
        logger.info(f"tick claims for '{task.name}' are succeeding again");
    }
    return won;
}

impl Scheduler._run_key(task: ScheduledTask) -> str {
    return f"sched-run:{self.namespace}:{task.name}";
}

impl Scheduler._hold_owner -> str {
    if not self._owner {
        self._owner = f"{socket.gethostname()}:{os.getpid()}:{uuid.uuid4().hex}";
    }
    return self._owner;
}

impl Scheduler._take_hold(task: ScheduledTask) -> bool {
    hold_fn: any = self.hold;
    return bool(hold_fn(self._run_key(task), self.hold_ttl, self._hold_owner()));
}

impl Scheduler._hold_run(task: ScheduledTask) -> bool {
    if self.hold is None {
        return True;
    }
    key = self._run_key(task);
    try {
        held = self._take_hold(task);
    } except Exception as e {
        if key not in self._failing_claims {
            self._failing_claims.add(key);
            logger.warning(
                f"could not take the run hold of '{task.name}': {e}; "
                "skipping its ticks until a hold succeeds"
            );
        }
        return False;
    }
    if key in self._failing_claims {
        self._failing_claims.discard(key);
        logger.info(f"run holds for '{task.name}' are succeeding again");
    }
    return held;
}

impl Scheduler._keep_hold(task: ScheduledTask, beat: threading.Event) -> None {
    lost = False;
    while not beat.`wait(self.hold_ttl / 3) {
        try {
            held = self._take_hold(task);
            reason = "";
        } except Exception as e {
            held = False;
            reason = f" ({e})";
        }
        if held and lost {
            lost = False;
            logger.info(f"'{task.name}' has its run hold back while still running");
        } elif not held and not lost {
            lost = True;
            logger.warning(
                f"'{task.name}' lost its run hold while still running{reason}; "
                "another replica may start it"
            );
        }
    }
}

impl Scheduler._release_run(task: ScheduledTask) -> None {
    if self.release is None {
        return;
    }
    release_fn: any = self.release;
    try {
        release_fn(self._run_key(task), self._hold_owner());
    } except Exception as e {
        logger.warning(
            f"could not release the run hold of '{task.name}': {e}; "
            f"it expires within {self.hold_ttl}s"
        );
    }
}

impl Scheduler._still_running(task: ScheduledTask) -> bool {
    with self._flight_lock {
        flight = self._in_flight.get(id(task));
    }
    if flight is not None and flight[1].is_alive() {
        if task.name not in self._overlapping {
            self._overlapping.add(task.name);
            logger.warning(
                f"'{task.name}' is still running from an earlier tick; skipping its "
                "ticks until that run finishes"
            );
        }
        return True;
    }
    if task.name in self._overlapping {
        self._overlapping.discard(task.name);
        logger.info(f"'{task.name}' finished its long run; its ticks run again");
    }
    return False;
}

impl Scheduler._launch(task: ScheduledTask, due: datetime.datetime) -> None {
    thread = threading.Thread(
        target=self._run_tracked,
        args=(task, due),
        daemon=True,
        name=f"jac-schedule-{task.name}"
    );
    with self._flight_lock {
        refused = not self._running;
        if not refused {
            self._in_flight[id(task)] = (task.name, thread);
        }
    }
    if refused {
        self._release_run(task);
        self._skip(task, due, "stopping");
        return;
    }
    thread.start();
}

impl Scheduler._run_tracked(task: ScheduledTask, due: datetime.datetime) -> None {
    beat = threading.Event();
    keeper: (threading.Thread | None) = None;
    if self.hold is not None {
        keeper = threading.Thread(
            target=self._keep_hold,
            args=(task, beat),
            daemon=True,
            name=f"jac-schedule-hold-{task.name}"
        );
        keeper.start();
    }
    try {
        started = time.monotonic();
        error = self._execute(task);
        self._report(
            RunOutcome(
                task=task.name,
                tick=due,
                worker=self._worker(),
                status="failed" if error else "ok",
                duration=time.monotonic() - started,
                error=error
            )
        );
    } finally {
        beat.set();
        if keeper is not None {
            keeper.join();
        }
        self._release_run(task);
        with self._flight_lock {
            flight = self._in_flight.get(id(task));
            if flight is not None and flight[1] is threading.current_thread() {
                del self._in_flight[id(task)];
            }
        }
    }
}

impl Scheduler.stop(timeout: (float | None) = None) -> None {
    budget = max(0.0, timeout) if timeout is not None else None;
    deadline = time.monotonic() + (budget if budget is not None else 5.0);
    with self._flight_lock {
        self._running = False;
    }
    if self._stop_event is not None {
        self._stop_event.set();
    }
    if self._done_event is not None {
        self._done_event.set();
    }
    if self._thread is not None and self._thread.is_alive() {
        self._thread.join(timeout=max(0.0, deadline - time.monotonic()));
    }
    with self._flight_lock {
        running = [
            flight
            for flight in self._in_flight.values()
            if flight[1].is_alive()
        ];
    }
    if not running or budget is None {
        return;
    }
    for (_name, thread) in running {
        thread.join(timeout=max(0.0, deadline - time.monotonic()));
    }
    left = sorted(
        [
            name
            for (name, thread) in running
            if thread.is_alive()
        ]
    );
    if left {
        logger.warning(
            f"scheduled task(s) {', '.join(left)} still running when the "
            f"{budget:.1f}s drain budget ran out; the worker exits without them"
        );
    }
}

impl Scheduler.`wait -> None {
    if not self._running {
        return;
    }
    if self._done_event is None {
        return;
    }
    try {
        while not self._done_event.`wait(timeout=0.5) {}
    } except KeyboardInterrupt {
        logger.info("Scheduler interrupted, shutting down...");
    }
    self.stop();
}

impl Scheduler.has_pending -> bool {
    return any(task.next_run is not None for task in self._tasks);
}

impl Scheduler._run_loop -> None {
    stop_event = self._stop_event;
    done_event = self._done_event;
    if stop_event is None or done_event is None {
        return;
    }
    heap: list[tuple[float, int, ScheduledTask]] = [];
    for (i, task) in enumerate(self._tasks) {
        if task.next_run is None {
            continue;
        }
        heapq.heappush(heap, (task.next_run.timestamp(), i, task));
    }
    while self._running {
        self._pick_up_new_tasks(heap);
        if not heap {
            stop_event.`wait(timeout=1.0);
            continue;
        }
        (next_ts, idx, task) = heap[0];
        delay = next_ts - datetime.datetime.now(datetime.timezone.utc).timestamp();
        if delay > 0 {
            stop_event.`wait(timeout=delay);
        }
        if not self._running {
            break;
        }
        heapq.heappop(heap);
        now = datetime.datetime.now(datetime.timezone.utc);
        due = task.next_run;
        if due is not None {
            self._tick(task, due);
        }
        new_next = self._compute_next_run(task.spec, now);
        task.next_run = new_next;
        if new_next is not None {
            heapq.heappush(heap, (new_next.timestamp(), id(task), task));
        }
        if not heap and not self.has_pending() {
            done_event.set();
        }
    }
    done_event.set();
}

impl Scheduler._pick_up_new_tasks(
    heap: list[tuple[float, int, ScheduledTask]]
) -> None {
    heap_tasks = {id(t) for (_, _, t) in heap};
    for (i, task) in enumerate(self._tasks) {
        if task.next_run is None {
            continue;
        }
        if id(task) in heap_tasks {
            continue;
        }
        heapq.heappush(heap, (task.next_run.timestamp(), i, task));
    }
}

impl Scheduler._compute_next_run(
    spec: ScheduleSpec, now: datetime.datetime
) -> (datetime.datetime | None) {
    if spec.date is not None {
        return self._compute_date(spec.date, now);
    }
    if spec.interval is not None {
        return next_interval_run(float(spec.interval), now);
    }
    if spec.cron is not None {
        return CronSchedule.parse(str(spec.cron)).next_after(now);
    }
    return None;
}

impl Scheduler._compute_date(
    date_str: str, now: datetime.datetime
) -> (datetime.datetime | None) {
    try {
        run_at = datetime.datetime.fromisoformat(date_str);
    } except (ValueError, TypeError) {
        logger.warning(f"Invalid date format: {date_str}");
        return None;
    }
    run_at_aware = run_at.tzinfo is not None;
    now_aware = now.tzinfo is not None;
    if now_aware and not run_at_aware {
        run_at = run_at.astimezone(datetime.timezone.utc);
    } elif run_at_aware and not now_aware {
        run_at = run_at.replace(tzinfo=None);
    }
    if run_at > now {
        return run_at;
    }
    return None;
}

impl Scheduler._execute(task: ScheduledTask) -> str {
    try {
        result = task.target();
        if task.is_walker {
            import from jaclang.runtime.constructs { WalkerArchetype }
            if isinstance(result, WalkerArchetype) {
                import from jaclang { JacRuntimeInterface as Jac }
                Jac.`spawn(result, Jac.root());
            }
        }
    } except Exception as e {
        return f"{type(e).__name__}: {e}";
    }
    if isinstance(result, dict) and result.get('error') {
        return str(result['error']);
    }
    return "";
}

impl Scheduler._worker -> str {
    return f"{socket.gethostname()}:{os.getpid()}";
}

impl Scheduler._skip(task: ScheduledTask, due: datetime.datetime, reason: str) -> None {
    self._report(
        RunOutcome(
            task=task.name,
            tick=due,
            worker=self._worker(),
            status="skipped",
            reason=reason
        )
    );
}

impl Scheduler._report(outcome: RunOutcome) -> None {
    tick = outcome.tick.isoformat();
    took = f"{outcome.duration * 1000:.1f} ms";
    fields: dict[str, any] = {
        "task": outcome.task,
        "tick": tick,
        "worker": outcome.worker,
        "status": outcome.status
    };
    if outcome.status == "skipped" {
        fields["reason"] = outcome.reason;
        logger.debug(
            f"scheduled {outcome.task} skipped its {tick} tick: {outcome.reason}",
            extra={"svc_extras": fields}
        );
    } else {
        fields["duration_ms"] = round(outcome.duration * 1000, 1);
        where = f"(tick {tick}, worker {outcome.worker})";
        if outcome.status == "failed" {
            fields["error"] = outcome.error;
            logger.error(
                f"scheduled {outcome.task} failed in {took} {where}: {outcome.error}",
                extra={"svc_extras": fields}
            );
        } else {
            logger.info(
                f"scheduled {outcome.task} ok in {took} {where}",
                extra={"svc_extras": fields}
            );
        }
    }
    if outcome.status != "skipped" {
        self._remember(outcome);
    }
    for (name, listener) in list(self._listeners.items()) {
        try {
            listener(outcome);
        } except Exception as e {
            logger.warning(f"run listener '{name}' failed on {outcome.task}: {e}");
        }
    }
}

impl Scheduler._last_key(name: str) -> str {
    return f"sched-last:{self.namespace}:{name}";
}

impl Scheduler._remember(outcome: RunOutcome) -> None {
    last: dict[str, any] = {
        "tick": outcome.tick.isoformat(),
        "worker": outcome.worker,
        "status": outcome.status,
        "duration_ms": round(outcome.duration * 1000, 1),
        "error": outcome.error,
        "finished_at": datetime.datetime.now(datetime.timezone.utc).isoformat()
    };
    self._last[outcome.task] = last;
    if self.record is None {
        return;
    }
    record_fn: any = self.record;
    key = self._last_key(outcome.task);
    try {
        record_fn(key, json.dumps(last));
    } except Exception as e {
        if key not in self._failing_claims {
            self._failing_claims.add(key);
            logger.warning(
                f"could not record the last run of '{outcome.task}': {e}; "
                "listings show this worker's own runs until a record succeeds"
            );
        }
        return;
    }
    if key in self._failing_claims {
        self._failing_claims.discard(key);
        logger.info(f"last-run records for '{outcome.task}' are succeeding again");
    }
}

impl Scheduler.last_run_of(name: str) -> (dict[str, any] | None) {
    key = self._last_key(name);
    if self.recall is not None and key not in self._failing_claims {
        recall_fn: any = self.recall;
        read_key = f"{key}#read";
        try {
            raw = recall_fn(key);
            answer = json.loads(raw) if raw else None;
            if read_key in self._failing_claims {
                self._failing_claims.discard(read_key);
                logger.info(f"last-run reads for '{name}' are succeeding again");
            }
            return answer;
        } except Exception as e {
            if read_key not in self._failing_claims {
                self._failing_claims.add(read_key);
                logger.warning(
                    f"could not read the last run of '{name}': {e}; "
                    "showing this worker's own last run until a read succeeds"
                );
            }
        }
    }
    return self._last.get(name);
}

impl Scheduler.schedules -> list[dict[str, any]] {
    return [
        {
            "name": task.name,
            "kind": "walker" if task.is_walker else "function",
            "interval": task.spec.interval,
            "cron": task.spec.cron,
            "date": task.spec.date,
            "next_run": task.next_run.isoformat()
                if task.next_run is not None
                else None,
            "last_run": self.last_run_of(task.name)
        } for task in self._tasks
    ];
}
