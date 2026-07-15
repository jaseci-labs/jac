"""Client side of the model daemon.

`resolve_local_model` turns a `local:<alias>` model into ordinary OpenAI-
compatible routing data (base_url + stamped ctx_window / tool support), lazily
autostarting the daemon. It NEVER downloads weights -- an un-pulled model raises
an actionable error (only `jac model pull` / `jac model run` fetch).
"""

import os;
import time;
import subprocess;
import shutil;
import urllib.request;

import from jaclang.byllm.serve.manifest { resolve_entry, to_cache_spec }
import from jaclang.byllm.serve.paths {
    daemon_portfile, daemon_lockfile, daemon_log
}
import from jaclang.byllm.model_cache { is_downloaded }
import from jaclang.byllm.config_loader { get_byllm_config }

"""Absolute path to the jac binary for re-invocation (JAC_EXECUTABLE, then PATH)."""
def _jac_executable -> str {
    return os.environ.get("JAC_EXECUTABLE", "") or shutil.which("jac") or "jac";
}

"""Recorded daemon port, or None if no daemon has registered one."""
def _read_portfile -> int | None {
    try {
        p = daemon_portfile();
        if not p.exists() {
            return None;
        }
        return int(p.read_text().strip());
    } except Exception {
        return None;
    }
}

"""True if a daemon answers /healthz on `port`."""
def _daemon_healthy(port: int) -> bool {
    try {
        with urllib.request.urlopen(f"http://127.0.0.1:{port}/healthz", timeout=1) as resp {
            return resp.status == 200;
        }
    } except Exception {
        return False;
    }
}

"""Spawn a detached `jac model serve` and wait for it to become healthy."""
def _spawn_daemon(serve_cfg: dict) -> int {
    argv = [_jac_executable(), "model", "serve"];
    sp = int(serve_cfg.get("serve_port", 0));
    if sp > 0 {
        argv += ["--serve_port", str(sp)];
    }
    logf = open(daemon_log(), "ab");
    proc = subprocess.Popen(
        argv, stdout=logf, stderr=logf, stdin=subprocess.DEVNULL,
        start_new_session=True
    );
    deadline = time.time() + 90.0;
    while time.time() < deadline {
        if proc.poll() is not None {
            raise RuntimeError(
                f"model daemon exited during startup; see {daemon_log()}"
            );
        }
        port = _read_portfile();
        if port and _daemon_healthy(port) {
            return port;
        }
        time.sleep(0.2);
    }
    raise RuntimeError(f"model daemon did not become healthy in 90s; see {daemon_log()}");
}

"""Return a healthy daemon's port, autostarting one under a cross-process lock."""
def ensure_daemon -> int {
    serve_cfg = get_byllm_config().get_serve_config();
    port = _read_portfile();
    if port and _daemon_healthy(port) {
        return port;
    }
    lockf = open(daemon_lockfile(), "w");
    try {
        try {
            import fcntl;
            fcntl.flock(lockf, fcntl.LOCK_EX);
        } except Exception {}
        # Re-check under the lock (another process may have just started it).
        port = _read_portfile();
        if port and _daemon_healthy(port) {
            return port;
        }
        if not bool(serve_cfg.get("autostart", True)) {
            raise RuntimeError(
                "byLLM model daemon is not running and [byllm.serve].autostart is "
                "false. Start it with: jac model serve"
            );
        }
        return _spawn_daemon(serve_cfg);
    } finally {
        try {
            lockf.close();
        } except Exception {}
    }
}

"""Resolve `local:<alias>` to OpenAI-compatible routing data via the daemon.

Raises ValueError for an unknown alias and RuntimeError (with a `jac model pull`
hint) when the weights are not downloaded. Never downloads.
"""
def resolve_local_model(alias: str, user_ctx_window: int = 0) -> dict {
    model_entry = resolve_entry(alias);
    spec = to_cache_spec(model_entry);
    if not is_downloaded(alias, spec) {
        raise RuntimeError(
            f"Local model '{alias}' is not downloaded. Run: jac model pull {alias}"
        );
    }
    port = ensure_daemon();
    ctx = int(user_ctx_window) if int(user_ctx_window) > 0
        else int(model_entry.get("ctx_window", 0));
    return {
        "served_model": f"openai/{alias}",
        "base_url": f"http://127.0.0.1:{port}/v1",
        "api_key": "sk-local",
        "ctx_window": ctx,
        "supports_native_tools": bool(model_entry.get("supports_native_tools", False))
    };
}
