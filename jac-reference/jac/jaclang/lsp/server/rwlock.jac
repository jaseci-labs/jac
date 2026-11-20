import threading;
import from contextlib { contextmanager }

obj ReadWriteLock {
    has _cond: threading.Condition postinit,
        _readers: int = 0,
        _writer: bool = False,
        _writers_waiting: int = 0;

    def postinit -> None;
    def acquire_read -> None;
    def release_read -> None;
    def acquire_write -> None;
    def release_write -> None;
    @contextmanager
    def read_lock -> None;

    @contextmanager
    def write_lock -> None;
}
