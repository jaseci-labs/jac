"""Tests for the built-in scheduler engine."""

import datetime;
import threading;
import time;
import from pathlib { Path }
import from jaclang { JacRuntime as Jac }
import from jaclang.runtimelib.scheduler { Scheduler, ScheduleSpec, ScheduledTask }

glob FIXTURES = str(Path(__file__).parent / "fixtures");

def fresh_scheduler -> Scheduler {
    return Scheduler();
}

test "task registration and scheduler lifecycle" {
    sched = fresh_scheduler();
    assert not sched.has_pending();

    # Future date registers successfully
    future = (datetime.datetime.now() + datetime.timedelta(hours=1)).isoformat();
    sched.register("future_task", lambda : None , ScheduleSpec(date=future), False);
    assert len(sched._tasks) == 1;
    assert sched._tasks[0].name == "future_task";
    assert sched._tasks[0].next_run is not None;

    # Past date is skipped
    past = (datetime.datetime.now() - datetime.timedelta(hours=1)).isoformat();
    sched.register("past_task", lambda : None , ScheduleSpec(date=past), False);
    assert len(sched._tasks) == 1;

    # Invalid date is skipped
    sched.register("bad_date", lambda : None , ScheduleSpec(date="not-a-date"), False);
    assert len(sched._tasks) == 1;

    # Multiple task types
    sched.register("t_interval", lambda : None , ScheduleSpec(interval=60), False);
    sched.register("t_cron", lambda : None , ScheduleSpec(cron="* * * * *"), False);
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
    assert sched._parse_cron_next("* * * * *", now) == datetime.datetime(
        2026, 1, 1, 12, 1, 0
    );
    assert sched._parse_cron_next("30 * * * *", now) == datetime.datetime(
        2026, 1, 1, 12, 30, 0
    );
    now2 = datetime.datetime(2026, 1, 1, 8, 0, 0);
    assert sched._parse_cron_next("0 9 * * *", now2) == datetime.datetime(
        2026, 1, 1, 9, 0, 0
    );

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

    # DYNAMIC raises NotImplementedError
    try {
        @schedule(interval=10, trigger=ScheduleTrigger.DYNAMIC)
        def dynamic_fn { }
        assert False , "Expected NotImplementedError";
    } except NotImplementedError as e {
        assert "jac-scale" in str(e).lower();
    }

    # _execute catches exceptions gracefully
    def bad_fn {
        raise RuntimeError("boom") ;
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
    import from jaclang.runtimelib.server { ModuleIntrospector }
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
    introspector = ModuleIntrospector(module_name="scheduled_tasks", base_path=FIXTURES);
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
        "interval_function",
        module.interval_function,
        ScheduleSpec(interval=0.2),
        False
    );

    # Bad function to verify error recovery
    def bad_fn {
        raise RuntimeError("deliberate error") ;
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
