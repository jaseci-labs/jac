"""Single source of truth for jac's global on-disk cache root.

Pure Python with no jac dependencies, so it is importable during bootstrap,
before the jac0core ``.jac`` modules have been transpiled. Everything that
writes under the machine-wide cache derives its directory from here: the
bootstrap bytecode cache (``meta_importer``) and the JIR module cache
(``jaclang.compiler.driver.jir``) directly, every other bucket through the
``jaclang.cache`` authority, which wraps this rule rather than restating it.
The fused launcher (``jaclang/dist/fused/materialize.jac``) runs before
CPython exists and carries an equivalent copy; ``tests/cache`` holds the two
to the same answers.

The root rule::

    JAC_CACHE_HOME            an explicit root (``~`` expands)
    XDG_CACHE_HOME/jac        the XDG base, on every platform when set
    Linux:   ~/.cache/jac
    macOS:   ~/Library/Caches/jac
    Windows: %LOCALAPPDATA%/jac/cache

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
import hashlib
import json
import os
import time
import secrets
import sys
from pathlib import Path


def get_cache_home() -> Path:
    """Return the root of jac's machine-wide cache (see the module docstring)."""
    explicit = os.environ.get("JAC_CACHE_HOME", "").strip()
    if explicit:
        return Path(os.path.expanduser(explicit))
    xdg = os.environ.get("XDG_CACHE_HOME", "").strip()
    if xdg:
        return Path(xdg) / "jac"
    if sys.platform == "win32":
        base = Path(os.environ.get("LOCALAPPDATA", Path.home() / "AppData" / "Local"))
        return base / "jac" / "cache"
    if sys.platform == "darwin":
        return Path.home() / "Library" / "Caches" / "jac"
    return Path.home() / ".cache" / "jac"


def get_jir_cache_dir() -> Path:
    """Return the global cache directory for JIR files."""
    return get_cache_home() / "jir"


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


# File content digests: the one authority for "sha256 of this file". A digest
# is memoized for the process and recorded in a ledger shared across
# processes (one shard per directory under ``jir/digests``), keyed by the
# file's identity: inode, size, and nanosecond mtime and ctime. ctime moves on
# every write and cannot be set back, so a same-size rewrite that restores its
# mtime still misses. A digest is only reused when the file was already stable
# when it was hashed (the racy-entry rule git uses), so a file edited within
# one timestamp tick is always read again.

_DIGEST_RACY_NS = 2_000_000_000
_DIGEST_SHARD_CAP = 4096
_digest_memo: dict[str, tuple[tuple[int, int, int, int], str]] = {}
_digest_shards: dict[str, dict[str, list]] = {}
_digest_dirty: set[str] = set()
_digest_flush_armed: list[bool] = []


def get_digest_ledger_dir() -> Path:
    """Directory of the cross-process file-digest ledger."""
    return get_jir_cache_dir() / "digests"


def file_identity(path: str | Path) -> tuple[int, int, int, int] | None:
    """The (inode, size, mtime_ns, ctime_ns) identity of a file, or None."""
    try:
        st = os.stat(path)
    except OSError:
        return None
    return (st.st_ino, st.st_size, st.st_mtime_ns, st.st_ctime_ns)


def _digest_shard(name: str) -> dict[str, list]:
    entries = _digest_shards.get(name)
    if entries is None:
        entries = {}
        try:
            raw = json.loads((get_digest_ledger_dir() / f"{name}.json").read_text())
            if isinstance(raw, dict):
                entries = raw
        except (OSError, ValueError):
            pass
        _digest_shards[name] = entries
    return entries


def _hash_file(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def file_sha256(path: str | Path) -> str:
    """The sha256 hex digest of a file's contents (raises OSError like open)."""
    real = os.path.realpath(path)
    ident = file_identity(real)
    if ident is None:
        return _hash_file(real)
    known = _digest_memo.get(real)
    if known is not None and known[0] == ident:
        return known[1]
    name = hashlib.sha256(os.path.dirname(real).encode()).hexdigest()[:16]
    rec = _digest_shard(name).get(real)
    if isinstance(rec, list) and len(rec) == 5 and tuple(rec[:4]) == ident:
        _digest_memo[real] = (ident, str(rec[4]))
        return str(rec[4])
    digest = _hash_file(real)
    if time.time_ns() - max(ident[2], ident[3]) > _DIGEST_RACY_NS:
        _digest_memo[real] = (ident, digest)
        _digest_shard(name)[real] = [*ident, digest]
        _digest_dirty.add(name)
        if not _digest_flush_armed:
            import atexit

            atexit.register(flush_file_digests)
            _digest_flush_armed.append(True)
    return digest


def flush_file_digests() -> None:
    """Merge the digests this process recorded into the shared ledger."""
    if not _digest_dirty:
        return
    base = get_digest_ledger_dir()
    for name in sorted(_digest_dirty):
        path = base / f"{name}.json"
        merged: dict[str, list] = {}
        try:
            with FileLock(base / ".lock", timeout=5.0):
                try:
                    on_disk = json.loads(path.read_text())
                    if isinstance(on_disk, dict):
                        merged.update(on_disk)
                except (OSError, ValueError):
                    pass
                merged.update(_digest_shards.get(name, {}))
                if len(merged) > _DIGEST_SHARD_CAP:
                    merged = dict(list(merged.items())[-_DIGEST_SHARD_CAP:])
                atomic_write(path, json.dumps(merged).encode())
        except (OSError, TimeoutError):
            pass
    _digest_dirty.clear()


def forget_file_digests() -> None:
    """Drop this process's digest memo (the shared ledger is kept)."""
    _digest_memo.clear()
    _digest_shards.clear()
    _digest_dirty.clear()
