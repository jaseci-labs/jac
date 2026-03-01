"""Return or create the module-level singleton Scheduler."""
impl Scheduler.instance -> Scheduler {
    global _scheduler_instance;
    if _scheduler_instance is not None {
        return _scheduler_instance;
    }
    _scheduler_instance = Scheduler();
    return _scheduler_instance;
}

"""Register a task with the scheduler."""
impl Scheduler.register(
    name: str, target: Callable, spec: ScheduleSpec, is_walker: bool
) -> None {
    now = datetime.datetime.now();
    next_run = self._compute_next_run(spec, now);
    if next_run is None {
        return;
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
}

"""Start the background scheduler thread."""
impl Scheduler.start -> None {
    if self._running {
        return;
    }
    self._running = True;
    self._stop_event = threading.Event();
    self._done_event = threading.Event();
    self._thread = threading.Thread(target=self._run_loop, daemon=True);
    self._thread.start();
}

"""Signal the scheduler to stop and wait for the thread to finish."""
impl Scheduler.stop -> None {
    self._running = False;
    self._stop_event.set();
    self._done_event.set();
    if self._thread and self._thread.is_alive() {
        self._thread.join(timeout=5);
    }
}

"""Block the calling thread until all tasks complete or KeyboardInterrupt.

For one-shot (date) tasks, returns when all have fired.
For recurring (interval/cron) tasks, blocks until Ctrl+C.
"""
impl Scheduler.wait -> None {
    if not self._running {
        return;
    }
    try {
        while not self._done_event.wait(timeout=0.5) { }
    } except KeyboardInterrupt {
        logger.info("Scheduler interrupted, shutting down...");
    }
    self.stop();
}

"""Check if any tasks still have a future run scheduled."""
impl Scheduler.has_pending -> bool {
    return any(task.next_run is not None for task in self._tasks);
}

"""Main scheduler loop using a heapq priority queue."""
impl Scheduler._run_loop -> None {
    heap: list = [];
    for (i, task) in enumerate(self._tasks) {
        if task.next_run is None {
            continue;
        }
        heapq.heappush(heap, (task.next_run.timestamp(), i, task));
    }
    while self._running {
        self._pick_up_new_tasks(heap);
        if not heap {
            self._stop_event.wait(timeout=1.0);
            continue;
        }
        (next_ts, idx, task) = heap[0];
        delay = next_ts - datetime.datetime.now().timestamp();
        if delay > 0 {
            self._stop_event.wait(timeout=delay);
        }
        if not self._running {
            break;
        }
        heapq.heappop(heap);
        now = datetime.datetime.now();
        task.last_run = now;
        threading.Thread(target=self._execute, args=(task, ), daemon=True).start();
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

"""Pick up any newly registered tasks not yet in the heap."""
impl Scheduler._pick_up_new_tasks(heap: list) -> None {
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

"""Compute the next run datetime for a given spec."""
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

"""Compute next run for a date-based spec."""
impl Scheduler._compute_date(
    date_str: str, now: datetime.datetime
) -> (datetime.datetime | None) {
    try {
        run_at = datetime.datetime.fromisoformat(date_str);
    } except (ValueError, TypeError) {
        logger.warning(f"Invalid date format: {date_str}");
        return None;
    }
    if run_at > now {
        return run_at;
    }
    return None;
}

"""Parse a 5-field cron string and return the next matching datetime."""
impl Scheduler._parse_cron_next(
    cron: str, now: datetime.datetime
) -> datetime.datetime {
    fields = cron.strip().split();
    if len(fields) != 5 {
        raise ValueError(f"Cron must have 5 fields, got: {cron}") ;
    }
    (f_min, f_hour, f_day, f_month, f_weekday) = fields;
    candidate = now.replace(second=0, microsecond=0) + datetime.timedelta(minutes=1);
    limit = now + datetime.timedelta(days=366);
    while candidate <= limit {
        if (
            self._cron_field_matches(f_month, candidate.month, 1, 12)
            and self._cron_field_matches(f_day, candidate.day, 1, 31)
            and self._cron_field_matches(f_weekday, candidate.weekday(), 0, 6)
            and self._cron_field_matches(f_hour, candidate.hour, 0, 23)
            and self._cron_field_matches(f_min, candidate.minute, 0, 59)
        ) {
            return candidate;
        }
        candidate = candidate + datetime.timedelta(minutes=1);
    }
    raise ValueError(f"No matching time found for cron: {cron}") ;
}

"""Check if a cron field matches a value."""
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

"""Execute a single scheduled task."""
impl Scheduler._execute(task: ScheduledTask) -> None {
    try {
        if task.is_walker {
            import from jaclang { JacRuntimeInterface as Jac }
            walker_instance = task.target();
            Jac.spawn(walker_instance, Jac.root());
        } else {
            task.target();
        }
    } except Exception as e {
        logger.error(f"Error executing task '{task.name}': {e}");
    }
}
