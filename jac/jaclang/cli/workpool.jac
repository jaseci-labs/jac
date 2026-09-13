import os;

glob WORKER_MEM_BYTES: int = 2 * 1024 * 1024 * 1024,
     MEM_HEADROOM: float = 0.6,
     MAX_AUTO_JOBS: int = 12;

obj WorkPool {
    has items: list[str],
        job: Callable[[dict[(str, any)]], any],
        on_record: Callable[[int, dict[(str, any)]], None],
        jobs: int = 1,
        prerequisites: dict[int, set[int]] = {},
        request_extra: (Callable[[int, str], dict[(str, any)]] | None) = None,
        should_stop: (Callable[[], bool] | None) = None,
        retire: (Callable[[int, int], bool] | None) = None,
        worker_init: (Callable[[], None] | None) = None,
        worker_exit: (Callable[[], None] | None) = None,
        on_dispatch: (Callable[[int, str], None] | None) = None,
        isolate: (set[str] | None) = None,
        rss_log_env: str = "JAC_WORKPOOL_RSS_LOG",
        crash_prefix: str = "jac-work-crash-",
        cursor: int = 0,
        stopping: bool = False,
        kids: list[dict[(str, any)]] postinit,
        crashlogs: list[str] postinit,
        pending: list[int] = [],
        completed: set[int] = set();

    def postinit -> None;
    def run -> None;
    def run_inline -> None;
    def _request(idx: int, path: str, crashlog: str) -> dict[(str, any)];
    def _next_ready -> int | None;
    def _run_job(
        request: dict[str, any], served: int, setup_seconds: float
    ) -> dict[str, any];

    def _pump -> None;
    def _spawn(slot: int) -> dict[(str, any)];
    def _worker_loop(dispatch_fd: int, result_fd: int) -> None;
    def _dispatch(kid: dict[(str, any)]) -> bool;
    def _handle_record(kid: dict[(str, any)], line: str) -> None;
    def _log_footprint(
        kid: dict[(str, any)], record: dict[(str, any)], done: any
    ) -> None;

    def _reap(kid: dict[(str, any)]) -> None;
    def _should_stop -> bool;
    def _shutdown -> None;
}

def pool_available -> bool;

def worker_rss_mb -> int;

def should_retire(served: int, recycle: int, rss_mb: int, rss_cap: int) -> bool;

def env_int(name: str, fallback: int) -> int;

def maybe_malloc_trim -> None;

def default_jobs(worker_bytes: int = 0, avail_bytes: int = 0) -> int;

def jobs_setting(
    command: str, requested: (str | int | None) = None, dev: any = None
) -> str;

def resolve_jobs(
    requested: (str | int | None) = None,
    env_var: str = "JAC_JOBS",
    worker_bytes: int = 0
) -> int;

def forced_serial(requested: (str | int | None) = None) -> bool;
