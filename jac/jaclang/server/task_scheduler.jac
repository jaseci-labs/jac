import threading;
import time;
import heapq;
import datetime;
import json;
import logging;
import math;
import os;
import socket;
import uuid;
import from jaclang.runtime.builtin { ScheduleTrigger }
import from jaclang.server.serving.drain { DrainState }

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

obj RunOutcome {
    has task: str,
        tick: datetime.datetime,
        worker: str,
        status: str,
        duration: float = 0.0,
        reason: str = "",
        error: str = "";
}

obj Scheduler {
    has _tasks: list[ScheduledTask] = [],
        _thread: (threading.Thread | None) = None,
        _running: bool = False,
        _stop_event: (threading.Event | None) = None,
        _done_event: (threading.Event | None) = None,
        claim: (Callable[[str, int], bool] | None) = None,
        namespace: str = "",
        _failing_claims: set[str] = set(),
        hold: (Callable[[str, int, str], bool] | None) = None,
        release: (Callable[[str, str], bool] | None) = None,
        hold_ttl: int = 30,
        _owner: str = "",
        drain: (DrainState | None) = None,
        _in_flight: dict[int, tuple[str, threading.Thread]] = {},
        _flight_lock: threading.Lock = threading.Lock(),
        _overlapping: set[str] = set(),
        _listeners: dict[str, Callable[[RunOutcome], None]] = {},
        record: (Callable[[str, str], None] | None) = None,
        recall: (Callable[[str], (str | None)] | None) = None,
        _last: dict[str, dict[str, any]] = {};

    static def instance -> Scheduler;
    def register(
        name: str, target: Callable, spec: ScheduleSpec, is_walker: bool
    ) -> None;

    def on_run(name: str, listener: Callable[[RunOutcome], None]) -> None;
    def start -> None;
    def start_if_pending -> None;
    def _tick(task: ScheduledTask, due: datetime.datetime) -> None;
    def _claim_key(task: ScheduledTask) -> str;
    def _may_fire(task: ScheduledTask, due: datetime.datetime) -> bool;
    def _run_key(task: ScheduledTask) -> str;
    def _hold_owner -> str;
    def _take_hold(task: ScheduledTask) -> bool;
    def _hold_run(task: ScheduledTask) -> bool;
    def _keep_hold(task: ScheduledTask, beat: threading.Event) -> None;
    def _release_run(task: ScheduledTask) -> None;
    def _still_running(task: ScheduledTask) -> bool;
    def _launch(task: ScheduledTask, due: datetime.datetime) -> None;
    def _run_tracked(task: ScheduledTask, due: datetime.datetime) -> None;
    def _worker -> str;
    def _skip(task: ScheduledTask, due: datetime.datetime, reason: str) -> None;
    def _report(outcome: RunOutcome) -> None;
    def _last_key(name: str) -> str;
    def _remember(outcome: RunOutcome) -> None;
    def last_run_of(name: str) -> (dict[str, any] | None);
    def schedules -> list[dict[str, any]];
    def stop(timeout: (float | None) = None) -> None;
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

    def _execute(task: ScheduledTask) -> str;
}
