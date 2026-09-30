import logging;
import os;
import socket;
import threading;
import uuid;
import from jaclang.scale.jobs.queue { JOBS_CHANNEL, JobInfo, JobQueueStore }

glob logger = logging.getLogger(__name__),
     DEFAULT_LEASE_S = 60.0,
     DEFAULT_POLL_S = 1.0,
     DEFAULT_RETENTION_S = 604800.0,
     MAINTAIN_CAP_S = 5.0,
     __all__ = [
         'JobRunner',
         'QueueSpec',
         'PermanentJobError',
         'JobTargetMissing',
         'JobRootMissing',
         'JobTimedOut'
     ];


class PermanentJobError(Exception) {}


class JobTargetMissing(PermanentJobError) {}


class JobRootMissing(PermanentJobError) {}


class JobTimedOut(Exception) {}


obj QueueSpec {
    has name: str,
        concurrency: int = 1,
        lease_s: float = DEFAULT_LEASE_S;
}


obj JobRunner {
    has store: JobQueueStore,
        queues: list[QueueSpec],
        execute: Callable[[JobInfo], None],
        owner: str = "",
        poll_s: float = DEFAULT_POLL_S,
        retention_s: float = DEFAULT_RETENTION_S,
        on_counts: (Callable[[dict[tuple[str, str], int]], None] | None) = None,
        _stop: threading.Event postinit,
        _maint_stop: threading.Event postinit,
        _maint_thread: (threading.Thread | None) postinit,
        _wake: dict[str, threading.Event] postinit,
        _slots: dict[str, threading.BoundedSemaphore] postinit,
        _threads: list[threading.Thread] postinit,
        _attending: dict[str, set[str]] postinit,
        _settled: threading.Condition postinit,
        _maintain_s: float postinit,
        _listening: bool postinit;

    def postinit -> None;
    def start -> None;
    def stop(deadline_s: float = 10.0) -> None;
    def wake(payload: str = "") -> None;
    def run_once(queue: str) -> bool;
    def maintain -> None;
    def attending -> list[str];
    def _spec(queue: str) -> QueueSpec;
    def _attend(job: JobInfo) -> None;
    def _release(job: JobInfo) -> None;
    def _run_claimed(job: JobInfo) -> None;
    def _await_attempt(job: JobInfo) -> (Exception | None);
    def _record(job: JobInfo, error: (Exception | None)) -> None;
    def _dispatch_loop(spec: QueueSpec) -> None;
    def _maintain_loop -> None;
}
