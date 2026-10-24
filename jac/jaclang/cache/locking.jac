import errno;
import os;
import from pathlib { Path }

obj FileLock {
    has path: Path,
        handle: int = -1;

    def acquire(create: bool = True) -> bool;
    def release;
}
