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
    now = datetime.datetime.now(datetime.timezone.utc);
    next_run = self._compute_next_run(spec, now);
    if next_run is None {
        return;
    }
    for existing in self._tasks {
        if existing.name == name {
            existing.target = target;
            existing.spec = spec;
            existing.is_walker = is_walker;
            existing.next_run = next_run;
            self._wake();
            return;
        }
    }
    self._tasks.append(
        ScheduledTask(
            name=name,
            target=target,
            spec=spec,
            is_walker=is_walker,
            next_run=next_run,
            last_run=None
        )
    );
    self._wake();
}

impl Scheduler._wake -> None {
    if self._running and self._stop_event is not None {
        self._stop_event.set();
    }
}

impl Scheduler.remove(name: str) -> None {
    self._tasks = [
        t
        for t in self._tasks
        if t.name != name
    ];
}

impl Scheduler.start -> None {
    if self._running {
        return;
    }
    self._running = True;
    if self._in_flight_names is None {
        self._in_flight_names = set();
    }
    self._stop_event = threading.Event();
    self._done_event = threading.Event();
    self._thread = threading.Thread(target=self._run_loop, daemon=True);
    self._thread.start();
}

impl Scheduler.stop -> None {
    self._running = False;
    if self._stop_event is not None {
        self._stop_event.set();
    }
    if self._done_event is not None {
        self._done_event.set();
    }
    if self._thread is not None and self._thread.is_alive() {
        self._thread.join(timeout=5);
    }
    import time;
    deadline = time.monotonic() + 5.0;
    while self._in_flight_names and time.monotonic() < deadline {
        time.sleep(0.1);
    }
    self._tasks = [];
}

impl Scheduler.wait -> None {
    if not self._running {
        return;
    }
    if self._done_event is None {
        return;
    }
    try {
        while not self._done_event.wait(timeout=0.5) { }
    } except KeyboardInterrupt {
        logger.info("Scheduler interrupted, shutting down...");
    }
    self.stop();
}

impl Scheduler.has_pending -> bool {
    return any(task.next_run is not None for task in self._tasks);
}

impl Scheduler._run_loop -> None {
    heap: list = [];
    while self._running {
        self._pick_up_new_tasks(heap);
        if not heap {
            self._stop_event.wait(timeout=1.0);
            if not self._running {
                break;
            }
            self._stop_event.clear();
            if not self._running {
                break;
            }
            continue;
        }
        (next_ts, seq, task) = heap[0];
        delay = next_ts - datetime.datetime.now(datetime.timezone.utc).timestamp();
        if delay > 0 {
            self._stop_event.wait(timeout=delay);
            if not self._running {
                break;
            }
            self._stop_event.clear();
            if not self._running {
                break;
            }
            continue;
        }
        heapq.heappop(heap);
        if not any((t is task) for t in self._tasks) {
            continue;
        }
        if task.next_run is None or task.next_run.timestamp() != next_ts {
            continue;
        }
        now = datetime.datetime.now(datetime.timezone.utc);
        if task.name not in self._in_flight_names {
            self._in_flight_names.add(task.name);
            task.last_run = now;
            threading.Thread(target=self._execute, args=(task, ), daemon=True).start();
        }
        new_next = self._compute_next_run(task.spec, now);
        task.next_run = new_next;
        if new_next is not None {
            heapq.heappush(heap, (new_next.timestamp(), id(task), task));
        }
        if not heap and not self.has_pending() {
            self._done_event.set();
        }
    }
    self._done_event.set();
}

impl Scheduler._pick_up_new_tasks(heap: list) -> None {
    entry_ts: dict = {};
    for (ts, _, t) in heap {
        entry_ts.setdefault(id(t), set()).add(ts);
    }
    for task in self._tasks {
        if task.next_run is None {
            continue;
        }
        ts = task.next_run.timestamp();
        if ts in entry_ts.get(id(task), set()) {
            continue;
        }
        heapq.heappush(heap, (ts, id(task), task));
    }
}

impl Scheduler._compute_next_run(
    spec: ScheduleSpec, now: datetime.datetime
) -> (datetime.datetime | None) {
    if spec.date is not None {
        return self._compute_date(spec.date, now);
    }
    if spec.interval is not None {
        return now + datetime.timedelta(seconds=spec.interval);
    }
    if spec.cron is not None {
        return self._parse_cron_next(str(spec.cron), now);
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

impl Scheduler._parse_cron_next(
    cron: str, now: datetime.datetime
) -> datetime.datetime {
    fields = cron.strip().split();
    if len(fields) != 5 {
        raise ValueError(f"Cron must have 5 fields, got: {cron}");
    }
    (f_min, f_hour, f_day, f_month, f_weekday) = fields;
    candidate = now.replace(second=0, microsecond=0) + datetime.timedelta(minutes=1);
    limit = now + datetime.timedelta(days=366);
    while candidate <= limit {
        if not (
            self._cron_field_matches(f_month, candidate.month, 1, 12)
            and self._cron_field_matches(f_day, candidate.day, 1, 31)
            and self._weekday_matches(f_weekday, candidate)
        ) {
            candidate = (candidate + datetime.timedelta(days=1)).replace(
                hour=0, minute=0
            );
            continue;
        }
        if not self._cron_field_matches(f_hour, candidate.hour, 0, 23) {
            candidate = (candidate + datetime.timedelta(hours=1)).replace(minute=0);
            continue;
        }
        if self._cron_field_matches(f_min, candidate.minute, 0, 59) {
            return candidate;
        }
        candidate = candidate + datetime.timedelta(minutes=1);
    }
    raise ValueError(f"No matching time found for cron: {cron}");
}

impl Scheduler._weekday_matches(field: str, candidate: datetime.datetime) -> bool {
    wd = (candidate.weekday() + 1) % 7;
    if self._cron_field_matches(field, wd, 0, 6) {
        return True;
    }
    return wd == 0 and self._cron_field_matches(field, 7, 0, 7);
}

impl Scheduler._cron_field_matches(
    field: str, value: int, min_val: int, max_val: int
) -> bool {
    for part in field.split(',') {
        part = part.strip();
        if part == '*' {
            return True;
        } elif part.startswith('*/') {
            try {
                step = int(part[2:]);
                if step > 0 and (value - min_val) % step == 0 {
                    return True;
                }
            } except ValueError { }
        } elif '-' in part {
            try {
                (lo, hi) = part.split('-', 1);
                if int(lo) <= value <= int(hi) {
                    return True;
                }
            } except ValueError { }
        } else {
            try {
                if int(part) == value {
                    return True;
                }
            } except ValueError { }
        }
    }
    return False;
}

impl Scheduler._execute(task: ScheduledTask) -> None {
    try {
        if task.spec.trigger == ScheduleTrigger.DYNAMIC {
            if self.dynamic_handler is None {
                raise NotImplementedError(
                    "Dynamic scheduling is not implemented in jaclang."
                );
            }
            self.dynamic_handler(task);
            return;
        }
        if task.is_walker {
            import from jaclang { JacRuntimeInterface as Jac }
            import from jaclang.jac0core.constructs { WalkerArchetype }
            walker_instance = task.target();
            if not isinstance(walker_instance, WalkerArchetype) {
                raise TypeError("Invalid walker object");
            }
            Jac.spawn(walker_instance, Jac.root());
        } else {
            task.target();
        }
    } except Exception as e {
        logger.error(f"Error executing task '{task.name}': {e}");
    } finally {
        if self._in_flight_names is not None {
            self._in_flight_names.discard(task.name);
        }
    }
}
