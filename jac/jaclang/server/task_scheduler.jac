import threading;
import time;
import heapq;
import datetime;
import logging;
import math;
import os;
import from jaclang.runtime.builtin { ScheduleTrigger }

glob _scheduler_instance: (Scheduler | None) = None,
     logger = logging.getLogger(__name__),
     CRON_FIELDS: list[tuple[str, int, int]] = [
         ("minute", 0, 59),
         ("hour", 0, 23),
         ("day", 1, 31),
         ("month", 1, 12),
         ("weekday", 0, 6)
     ],
     MONTH_DAYS: dict[int, int] = {
         1: 31,
         2: 29,
         3: 31,
         4: 30,
         5: 31,
         6: 30,
         7: 31,
         8: 31,
         9: 30,
         10: 31,
         11: 30,
         12: 31
     };

def schedule_problems(spec: ScheduleSpec) -> list[str];
def next_interval_run(seconds: float, now: datetime.datetime) -> datetime.datetime;
def _cron_values(expr: str, text: str, label: str, lo: int, hi: int) -> set[int];
def _cron_number(expr: str, text: str, label: str, lo: int, hi: int) -> int;

def tick_of(when: datetime.datetime) -> int;
def schedule_namespace(module_name: str) -> str;

obj ScheduleSpec {
    has date: (str | None) = None,
        interval: (float | None) = None,
        cron: (str | None) = None,
        trigger: ScheduleTrigger = ScheduleTrigger.STATIC;
}

obj CronSchedule {
    has minutes: set[int],
        hours: set[int],
        days: set[int],
        months: set[int],
        weekdays: set[int];

    static def parse(expr: str) -> CronSchedule;
    def next_after(now: datetime.datetime) -> datetime.datetime;
}

obj ScheduledTask {
    has name: str,
        target: Callable,
        spec: ScheduleSpec,
        is_walker: bool,
        next_run: (datetime.datetime | None) = None,
        last_run: (datetime.datetime | None) = None;
}

obj Scheduler {
    has _tasks: list[ScheduledTask] = [],
        _thread: (threading.Thread | None) = None,
        _running: bool = False,
        _stop_event: (threading.Event | None) = None,
        _done_event: (threading.Event | None) = None,
        claim: (Callable[[str, int], bool] | None) = None,
        namespace: str = "",
        _failing_claims: set[str] = set();

    static def instance -> Scheduler;
    def register(
        name: str, target: Callable, spec: ScheduleSpec, is_walker: bool
    ) -> None;

    def start -> None;
    def start_if_pending -> None;
    def _may_fire(task: ScheduledTask, due: datetime.datetime) -> bool;
    def stop -> None;
    def `wait -> None;
    def has_pending -> bool;
    def _run_loop -> None;
    def _pick_up_new_tasks(heap: list[tuple[float, int, ScheduledTask]]) -> None;
    def _compute_next_run(
        spec: ScheduleSpec, now: datetime.datetime
    ) -> (datetime.datetime | None);

    def _compute_date(
        date_str: str, now: datetime.datetime
    ) -> (datetime.datetime | None);

    def _execute(task: ScheduledTask) -> None;
}
