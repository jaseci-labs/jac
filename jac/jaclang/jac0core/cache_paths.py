"""Single source of truth for jac's global on-disk cache root.

Pure Python with no jac dependencies, so it is importable during bootstrap —
before the jac0core ``.jac`` modules have been transpiled. Both the bootstrap
bytecode cache (``meta_importer``) and the JIR module cache
(``jaclang.compiler.driver.jir``) derive their directories from here, so the
platform-resolution logic lives in exactly one place.

This bootstrap-safe module owns global cache directories, file locking, and atomic publication.
The per-module cache locations (``jir/modules/``, holding every product of
a module including its native interface and object) are project-aware and
therefore resolved in ``jaclang.compiler.driver.jir`` via
``get_module_cache_path(source_path)``, which falls back to the project's
``.jac/cache`` when inside a project.

Platform roots:
    Linux:   ~/.cache/jac/jir/             ($XDG_CACHE_HOME honored)
    macOS:   ~/Library/Caches/jac/jir/
    Windows: %LOCALAPPDATA%/jac/cache/jir/
"""

import errno
import os
import time
import secrets
import sys
from pathlib import Path


def get_jir_cache_dir() -> Path:
    """Return the platform-appropriate global cache directory for JIR files."""
    if sys.platform == "win32":
        base = Path(os.environ.get("LOCALAPPDATA", Path.home() / "AppData" / "Local"))
        return base / "jac" / "cache" / "jir"
    elif sys.platform == "darwin":
        return Path.home() / "Library" / "Caches" / "jac" / "jir"
    else:
        xdg = os.environ.get("XDG_CACHE_HOME")
        base = Path(xdg) if xdg else (Path.home() / ".cache")
        return base / "jac" / "jir"


def get_bootstrap_cache_dir() -> Path:
    """Global cache dir for marshalled jac0core bootstrap bytecode."""
    return get_jir_cache_dir() / "bootstrap"


def get_app_cache_dir() -> Path:
    """Global cache dir for materialized app bundles (.jab), content-keyed."""
    return get_jir_cache_dir().parent / "apps"


class FileLock:
    """Cross-process file lock usable before the Jac importer is initialized.

    The lock file is persistent: removing it can split waiters across inodes.
    Each acquisition opens its own descriptor, including in sibling threads.
    """

    def __init__(self, path: str | Path, timeout: float = 1800.0) -> None:
        self.path = Path(path)
        self.timeout = timeout
        self.handle = -1

    def acquire(self) -> None:
        if self.handle != -1:
            raise RuntimeError("FileLock is not reentrant")
        self.path.parent.mkdir(parents=True, exist_ok=True)
        handle = os.open(self.path, os.O_CREAT | os.O_RDWR, 0o600)
        try:
            if os.name == "nt" and os.fstat(handle).st_size == 0:
                os.write(handle, b"0")
            deadline = time.monotonic() + self.timeout
            while True:
                try:
                    if os.name == "nt":
                        import msvcrt
                        os.lseek(handle, 0, os.SEEK_SET)
                        msvcrt.locking(handle, msvcrt.LK_NBLCK, 1)
                    else:
                        import fcntl
                        fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
                    break
                except OSError as exc:
                    if exc.errno not in (errno.EACCES, errno.EAGAIN):
                        raise
                    if time.monotonic() >= deadline:
                        raise TimeoutError(f"Timed out waiting for {self.path}") from exc
                    time.sleep(0.05)
        except BaseException:
            os.close(handle)
            raise
        self.handle = handle

    def release(self) -> None:
        if self.handle != -1:
            os.close(self.handle)
            self.handle = -1

    def __enter__(self) -> "FileLock":
        self.acquire()
        return self

    def __exit__(self, exc_type: object, exc_value: object, traceback: object) -> None:
        self.release()


def atomic_write(path: str | Path, data: bytes, mode: int | None = None) -> None:
    """Publish complete bytes on a new inode; open readers retain the old image.

    Callers that merge existing contents must hold FileLock across their read
    and this replacement. Existing permissions are preserved unless mode is
    explicit; new files use ordinary 0666 permissions filtered by the umask.
    """
    destination = Path(path)
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary: Path | None = None
    try:
        # O_EXCL protects the randomly named staging file; os.open applies the
        # process umask without reading/changing that process-global setting.
        while True:
            candidate = destination.parent / f".{destination.name}.{secrets.token_hex(16)}.tmp"
            try:
                handle = os.open(candidate, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o666)
                temporary = candidate
                break
            except FileExistsError:
                continue
        with os.fdopen(handle, "wb") as output:
            output.write(data)
        if mode is None:
            try:
                mode = destination.stat().st_mode & 0o777
            except FileNotFoundError:
                pass
        if mode is not None:
            temporary.chmod(mode)
        os.replace(temporary, destination)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
