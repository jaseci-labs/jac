"""Tests for the built-in scheduler engine."""

import datetime;
import threading;
import time;
import from pathlib { Path }
import from jaclang { JacRuntime as Jac }
import logging;
import from jaclang.server.task_scheduler {
    CronSchedule,
    Scheduler,
    ScheduleSpec,
    ScheduledTask,
    schedule_problems
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

    # A malformed date is a spec error, not a silent skip
    refused = False;
    try {
        sched.register(
            "bad_date", lambda { None; }, ScheduleSpec(date="not-a-date"), False
        );
    } except ValueError as e {
        refused = "bad_date" in str(e);
    }
    assert refused;
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

test "cron fields parse into the values they select" {
    cron = CronSchedule.parse("*/15 9-11 1,15 * 0-4");
    assert cron.minutes == {0, 15, 30, 45} , cron.minutes;
    assert cron.hours == {9, 10, 11} , cron.hours;
    assert cron.days == {1, 15} , cron.days;
    assert cron.months == set(range(1, 13)) , cron.months;
    assert cron.weekdays == {0, 1, 2, 3, 4} , cron.weekdays;
    assert CronSchedule.parse("* * */2 * *").days == set(range(1, 32, 2));

    now = datetime.datetime(2026, 1, 1, 12, 0, 0);
    assert CronSchedule.parse("* * * * *").next_after(now)
        == datetime.datetime(2026, 1, 1, 12, 1, 0);
    assert CronSchedule.parse("30 * * * *").next_after(now)
        == datetime.datetime(2026, 1, 1, 12, 30, 0);
    assert CronSchedule.parse("0 9 * * *").next_after(
        datetime.datetime(2026, 1, 1, 8, 0)
    )
        == datetime.datetime(2026, 1, 1, 9, 0, 0);
    assert CronSchedule.parse("0 3 * * 0").next_after(now)
        == datetime.datetime(2026, 1, 5, 3, 0, 0) , "weekday 0 is Monday";
}


test "a cron that fires rarely is found however far away its next run is" {
    # #9031: the old engine scanned 366 days of minutes and raised past that,
    # so a valid Feb 29 schedule crashed boot in a year with no Feb 29 ahead.
    now = datetime.datetime(2026, 9, 17, 10, 0, tzinfo=datetime.timezone.utc);
    leap = CronSchedule.parse("0 0 29 2 *").next_after(now);
    assert leap
        == datetime.datetime(2028, 2, 29, 0, 0, tzinfo=datetime.timezone.utc) , leap;
}


test "a cron the engine cannot honour is refused with the field it got wrong" {
    cases = {
        "* * *": "needs 5 fields",
        "60 * * * *": "minute value 60 is outside 0-59",
        "* 24 * * *": "hour value 24 is outside 0-23",
        "* * 0 * *": "day value 0 is outside 1-31",
        "* * * 13 *": "month value 13 is outside 1-12",
        "* * * * 7": "weekday value 7 is outside 0-6",
        "*/0 * * * *": "minute value 0",
        "5-1 * * * *": "runs backwards",
        "abc * * * *": "'abc'",
        "1-5/2 * * * *": "'5/2'",
        "0 0 30 2 *": "never fires",
        "0 0 31 4,6,9,11 *": "never fires"
    };
    for (expr, expected) in cases.items() {
        message = "";
        try {
            CronSchedule.parse(expr);
        } except ValueError as e {
            message = str(e);
        }
        assert expected in message , f"{expr!r}: {message!r}";
    }
}

test "compute next run and schedule decorator" {
    sched = fresh_scheduler();
    now = datetime.datetime.now();

    # Date
    future = (now + datetime.timedelta(hours=1)).isoformat();
    result = sched._compute_next_run(ScheduleSpec(date=future), now);
    assert result is not None;
    assert abs((result - now).total_seconds() - 3600) < 2;

    # Interval
    result = sched._compute_next_run(ScheduleSpec(interval=60.0), now);
    assert result is not None;
    delta = (result - now).total_seconds();
    assert 59.0 <= delta <= 61.0;

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

class _Records(logging.Handler) {
    def init(self: _Records) {
        super.__init__();
        self.messages: list[str] = [];
    }

    def emit(self: _Records, record: logging.LogRecord) {
        self.messages.append(f"{record.levelname} {record.getMessage()}");
    }
}


test "every @schedule spec the issue lists is refused or warned about by name" {
    # #9031: each of these was accepted, and ran as a busy loop, starved
    # other tasks, was dropped without a word, or crashed boot.
    import from jaclang.runtime.builtin { ScheduleTrigger }
    refused = {
        "spin": (ScheduleSpec(interval=0), "positive number of seconds"),
        "negative": (ScheduleSpec(interval=-5), "positive number of seconds"),
        "nan": (ScheduleSpec(interval=float("nan")), "positive number of seconds"),
        "flag": (ScheduleSpec(interval=True), "positive number of seconds"),
        "empty": (ScheduleSpec(), "needs one of interval, cron or date"),
        "both": (ScheduleSpec(interval=2, cron="* * * * *"), "not interval and cron"),
        "bad_cron": (ScheduleSpec(cron="60 * * * *"), "outside 0-59"),
        "bad_date": (ScheduleSpec(date="tomorrow"), "not an ISO date-time"),
        "dynamic_timed": (
            ScheduleSpec(trigger=ScheduleTrigger.DYNAMIC, interval=5),
            "DYNAMIC schedule takes no interval"
        )
    };
    for (name, (spec, expected)) in refused.items() {
        problems = schedule_problems(spec);
        assert len(problems) == 1 and expected in problems[0] , f"{name}: {problems}";
    }
    for spec in [
        ScheduleSpec(interval=0.3),
        ScheduleSpec(cron="0 0 29 2 *"),
        ScheduleSpec(date="2020-01-01 00:00:00"),
        ScheduleSpec(trigger=ScheduleTrigger.DYNAMIC)
    ] {
        assert schedule_problems(spec) == [] , spec;
    }

    records = _Records();
    log = logging.getLogger("jaclang.server.task_scheduler");
    log.addHandler(records);
    try {
        sched = fresh_scheduler();
        sched.register(
            "expired", lambda { None; }, ScheduleSpec(date="2020-01-01 00:00:00"), False
        );
    } finally {
        log.removeHandler(records);
    }
    assert sched._tasks == [];
    assert any("'expired'" in m and "already passed" in m for m in records.messages) , records.messages;
}


test "an interval too long to schedule is a spec problem, not a crash" {
    # timedelta overflows past about 8.6e13 seconds, and a shorter interval can
    # still put its next run beyond year 9999; either used to escape as an
    # OverflowError from boot validation instead of naming the target.
    for raw in [1e300, 10 ** 400, 8e13] {
        problems = schedule_problems(ScheduleSpec(interval=raw));
        assert len(problems) == 1 and "too long" in problems[0] , f"{raw!r}: {problems}";
    }
    assert schedule_problems(ScheduleSpec(interval=86400 * 365 * 100)) == [];
    tiny = schedule_problems(ScheduleSpec(interval=1e-7));
    assert len(tiny) == 1 and "at least a microsecond" in tiny[0] , tiny;
}


test "the served app refuses to start on a bad @schedule, naming every target" {
    import from tempfile { TemporaryDirectory }
    import from jaclang.server.settings { ServeConfigError }
    import from jaclang.testing.testing { JacTestClient }
    with TemporaryDirectory() as tmpdir {
        client = JacTestClient.from_file(
            str(Path(FIXTURES) / "bad_schedules.jac"), base_path=tmpdir
        );
        try {
            server: any = client.server;
            server.introspector.load();
            message = "";
            try {
                server._validate_or_raise();
            } except ServeConfigError as e {
                message = str(e);
            }
            for expected in [
                "@schedule on 'spin': interval must be a positive number of seconds, got 0",
                "@schedule on 'bad_minute': cron '60 * * * *': minute value 60 is outside 0-59",
                "@schedule on 'SpinWalker': takes one of interval, cron or date, not interval and cron",
                "@schedule on 'huge': interval 1e+300 seconds is too long"
            ] {
                assert expected in message , message;
            }
            assert "good_one" not in message , message;
        } finally {
            client.close();
        }
    }
}
