import threading;
import time;
import heapq;
import datetime;
import logging;
import from jaclang.runtime.builtin { ScheduleTrigger }
import from jaclang.server.serving.drain { DrainState }

glob _scheduler_instance: (Scheduler | None) = None,
     logger = logging.getLogger(__name__);

obj ScheduleSpec {
    has date: (str | None) = None,
        interval: (float | None) = None,
        cron: (str | None) = None,
        trigger: ScheduleTrigger = ScheduleTrigger.STATIC;
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
        dynamic_handler: (Callable | None) = None,
        lease: (Callable[[str, int], bool] | None) = None,
        drain: (DrainState | None) = None,
        _in_flight: dict[int, tuple[str, threading.Thread]] = {},
        _flight_lock: threading.Lock = threading.Lock(),
        _overlapping: set[str] = set();

    static def instance -> Scheduler;
    def register(
        name: str, target: Callable, spec: ScheduleSpec, is_walker: bool
    ) -> None;

    def start -> None;
    def start_if_pending -> None;
    def _lease_ttl(spec: ScheduleSpec) -> int;
    def _may_fire(task: ScheduledTask) -> bool;
    def _still_running(task: ScheduledTask) -> bool;
    def _launch(task: ScheduledTask) -> None;
    def _run_tracked(task: ScheduledTask) -> None;
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

    def _parse_cron_next(cron: str, now: datetime.datetime) -> datetime.datetime;
    def _cron_field_matches(
        field: str, value: int, min_val: int, max_val: int
    ) -> bool;

    def _execute(task: ScheduledTask) -> None;
}
