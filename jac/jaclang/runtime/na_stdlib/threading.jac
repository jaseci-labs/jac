import time;

import from _threading_native {
    th_alloc,
    th_free,
    th_spawn,
    th_detach,
    th_join,
    th_at_exit
}

obj:pub Lock {
    has _mutex: int = 0;

    def init;
    def drop;
    def __enter__ -> Lock;
    def __exit__(exc_type: any, exc: any, tb: any) -> bool;
    def acquire(blocking: bool = True, timeout: float = -1.0) -> bool;
    def release -> None;
}


obj:pub Event {
    has _lock: Lock = Lock(),
        _flag: bool = False,
        _generation: int = 0;

    def is_set -> bool;
    def set -> None;
    def clear -> None;
    def `wait(timeout: (float | None) = None) -> bool;
}


obj:pub Thread {
    has target: Callable[[], any],
        daemon: bool = False,
        name: str = "",
        _task_id: int = 0,
        _started: bool = False,
        _alive: bool = False;

    def init(
        target: Callable[[], any],
        daemon: (bool | None) = None,
        name: (str | None) = None,
    );

    def start -> None;
    def is_alive -> bool;
    def join(timeout: (float | None) = None) -> None;
}


glob _TASKS: dict[int, Thread] = {},
     _JOINABLE: dict[int, int] = {},
     _TASKS_LOCK: Lock = Lock(),
     _NEXT_TASK_ID: int = 1,
     _EXIT_HOOK_SET: bool = False;

def _thread_entry(task_id: int) -> int;


def _join_unfinished -> None;
