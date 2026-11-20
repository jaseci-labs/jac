import hashlib;
import importlib;
import logging;
import os;
import shutil;
import stat;
import subprocess;
import threading;
import time;
import from enum { StrEnum }
import from pathlib { Path }

glob logger = logging.getLogger(__name__),
     BUILD_TIMEOUT_SECONDS: int = 300,
     RETRY_AFTER_FAILURE_SECONDS: float = 60.0,
     RETRY_AFTER_BUILDING_SECONDS: int = 5,
     LOCK_POLL_SECONDS: float = 0.5,
     NOTE_HIT_EVERY_SECONDS: float = 86400.0,
     SOURCE_SKIP: tuple[str, ...] = (".jac", "node_modules", "__pycache__");

enum ConsoleState(StrEnum) {
    READY = "ready",
    BUILDING = "building",
    FAILED = "failed"
}

obj ConsoleStatus {
    has state: ConsoleState,
        dist_dir: (Path | None) = None,
        error: str = "",
        retry_after: int = RETRY_AFTER_BUILDING_SECONDS;
}

def build_with_jac(src: Path) -> Path;

def package_ui_dir -> Path;

def console_cache_dir -> Path;

def source_digest(source_dir: Path) -> str;

def _compiler_digest -> str;

def _make_owner_writable(top: Path);

def _remove_tree(top: Path) -> None;

obj AdminConsole {
    has source_dir: Path,
        cache_dir: Path,
        build_fn: Callable[[Path], Path] = build_with_jac,
        retry_after: float = RETRY_AFTER_FAILURE_SECONDS,
        _key: str = "",
        _mutex: (threading.Lock | None) = None,
        _worker: (threading.Thread | None) = None,
        _failed_at: float = 0.0,
        _error: str = "",
        _hit_noted_at: float = 0.0;

    def postinit;
    def key -> str;
    def entry_dir -> Path;
    def dist_dir -> Path;
    def is_built -> bool;
    def status -> ConsoleStatus;
    def wait_for(timeout: float) -> ConsoleStatus;
    def _note_hit -> None;
    def _run -> None;
    def _failure_stamp -> Path;
    def _refuse_recent_failure;
    def _build_locked;
}

glob _DEFAULT_CONSOLE: list[AdminConsole] = [],
     _DEFAULT_LOCK: threading.Lock = threading.Lock();

def default_admin_console -> AdminConsole;

def resolve_console(
    staged_dir: Path, console: (AdminConsole | None) = None
) -> (Path | Response);

def console_unavailable(status: ConsoleStatus) -> Response;
