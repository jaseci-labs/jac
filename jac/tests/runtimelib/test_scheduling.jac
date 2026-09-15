"""Tests for the built-in scheduler engine."""

import datetime;
import threading;
import time;
import from pathlib { Path }
import from jaclang { JacRuntime as Jac }
import logging;
import from jaclang.server.task_scheduler {
    Scheduler,
    ScheduleSpec,
    ScheduledTask,
    schedule_namespace,
    tick_of
}

glob FIXTURES = str(Path(__file__).parent / "fixtures");

def fresh_scheduler -> Scheduler {
    return Scheduler();
}

test "task registration and scheduler lifecycle" {
    sched = fresh_scheduler();
    assert not sched.has_pending();

    # Future date registers successfully
    future = (datetime.datetime.now() + datetime.timedelta(hours=1)).isoformat();
    sched.register("future_task", lambda { None; }, ScheduleSpec(date=future), False);
    assert len(sched._tasks) == 1;
    assert sched._tasks[0].name == "future_task";
    assert sched._tasks[0].next_run is not None;

    # Past date is skipped
    past = (datetime.datetime.now() - datetime.timedelta(hours=1)).isoformat();
    sched.register("past_task", lambda { None; }, ScheduleSpec(date=past), False);
    assert len(sched._tasks) == 1;

    # Invalid date is skipped
    sched.register(
        "bad_date", lambda { None; }, ScheduleSpec(date="not-a-date"), False
    );
    assert len(sched._tasks) == 1;

    # Multiple task types
    sched.register("t_interval", lambda { None; }, ScheduleSpec(interval=60), False);
    sched.register("t_cron", lambda { None; }, ScheduleSpec(cron="* * * * *"), False);
    assert len(sched._tasks) == 3;
    names = [t.name for t in sched._tasks];
    assert "future_task" in names and "t_interval" in names and "t_cron" in names;

    # Start creates daemon thread; idempotent
    sched.start();
    assert sched._running;
    assert sched._thread is not None
        and sched._thread.is_alive()
        and sched._thread.daemon;
    thread1 = sched._thread;
    sched.start();
    assert sched._thread is thread1;
    sched.stop();
    assert not sched._running;

    # Stop without prior start is safe
    sched2 = fresh_scheduler();
    sched2._stop_event = threading.Event();
    sched2._done_event = threading.Event();
    sched2.stop();

    # Singleton identity
    s1 = Scheduler.instance();
    s2 = Scheduler.instance();
    assert s1 is s2;
}

test "cron field matching and next run computation" {
    sched = fresh_scheduler();

    # Wildcard
    assert sched._cron_field_matches("*", 0, 0, 59);
    assert sched._cron_field_matches("*", 31, 1, 31);

    # Exact
    assert sched._cron_field_matches("5", 5, 0, 59);
    assert not sched._cron_field_matches("5", 6, 0, 59);

    # Step
    assert sched._cron_field_matches("*/15", 0, 0, 59);
    assert sched._cron_field_matches("*/15", 15, 0, 59);
    assert sched._cron_field_matches("*/15", 30, 0, 59);
    assert not sched._cron_field_matches("*/15", 7, 0, 59);

    # Range
    assert sched._cron_field_matches("1-5", 3, 1, 31);
    assert not sched._cron_field_matches("1-5", 6, 1, 31);

    # Comma-separated
    assert sched._cron_field_matches("1,15,30", 15, 0, 59);
    assert not sched._cron_field_matches("1,15,30", 10, 0, 59);

    # Invalid values
    assert not sched._cron_field_matches("abc", 5, 0, 59);
    assert not sched._cron_field_matches("*/abc", 5, 0, 59);
    assert not sched._cron_field_matches("a-b", 5, 0, 59);

    # Cron next-run
    now = datetime.datetime(2026, 1, 1, 12, 0, 0);
    assert sched._parse_cron_next("* * * * *", now)
        == datetime.datetime(2026, 1, 1, 12, 1, 0);
    assert sched._parse_cron_next("30 * * * *", now)
        == datetime.datetime(2026, 1, 1, 12, 30, 0);
    now2 = datetime.datetime(2026, 1, 1, 8, 0, 0);
    assert sched._parse_cron_next("0 9 * * *", now2)
        == datetime.datetime(2026, 1, 1, 9, 0, 0);

    # Invalid field count raises ValueError
    raised = False;
    try {
        sched._parse_cron_next("* * *", datetime.datetime.now());
    } except ValueError {
        raised = True;
    }
    assert raised;
}

test "compute next run and schedule decorator" {
    sched = fresh_scheduler();
    now = datetime.datetime.now();

    # Date
    future = (now + datetime.timedelta(hours=1)).isoformat();
    result = sched._compute_next_run(ScheduleSpec(date=future), now);
    assert result is not None;
    assert abs((result - now).total_seconds() - 3600) < 2;

    # Interval: the next multiple of the interval since the epoch, so every
    # replica lands on the same ticks no matter when it booted.
    result = sched._compute_next_run(ScheduleSpec(interval=60.0), now);
    assert result is not None;
    delta = (result - now).total_seconds();
    assert 0.0 < delta <= 60.0 , delta;
    assert result.second == 0 and result.microsecond == 0 , result;

    # Cron
    result = sched._compute_next_run(ScheduleSpec(cron="* * * * *"), now);
    assert result is not None;

    # Empty spec
    assert sched._compute_next_run(ScheduleSpec(), now) is None;

    # Fixture: spec attachment
    (module, ) = Jac.jac_import("scheduled_tasks", FIXTURES);

    assert hasattr(module.IntervalWalker, 'schedule_spec');
    assert isinstance(module.IntervalWalker.schedule_spec, ScheduleSpec);
    assert module.IntervalWalker.schedule_spec.interval == 0.3;

    assert hasattr(module.date_function, 'schedule_spec');
    assert module.date_function.schedule_spec.date is not None;

    assert hasattr(module.CronWalker, 'schedule_spec');
    assert module.CronWalker.schedule_spec.cron == "* * * * *";

    # Trigger defaults to STATIC
    assert module.StaticWalker.schedule_spec.trigger == ScheduleTrigger.STATIC;
    assert module.static_fn.schedule_spec.trigger == ScheduleTrigger.STATIC;
    assert module.str_trigger_fn.schedule_spec.trigger == ScheduleTrigger.STATIC;

    # _execute catches exceptions gracefully
    def bad_fn {
        raise RuntimeError("boom");
    }
    task = ScheduledTask(
        name="bad_task",
        target=bad_fn,
        spec=ScheduleSpec(interval=60),
        is_walker=False,
        next_run=datetime.datetime.now(),
        last_run=None
    );
    sched._execute(task);
}

test "fixture loading registration and api exclusion" {
    import from jaclang.server.server { ModuleIntrospector }
    (module, ) = Jac.jac_import("scheduled_tasks", FIXTURES);

    # All scheduled items have schedule_spec
    for name in [
        "DateWalker",
        "IntervalWalker",
        "CronWalker",
        "date_function",
        "interval_function",
        "cron_function"
    ] {
        assert hasattr(getattr(module, name), "schedule_spec") , f"{name} missing schedule_spec";
    }

    # Registration
    sched = fresh_scheduler();
    for name in ["DateWalker", "IntervalWalker", "CronWalker"] {
        target = getattr(module, name);
        sched.register(name, target, target.schedule_spec, True);
    }
    for name in ["date_function", "interval_function", "cron_function"] {
        target = getattr(module, name);
        sched.register(name, target, target.schedule_spec, False);
    }
    assert sched.has_pending();
    assert len(sched._tasks) >= 4;

    # Scheduled items excluded from API endpoints
    introspector = ModuleIntrospector(
        module_name="scheduled_tasks", base_path=FIXTURES
    );
    introspector._walkers = {
        "DateWalker": module.DateWalker,
        "IntervalWalker": module.IntervalWalker,
        "CronWalker": module.CronWalker
    };
    introspector._functions = {
        "date_function": module.date_function,
        "interval_function": module.interval_function,
        "cron_function": module.cron_function
    };
    assert len(introspector.get_walkers()) == 0;
    assert len(introspector.get_functions()) == 0;
}

test "scheduler executes walkers and functions correctly" {
    (module, ) = Jac.jac_import("scheduled_tasks", FIXTURES);
    module.execution_log.clear();
    sched = fresh_scheduler();

    run_at = (datetime.datetime.now() + datetime.timedelta(seconds=0.2)).isoformat();
    sched.register("DateWalker", module.DateWalker, ScheduleSpec(date=run_at), True);
    sched.register(
        "date_function", module.date_function, ScheduleSpec(date=run_at), False
    );
    sched.register(
        "IntervalWalker", module.IntervalWalker, ScheduleSpec(interval=0.2), True
    );
    sched.register(
        "interval_function", module.interval_function, ScheduleSpec(interval=0.2), False
    );

    # Bad function to verify error recovery
    def bad_fn {
        raise RuntimeError("deliberate error");
    }
    sched.register("bad", bad_fn, ScheduleSpec(interval=0.2), False);

    sched.start();
    time.sleep(1.5);
    sched.stop();

    # Date tasks fire exactly once
    assert module.execution_log.count("date-walker") == 1 , "Date walker should fire once";
    assert module.execution_log.count("date-function") == 1 , "Date function should fire once";

    # Interval tasks fire multiple times
    walker_count = module.execution_log.count("interval-walker");
    fn_count = module.execution_log.count("interval-function");
    assert walker_count >= 2 , f"Expected >=2 interval-walker runs, got {walker_count}";
    assert fn_count >= 2 , f"Expected >=2 interval-function runs, got {fn_count}";
}


"""The server registers every static @schedule target with its scheduler, even
though scheduled walkers and functions are not HTTP endpoints and so never
appear in the introspector's endpoint listings."""
test "the served app registers its scheduled targets with the scheduler" {
    import from tempfile { TemporaryDirectory }
    import from jaclang.testing.testing { JacTestClient }
    with TemporaryDirectory() as tmpdir {
        client = JacTestClient.from_file(
            str(Path(FIXTURES) / "scheduled_tasks.jac"), base_path=tmpdir
        );
        try {
            server: any = client.server;
            assert "IntervalWalker" not in server.get_walkers();
            assert "interval_function" not in server.get_functions();
            server._register_scheduled_tasks();
            names = {task.name for task in server.scheduler._tasks};
            for expected in [
                "IntervalWalker",
                "interval_function",
                "CronWalker",
                "cron_function",
                "StaticWalker",
                "static_fn"
            ] {
                assert expected in names , f"{expected} not registered: {sorted(
                    names
                )}";
            }
        } finally {
            client.close();
        }
    }
}


def _ticks(sched: Scheduler, spec: ScheduleSpec, boot: datetime.datetime) -> list {
    out: list = [];
    at: any = boot;
    for _ in range(4) {
        at = sched._compute_next_run(spec, at);
        out.append(at);
    }
    return out;
}


test "replicas that booted apart fire on the same interval ticks" {
    # #9027: each replica used to tick from its own boot time, so two pods
    # booted 305 s apart ran a 610 s task on two phases, each outside the
    # other's 300 s lease. Ticks now come from the epoch, not the boot.
    sched = fresh_scheduler();
    spec = ScheduleSpec(interval=610);
    boot_a = datetime.datetime(
        2026, 9, 15, 11, 33, 13, 500000, tzinfo=datetime.timezone.utc
    );
    boot_b = boot_a + datetime.timedelta(seconds=305);
    ticks_a = _ticks(sched, spec, boot_a);
    ticks_b = _ticks(sched, spec, boot_b);
    for t in ticks_a + ticks_b {
        assert tick_of(t) % (610 * 1000000) == 0 , f"{t} is off the 610 s grid";
    }
    assert ticks_b[0] in ticks_a , f"pod B must land on pod A's ticks: {ticks_a} {ticks_b}";

    hourly = ScheduleSpec(interval=3600);
    first = sched._compute_next_run(hourly, boot_a);
    assert first is not None and first.minute == 0 and first.second == 0 , first;
}


test "a worker recomputes inherited fire times when it starts" {
    # A forked or respawned worker inherits the parent's next_run, already in
    # the past, and used to fire it the moment its loop began.
    sched = fresh_scheduler();
    sched.register("beat", lambda { None; }, ScheduleSpec(interval=600), False);
    stale = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(hours=1);
    sched._tasks[0].next_run = stale;
    sched.start();
    try {
        refreshed = sched._tasks[0].next_run;
        assert refreshed is not None;
        assert refreshed > datetime.datetime.now(datetime.timezone.utc) , refreshed;
    } finally {
        sched.stop();
    }
}


def _shared_claims -> tuple {
    # Stands in for kv_claim_tick: a key admits a tick only above its last one.
    last: dict[str, int] = {};
    lock = threading.Lock();
    def claim(key: str, tick: int) -> bool {
        with lock {
            if last.get(key, -1) >= tick {
                return False;
            }
            last[key] = tick;
            return True;
        }
    }
    return (claim, last);
}


test "one replica wins each tick, and a stale tick is refused" {
    (claim, last) = _shared_claims();
    pod_a = fresh_scheduler();
    pod_b = fresh_scheduler();
    for pod in [pod_a, pod_b] {
        pod.claim = claim;
        pod.namespace = "orders";
        pod.register("beat", lambda { None; }, ScheduleSpec(interval=610), False);
    }
    tick_1 = datetime.datetime(2026, 9, 15, 11, 43, 20, tzinfo=datetime.timezone.utc);
    tick_2 = tick_1 + datetime.timedelta(seconds=610);
    task_a = pod_a._tasks[0];
    task_b = pod_b._tasks[0];

    assert [pod_a._may_fire(task_a, tick_1), pod_b._may_fire(task_b, tick_1)]
        == [True, False];
    assert [pod_b._may_fire(task_b, tick_2), pod_a._may_fire(task_a, tick_2)]
        == [True, False];
    # A respawned worker holding an old fire time cannot run it again.
    assert pod_a._may_fire(task_a, tick_1) is False;
    assert last == {"sched:orders:beat": tick_of(tick_2)} , last;
}


test "services sharing a database claim their own task of the same name" {
    # #9028: the key was the bare task name, so a heartbeat in two services
    # contended for one lease and one of them silently skipped every tick.
    (claim, last) = _shared_claims();
    orders = fresh_scheduler();
    billing = fresh_scheduler();
    orders.claim = claim;
    billing.claim = claim;
    orders.namespace = "orders";
    billing.namespace = "billing";
    for pod in [orders, billing] {
        pod.register("heartbeat", lambda { None; }, ScheduleSpec(interval=60), False);
    }
    tick = datetime.datetime(2026, 9, 15, 12, 0, tzinfo=datetime.timezone.utc);
    assert orders._may_fire(orders._tasks[0], tick) is True;
    assert billing._may_fire(billing._tasks[0], tick) is True;
    assert sorted(last.keys()) == ["sched:billing:heartbeat", "sched:orders:heartbeat"];
}


test "the namespace is the fleet service name, else the served module" {
    import os;
    saved = os.environ.pop("JAC_SV_NAME", None);
    try {
        assert schedule_namespace("main") == "main";
        os.environ["JAC_SV_NAME"] = "orders";
        assert schedule_namespace("main") == "orders";
        os.environ["JAC_SV_NAME"] = "__gateway__";
        assert schedule_namespace("main") == "main";
    } finally {
        os.environ.pop("JAC_SV_NAME", None);
        if saved is not None {
            os.environ["JAC_SV_NAME"] = saved;
        }
    }
}


class _Records(logging.Handler) {
    def init(self: _Records) {
        super.__init__();
        self.messages: list[str] = [];
    }

    def emit(self: _Records, record: logging.LogRecord) {
        self.messages.append(f"{record.levelname} {record.getMessage()}");
    }
}


test "a tick whose claim cannot be checked is skipped, and logged once" {
    # #9030: a failed lease check used to return True on every worker of
    # every pod, so a database blip ran the task everywhere at once.
    calls: list[int] = [];
    def broken(key: str, tick: int) -> bool {
        calls.append(tick);
        if len(calls) <= 2 {
            raise ConnectionError("database is restarting");
        }
        return True;
    }
    sched = fresh_scheduler();
    sched.claim = broken;
    sched.namespace = "orders";
    sched.register("mailer", lambda { None; }, ScheduleSpec(interval=60), False);
    task = sched._tasks[0];
    tick = datetime.datetime(2026, 9, 15, 12, 0, tzinfo=datetime.timezone.utc);
    records = _Records();
    log = logging.getLogger("jaclang.server.task_scheduler");
    log.addHandler(records);
    try {
        assert sched._may_fire(task, tick) is False;
        assert sched._may_fire(task, tick + datetime.timedelta(seconds=60)) is False;
        assert sched._may_fire(task, tick + datetime.timedelta(seconds=120)) is True;
    } finally {
        log.removeHandler(records);
    }
    warnings = [
        m
        for m in records.messages
        if m.startswith("WARNING")
    ];
    recovered = [
        m
        for m in records.messages
        if "succeeding again" in m
    ];
    assert len(warnings) == 1 , records.messages;
    assert len(recovered) == 1 , records.messages;
}
