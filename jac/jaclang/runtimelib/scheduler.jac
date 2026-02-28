"""Scheduler for walkers and functions."""
import threading;
import time;
import heapq;
import datetime;
import logging;
import from collections.abc { Callable }
import from jaclang.runtimelib.builtin { ScheduleTrigger }

glob _scheduler_instance: (Scheduler | None) = None,
     logger = logging.getLogger(__name__);

"""Holds the configuration for a scheduled task."""
obj ScheduleSpec {
    has date: (str | None) = None,
        interval: (float | None) = None,
        cron: (str | None) = None,
        trigger: ScheduleTrigger = ScheduleTrigger.STATIC;
}

"""One registered scheduled task."""
obj ScheduledTask {
    has name: str,
        target: Callable,
        spec: ScheduleSpec,
        is_walker: bool,
        next_run: (datetime.datetime | None) = None,
        last_run: (datetime.datetime | None) = None;
}

"""Background scheduler engine (singleton)."""
obj Scheduler {
    has _tasks: list[ScheduledTask] = [],
        _thread: (threading.Thread | None) = None,
        _running: bool = False,
        _stop_event: (threading.Event | None) = None,
        _done_event: (threading.Event | None) = None;

    static def instance -> Scheduler;
    def register(
        name: str, target: Callable, spec: ScheduleSpec, is_walker: bool
    ) -> None;

    def start -> None;
    def stop -> None;
    def wait -> None;
    def has_pending -> bool;
    def _run_loop -> None;
    def _pick_up_new_tasks(heap: list) -> None;
    def _compute_next_run(
        spec: ScheduleSpec, now: datetime.datetime
    ) -> (datetime.datetime | None);

    def _compute_date(
        date_str: str, now: datetime.datetime
    ) -> (datetime.datetime | None);

    def _parse_cron_next(cron: str, now: datetime.datetime) -> datetime.datetime;
    def _cron_field_matches(field: str, value: int, min_val: int, max_val: int) -> bool;
    def _execute(task: ScheduledTask) -> None;
}
