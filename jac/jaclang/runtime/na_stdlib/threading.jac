"""Native threading primitives backed by the platform POSIX thread API."""

import time;

obj Lock {
    has _mutex: int = 0;

    def init();
    def __enter__ -> Lock;
    def __exit__(exc_type: any, exc: any, tb: any) -> bool;
    def acquire(blocking: bool = True, timeout: float = -1.0) -> bool;
    def release() -> None;
    def __del__() -> None;
}

obj Event {
    has _lock: Lock = Lock(),
        _flag: bool = False;

    def is_set() -> bool;
    def set() -> None;
    def clear() -> None;
    def `wait(timeout: (float | None) = None) -> bool;
}

obj Thread {
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
    def start() -> None;
    def is_alive() -> bool;
    def join(timeout: (float | None) = None) -> None;
}
