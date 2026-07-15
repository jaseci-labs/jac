"""Machine-wide run directory for the byLLM model daemon.

Unlike the scale orchestrator (whose pidfiles/logs live in a *project-relative*
`.jac/run` / `.jac/logs`), the model daemon is machine-wide -- one daemon per
user, shared across all `jac` invocations. Layout (XDG-aware):

    $JAC_SERVE_DIR                     (override)
    else $XDG_RUNTIME_DIR/jac-serve    (Linux, if set -- per-UID)
    else ~/.cache/jac/serve            (fallback; sibling of ~/.cache/jac/models)

      daemon.pid  daemon.port  daemon.lock
      runners/<alias>.pid
      logs/daemon.log  logs/runner-<alias>.log
"""

import os;
import re;
import from pathlib { Path }

"""Machine-wide runtime directory (created on demand).

Prefers $JAC_SERVE_DIR, then $XDG_RUNTIME_DIR/jac-serve, then ~/.cache/jac/serve,
falling through on any unwritable candidate (some $XDG_RUNTIME_DIR values are not
writable by the running user).
"""
def serve_runtime_dir -> Path {
    home_cache = Path(os.path.expanduser("~")) / ".cache" / "jac" / "serve";
    candidates: list = [];
    override = os.environ.get("JAC_SERVE_DIR");
    if override {
        candidates.append(Path(override).expanduser());
    } else {
        xdg = os.environ.get("XDG_RUNTIME_DIR");
        if xdg {
            candidates.append(Path(xdg) / "jac-serve");
        }
    }
    candidates.append(home_cache);
    for cand in candidates {
        try {
            cand.mkdir(parents=True, exist_ok=True);
            return cand;
        } except Exception {}
    }
    home_cache.mkdir(parents=True, exist_ok=True);
    return home_cache;
}

"""Filesystem-safe token for an alias (used in pidfile/log names)."""
def _safe(alias: str) -> str {
    return re.sub("[^A-Za-z0-9._-]", "_", alias);
}

def daemon_pidfile -> Path {
    return serve_runtime_dir() / "daemon.pid";
}

def daemon_portfile -> Path {
    return serve_runtime_dir() / "daemon.port";
}

def daemon_lockfile -> Path {
    return serve_runtime_dir() / "daemon.lock";
}

def _runners_dir -> Path {
    d = serve_runtime_dir() / "runners";
    d.mkdir(parents=True, exist_ok=True);
    return d;
}

def runner_pidfile(alias: str) -> Path {
    return _runners_dir() / f"{_safe(alias)}.pid";
}

def _logs_dir -> Path {
    d = serve_runtime_dir() / "logs";
    d.mkdir(parents=True, exist_ok=True);
    return d;
}

def daemon_log -> Path {
    return _logs_dir() / "daemon.log";
}

def runner_log(alias: str) -> Path {
    return _logs_dir() / f"runner-{_safe(alias)}.log";
}
