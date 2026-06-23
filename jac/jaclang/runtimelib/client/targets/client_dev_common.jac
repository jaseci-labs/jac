"""Shared helpers for mobile/react-native dev loops."""

import os;
import shutil;
import socket;
import subprocess;
import from pathlib { Path }
import from typing { Optional }
import from jaclang.cli.console { console }
import from jaclang.runtimelib.client.targets.build_common { SUBPROCESS_TIMEOUT_SHORT }
import from jaclang.runtimelib.watcher { FileChangeEvent }

"""Return a bind error string for a TCP port, or None if bind succeeds."""
def port_bind_error(port: int) -> Optional[str] {
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM);
    try {
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1);
        s.bind(("0.0.0.0", port));
        return None;
    } except OSError as e {
        return str(e);
    } finally {
        s.close();
    }
}

"""Fail fast when a dev port is already bound."""
def assert_port_available(port: int, role: str, failure_hint: str) -> None {
    err = port_bind_error(port);
    if err is None {
        return;
    }
    raise RuntimeError(f"{role} port {port} is already in use ({err}). {failure_hint}");
}

"""Find a bindable port, scanning upward from ``start_port``."""
def resolve_port_or_next_available(
    start_port: int,
    role: str,
    reserved: Optional[list[int]] = None,
    max_scan: int = 200
) -> int {
    reserved_set: set[int] = set(reserved or []);
    candidate = start_port;
    first_err: Optional[str] = None;
    scans = 0;

    while scans <= max_scan {
        if candidate in reserved_set {
            candidate += 1;
            scans += 1;
            continue;
        }
        err = port_bind_error(candidate);
        if err is None {
            if candidate != start_port {
                if first_err is None {
                    console.warning(
                        f"  {role} port {start_port} is reserved; using {candidate}."
                    );
                } else {
                    console.warning(
                        f"  {role} port {start_port} is in use ({first_err}); "
                        f"using {candidate}."
                    );
                }
            }
            return candidate;
        }
        if first_err is None {
            first_err = err;
        }
        candidate += 1;
        scans += 1;
    }

    raise RuntimeError(
        f"Unable to find a free {role} port starting at {start_port} "
        f"(scanned {max_scan + 1} ports)."
    );
}

"""Best-effort adb reverse for the provided port list."""
def setup_android_port_reverse_common(ports: list[int], timeout: int = 5) -> None {
    if not shutil.which("adb") {
        return;
    }
    seen: set[int] = set();
    for port in ports {
        if port <= 0 or port in seen {
            continue;
        }
        seen.add(port);
        cmd = ["adb", "reverse", f"tcp:{port}", f"tcp:{port}"];
        try {
            result = subprocess.run(
                cmd, capture_output=True, text=True, timeout=timeout, check=False
            );
            if result.returncode == 0 {
                console.print(
                    f"  ✔ adb reverse tcp:{port} tcp:{port}", style="success"
                );
            } else {
                err = (result.stderr or "").strip() or "unknown adb error";
                console.warning(f"  ⚠ adb reverse failed for tcp:{port} ({err})");
            }
        } except Exception as e {
            console.warning(f"  ⚠ adb reverse failed for tcp:{port} ({e})");
        }
    }
}

"""Return True if watchdog is importable, else warn once with target-specific text."""
def ensure_watchdog_common(target_name: str) -> bool {
    try {
        import watchdog;
        return True;
    } except ImportError {
        console.warning(
            f"  watchdog not installed — saving .jac files will not refresh {target_name}. "
            "Install with: pip install 'watchdog>=3.0.0' (or add to [dev-dependencies]).",
            style="muted"
        );
        return False;
    }
}

"""Spawn ``jaclang start --no_client`` for local API dev."""
def start_backend_server_common(entry_file: Path, project_dir: Path, port: int) -> any {
    import sys;
    return subprocess.Popen(
        [
            sys.executable,
            "-m",
            "jaclang",
            "start",
            str(entry_file),
            "--port",
            str(port),
            "--no_client"
        ],
        cwd=str(project_dir),
        stdout=None,
        stderr=None
    );
}

# ---------------------------------------------------------------------------
# HMR watchdog callback base
# ---------------------------------------------------------------------------
# The mobile (Capacitor) and react-native (Metro) dev loops both drive a
# ``JacFileWatcher`` from a closure that binds the same three pieces of
# JacClientCompiler state: the compiler, the entry file, and the project
# root. ``JacFileWatcher.add_callback`` needs a callable, so each target
# shapes that closure as an obj with a bound ``on_event(evt)`` method.
# The post-edit work diverges (Vite recompile vs. Metro Fast Refresh),
# so ``on_event`` stays abstract here and each target's handler implements
# it — but the shared bound-state shape lives once in this base, which
# prevents the two handlers from drifting apart as fields are added.
"""Base for mobile/react-native HMR watchdog callbacks.

Subclasses extend this with target-specific fields (e.g. the RN handler
adds ``rn_dir`` + ``entry_module``) and implement ``on_event`` to call
their own recompile + re-stage pipeline.
"""
obj _ClientHmrHandler {
    has compiler: any,
        entry_file: Path,
        project_dir: Path;

    def on_event(evt: FileChangeEvent) -> None abs;
}

# ---------------------------------------------------------------------------
# Dev-loop teardown
# ---------------------------------------------------------------------------
# The mobile and react-native dev loops both block on a long-running child
# (cap run / expo start) with a JacFileWatcher + one or more subprocesses
# (Vite, API backend) running alongside. The teardown sequence — stop
# watcher, terminate each subprocess gracefully then kill, install signal
# handlers so Ctrl+C reaches the parent's `finally` — was duplicated
# verbatim between the two targets. Centralizing it here prevents drift
# and ensures both loops handle SIGINT/SIGTERM identically.
"""Evict stale Jac modules from the JacRuntime hub before a dev recompile.

The client bundle compiler reuses ``JacRuntime.program.mod.hub`` entries;
without evicting changed modules, ``compile_module()`` may return stale JS
and the bundler reloads the same bytes. This is pure hub bookkeeping with
no target-specific logic, so both the Capacitor (Vite) and react-native
(Metro) dev loops call it. Best-effort — compile still proceeds if it fails.
"""
def invalidate_runtime_module_cache(paths: list[str]) -> None {
    try {
        import from jaclang { JacRuntime as Jac }
        program = Jac.program;
        if not program or not program.mod or not program.mod.hub {
            return;
        }
        hub = program.mod.hub;
        norm_targets: set[str] = set();
        for p in paths {
            if not p {
                continue;
            }
            try {
                norm_targets.add(os.path.normcase(str(Path(p).resolve())));
            } except Exception {
                norm_targets.add(os.path.normcase(str(p)));
            }
        }
        if not norm_targets {
            return;
        }
        to_delete: list[str] = [];
        for k in list(hub.keys()) {
            if os.path.normcase(str(k)) in norm_targets {
                to_delete.append(k);
            }
        }
        for k in to_delete {
            del hub[k];
        }
    } except Exception {
        # Cache eviction is best-effort; compile still proceeds if this fails.
        return;
    }
}

"""Stop a ``JacFileWatcher`` if present (best-effort, swallows errors)."""
def stop_dev_watcher(watcher: any) {
    if watcher {
        try {
            watcher.stop();
        } except Exception { }
    }
}

"""Terminate a list of subprocesses gracefully, escalating to ``kill()``.

Each process gets ``terminate()`` + ``wait(timeout)``, falling back to
``kill()`` if the graceful shutdown fails or times out. Best-effort —
exceptions from one process never block the next. ``None`` entries are
skipped so callers can pass optional processes without pre-filtering.
"""
def terminate_dev_processes(
    processes: list[any], timeout: int = SUBPROCESS_TIMEOUT_SHORT
) {
    for p in processes {
        if not p {
            continue;
        }
        try {
            p.terminate();
            p.wait(timeout=timeout);
        } except Exception {
            try {
                p.kill();
            } except Exception { }
        }
    }
}

"""Register SIGINT/SIGTERM handlers that exit cleanly via ``sys.exit(0)``.

Both dev loops block on a long-running child (``cap run`` / ``expo start``).
Without these handlers, Ctrl+C reaches the child but the parent's
``finally`` block never runs, leaking the API server + watcher. The
handler calls ``sys.exit(0)`` so Python unwinds the ``try/finally`` and
the cleanup closure runs.
"""
def install_dev_signal_handlers {
    import signal;
    import sys;
    import from typing { cast }
    def on_signal(signum: int, frame: any) {
        sys.exit(0);
    }
    signal.signal(cast(int, signal.SIGINT), on_signal);
    signal.signal(cast(int, signal.SIGTERM), on_signal);
}
