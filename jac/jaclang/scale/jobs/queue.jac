import json;
import logging;
import uuid;
import from datetime { datetime, timezone }

glob logger = logging.getLogger(__name__),
     STATUS_QUEUED = "queued",
     STATUS_RUNNING = "running",
     STATUS_DONE = "done",
     STATUS_FAILED = "failed",
     STATUS_DEAD = "dead",
     STATUS_CANCELLED = "cancelled",
     STATUSES = [
         STATUS_QUEUED,
         STATUS_RUNNING,
         STATUS_DONE,
         STATUS_FAILED,
         STATUS_DEAD,
         STATUS_CANCELLED
     ],
     JOBS_CHANNEL = "jac_jobs",
     DEFAULT_QUEUE = "default",
     DEFAULT_MAX_ATTEMPTS = 3,
     ERROR_MAX_CHARS = 2000,
     JOB_COLUMNS = (
         "id, service, queue, target, args, key, status, run_at, attempts, "
         "max_attempts, timeout_s, lease_owner, lease_until, last_error, "
         "created_at, updated_at"
     ),
     __all__ = [
         'JobInfo',
         'JobQueueStore',
         'enqueue',
         'cancel',
         'job_info',
         'use_store',
         'bind_service',
         'target_name',
         'STATUS_QUEUED',
         'STATUS_RUNNING',
         'STATUS_DONE',
         'STATUS_FAILED',
         'STATUS_DEAD',
         'STATUS_CANCELLED',
         'STATUSES',
         'JOBS_CHANNEL',
         'DEFAULT_QUEUE',
         'DEFAULT_MAX_ATTEMPTS'
     ];


obj JobInfo {
    has id: str,
        queue: str,
        target: str,
        service: str = "",
        args: dict[str, any] = {},
        key: str = "",
        status: str = STATUS_QUEUED,
        run_at: str = "",
        attempts: int = 0,
        max_attempts: int = DEFAULT_MAX_ATTEMPTS,
        timeout_s: float = 0.0,
        lease_owner: str = "",
        lease_until: str = "",
        last_error: str = "",
        created_at: str = "",
        updated_at: str = "";
}


obj JobQueueStore {
    has store: any,
        service: str = "";

    def insert(
        queue: str,
        target: str,
        args: dict[str, any],
        key: str = "",
        run_at: (datetime | None) = None,
        max_attempts: int = DEFAULT_MAX_ATTEMPTS,
        timeout_s: float = 0.0
    ) -> str;

    def claim(queue: str, owner: str, lease_s: float) -> (JobInfo | None);
    def heartbeat(ids: list[str], owner: str, lease_s: float) -> int;
    def complete(id: str, owner: str) -> bool;
    def fail(job: JobInfo, owner: str, error: str, permanent: bool = False) -> str;
    def reap -> list[str];
    def cancel(id: str) -> bool;
    def get(id: str) -> (JobInfo | None);
    def counts -> dict[tuple[str, str], int];
    def prune(retention_s: float) -> int;
}


obj _QueueState {
    has explicit: (JobQueueStore | None) = None,
        service: str = "",
        warned_disabled: bool = False;
}


glob _state: _QueueState = _QueueState();


def use_store(store: (JobQueueStore | None)) -> None;
def bind_service(service: str) -> None;
def target_name(target: any) -> str;

def enqueue(
    target: any,
    args: (dict[str, any] | None) = None,
    key: str = "",
    queue: str = DEFAULT_QUEUE,
    run_at: (datetime | str | None) = None,
    max_attempts: int = DEFAULT_MAX_ATTEMPTS,
    timeout_s: float = 0.0
) -> str;

def cancel(job_id: str) -> bool;
def job_info(job_id: str) -> (JobInfo | None);

def _iso(value: any) -> str;
def _row_to_job(row: tuple[any, ...]) -> JobInfo;
def _parse_run_at(run_at: (datetime | str | None)) -> (datetime | None);
def _configured_queues -> list[str];
def _store_for_request(writable: bool = True) -> JobQueueStore;
def _warn_if_disabled -> None;
