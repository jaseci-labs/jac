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

def build_with_jac(src: Path) -> Path {
    result = subprocess.run(
        [jac_executable(), "build", "--as", "client", "main.jac"],
        cwd=str(src),
        capture_output=True,
        text=True,
        timeout=BUILD_TIMEOUT_SECONDS
    );
    if result.returncode != 0 {
        raise RuntimeError(
            f"jac build exited {result.returncode}: {(result.stderr or result.stdout)[-2000:]}"
        );
    }
    return src / ".jac" / "client" / "dist";
}

def package_ui_dir -> Path {
    return Path(admin_portal.__file__).parent / "ui";
}

def console_cache_dir -> Path {
    return bucket("admin").path();
}

def source_digest(source_dir: Path) -> str {
    h = hashlib.sha256();
    for (dirpath, dirnames, filenames) in os.walk(str(source_dir)) {
        dirnames[:] = sorted(
            [
                d
                for d in dirnames
                if d not in SOURCE_SKIP
            ]
        );
        for name in sorted(filenames) {
            path = Path(os.path.join(str(dirpath), str(name)));
            h.update(path.relative_to(source_dir).as_posix().encode("utf-8"));
            h.update(b"\0");
            h.update(path.read_bytes());
            h.update(b"\0");
        }
    }
    return h.hexdigest();
}

def _compiler_digest -> str {
    try {
        jir = importlib.import_module("jaclang.compiler.driver.jir");
        return str(jir.running_compiler_digest());
    } except ImportError {
        return "";
    }
}

def _make_owner_writable(top: Path) {
    for (dirpath, dirnames, filenames) in os.walk(str(top)) {
        os.chmod(dirpath, os.stat(dirpath).st_mode | stat.S_IRWXU);
        for name in filenames {
            path = os.path.join(dirpath, name);
            os.chmod(path, os.stat(path).st_mode | stat.S_IRUSR | stat.S_IWUSR);
        }
    }
}

def _remove_tree(top: Path) -> None {
    if not top.exists() {
        return;
    }
    try {
        _make_owner_writable(top);
    } except OSError {}
    shutil.rmtree(str(top), ignore_errors=True);
}

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

    def postinit {
        self._mutex = threading.Lock();
    }

    def key -> str {
        if not self._key {
            h = hashlib.sha256();
            h.update(_compiler_digest().encode("utf-8"));
            h.update(b"\0");
            h.update(source_digest(self.source_dir).encode("utf-8"));
            self._key = h.hexdigest()[:24];
        }
        return self._key;
    }

    def entry_dir -> Path {
        return self.cache_dir / self.key();
    }

    def dist_dir -> Path {
        return self.entry_dir() / "dist";
    }

    def is_built -> bool {
        return (self.dist_dir() / "index.html").is_file();
    }

    def status -> ConsoleStatus {
        if self.is_built() {
            self._note_hit();
            return ConsoleStatus(state=ConsoleState.READY, dist_dir=self.dist_dir());
        }
        with self._mutex {
            if self._worker is not None and self._worker.is_alive() {
                return ConsoleStatus(state=ConsoleState.BUILDING);
            }
            if self._failed_at {
                waited = time.monotonic() - self._failed_at;
                if waited < self.retry_after {
                    return ConsoleStatus(
                        state=ConsoleState.FAILED,
                        error=self._error,
                        retry_after=max(1, int(self.retry_after - waited))
                    );
                }
            }
            self._failed_at = 0.0;
            self._error = "";
            self._worker = threading.Thread(
                target=self._run, name="admin-console-build", daemon=True
            );
            self._worker.start();
        }
        return ConsoleStatus(state=ConsoleState.BUILDING);
    }

    def wait_for(timeout: float) -> ConsoleStatus {
        worker = self._worker;
        if worker is not None {
            worker.join(timeout);
        }
        if self.is_built() {
            return ConsoleStatus(state=ConsoleState.READY, dist_dir=self.dist_dir());
        }
        with self._mutex {
            if self._worker is not None and self._worker.is_alive() {
                return ConsoleStatus(state=ConsoleState.BUILDING);
            }
            if self._failed_at {
                return ConsoleStatus(state=ConsoleState.FAILED, error=self._error);
            }
        }
        return ConsoleStatus(state=ConsoleState.BUILDING);
    }

    def _note_hit -> None {
        now = time.monotonic();
        if self._hit_noted_at and now - self._hit_noted_at < NOTE_HIT_EVERY_SECONDS {
            return;
        }
        self._hit_noted_at = now;

        try {
            bucket("admin").note_hit(self.entry_dir());
        } except OSError {}
    }

    def _run -> None {
        try {
            self.cache_dir.mkdir(parents=True, exist_ok=True);
            lock = FileLock(self.cache_dir / f"{self.key()}.lock");
            while not lock.acquire() {
                if self.is_built() {
                    return;
                }
                time.sleep(LOCK_POLL_SECONDS);
            }
            try {
                if not self.is_built() {
                    self._refuse_recent_failure();
                    try {
                        self._build_locked();
                    } except Exception as e {
                        self._failure_stamp().write_text(str(e));
                        raise;
                    }
                }
            } finally {
                lock.release();
            }
        } except Exception as e {
            logger.error(f"Admin console build failed: {e}");
            with self._mutex {
                self._failed_at = time.monotonic();
                self._error = str(e);
            }
        }
    }

    def _failure_stamp -> Path {
        return self.cache_dir / f"{self.key()}.failed";
    }

    def _refuse_recent_failure {
        stamp = self._failure_stamp();
        try {
            if time.time() - stamp.stat().st_mtime < self.retry_after {
                raise RuntimeError(stamp.read_text() or "a recent build failed");
            }
        } except OSError {}
    }

    def _build_locked {
        target = self.entry_dir();
        staging = self.cache_dir
            / f"{self.key()}.tmp.{os.getpid()}.{threading.get_ident()}";
        _remove_tree(staging);
        try {
            src = staging / "src";
            shutil.copytree(
                str(self.source_dir),
                str(src),
                ignore=shutil.ignore_patterns(*SOURCE_SKIP),
                copy_function=shutil.copyfile
            );
            _make_owner_writable(src);
            logger.info("Building the admin console from source...");
            started = time.monotonic();
            built = Path(self.build_fn(src));
            if not (built / "index.html").is_file() {
                raise RuntimeError(f"the build left no index.html in {built}");
            }
            shutil.move(str(built), str(staging / "dist"));
            _remove_tree(src);
            _remove_tree(target);
            os.replace(str(staging), str(target));
            logger.info(f"Admin console built in {time.monotonic() - started:.1f}s");
        } finally {
            _remove_tree(staging);
        }
    }
}

glob _DEFAULT_CONSOLE: list[AdminConsole] = [],
     _DEFAULT_LOCK: threading.Lock = threading.Lock();

def default_admin_console -> AdminConsole {
    with _DEFAULT_LOCK {
        if not _DEFAULT_CONSOLE {
            _DEFAULT_CONSOLE.append(
                AdminConsole(source_dir=package_ui_dir(), cache_dir=console_cache_dir())
            );
        }
        return _DEFAULT_CONSOLE[0];
    }
}

def resolve_console(
    staged_dir: Path, console: (AdminConsole | None) = None
) -> (Path | Response) {
    if (staged_dir / "index.html").is_file() and (staged_dir / ".staged").is_file() {
        return staged_dir;
    }
    status = (console or default_admin_console()).status();
    if status.state == ConsoleState.READY and status.dist_dir is not None {
        return status.dist_dir;
    }
    return console_unavailable(status);
}

def console_unavailable(status: ConsoleStatus) -> Response {
    headers = {"Retry-After": str(status.retry_after)};
    if status.state == ConsoleState.FAILED {
        title = "Admin Portal Build Failed";
        detail = "The admin console could not be built. Check the server logs for details.";
        color = "#ef4444";
    } else {
        title = "Admin Portal Is Being Built";
        detail = "The admin console is being built. This page reloads when it is ready.";
        color = "#e2e8f0";
    }
    refresh = f'<meta http-equiv="refresh" content="{status.retry_after}">';
    return HTMLResponse(
        content=f'''<!DOCTYPE html>
<html>
<head><title>{title}</title>{refresh}</head>
<body style="background:#0f172a;color:#e2e8f0;font-family:system-ui;display:flex;justify-content:center;align-items:center;min-height:100vh;margin:0">
<div style="text-align:center">
<h1 style="color:{color}">{title}</h1>
<p>{detail}</p>
</div>
</body>
</html>''',
        status_code=503,
        headers=headers
    );
}
