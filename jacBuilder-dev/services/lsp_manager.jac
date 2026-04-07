"""LSP Manager - Manages per-project jac lsp subprocess lifecycle."""

import os;
import sys;
import json;
import subprocess;
import signal;
import time;
import from threading {Lock, Thread}
import from pathlib {Path}
import from collections {deque}

glob _lsp_registry: dict = {};
glob _lsp_lock = Lock();

"""Build a stable key for LSP registry entries."""
def _lsp_key(user_id: str, project_id: str) -> str {
    return str(user_id) + "::" + str(project_id);
}

"""Find jac command. Returns a list for subprocess calls.
For PyInstaller frozen apps, uses sidecar's --jac-cli mode.
"""
def _find_jac_cmd() -> list {
    # PyInstaller frozen app — use sidecar's multi-mode CLI
    if getattr(sys, 'frozen', False) {
        return [sys.executable, "--jac-cli"];
    }
    bin_dir = "Scripts" if sys.platform == "win32" else "bin";
    jac_name = "jac.exe" if sys.platform == "win32" else "jac";
    candidates = [
        str(Path.home() / ".jacvenv" / bin_dir / jac_name)
    ];
    venv = os.environ.get("VIRTUAL_ENV", "");
    if venv {
        candidates.append(os.path.join(venv, bin_dir, jac_name));
    }
    for path in candidates {
        if os.path.exists(path) {
            return [path];
        }
    }
    import shutil;
    result = shutil.which("jac");
    if result {
        return [result];
    }
    raise FileNotFoundError("Could not find 'jac' binary.");
}

"""Find the activate script for the virtualenv containing jac."""
def _find_activate_script() -> str {
    bin_dir = "Scripts" if sys.platform == "win32" else "bin";
    activate_name = "activate.bat" if sys.platform == "win32" else "activate";
    jacvenv_activate = str(Path.home() / ".jacvenv" / bin_dir / activate_name);
    if os.path.exists(jacvenv_activate) {
        return jacvenv_activate;
    }
    venv = os.environ.get("VIRTUAL_ENV", "");
    if venv {
        activate = os.path.join(venv, bin_dir, activate_name);
        if os.path.exists(activate) {
            return activate;
        }
    }
    jac_cmd = _find_jac_cmd();
    activate = os.path.join(os.path.dirname(jac_cmd[0]), "activate");
    if os.path.exists(activate) {
        return activate;
    }
    return "";
}

"""Build a clean environment dict for LSP subprocess."""
def _build_clean_env() -> dict {
    safe_keys = [
        "PATH", "HOME", "USER", "LOGNAME", "SHELL", "TERM", "LANG",
        "LC_ALL", "LC_CTYPE", "TMPDIR", "TMP", "TEMP", "XDG_RUNTIME_DIR",
        "VIRTUAL_ENV", "HOSTNAME", "PWD", "SHLVL"
    ];
    clean = {};
    for key in safe_keys {
        val = os.environ.get(key);
        if val is not None {
            clean[key] = val;
        }
    }
    return clean;
}

"""Read a Content-Length framed JSON-RPC message from a stream."""
def _read_content_length_message(stream: Any) -> Any {
    content_length = -1;
    while True {
        line = stream.readline();
        if not line {
            return None;
        }
        line_str = "";
        if isinstance(line, bytes) {
            line_str = line.decode("utf-8", errors="replace");
        } else {
            line_str = str(line);
        }
        line_stripped = line_str.strip();
        if line_stripped == "" {
            break;
        }
        if line_stripped.lower().startswith("content-length:") {
            try {
                content_length = int(line_stripped.split(":", 1)[1].strip());
            } except Exception {
            }
        }
    }
    if content_length < 0 {
        return None;
    }
    body = stream.read(content_length);
    if not body {
        return None;
    }
    body_str = "";
    if isinstance(body, bytes) {
        body_str = body.decode("utf-8", errors="replace");
    } else {
        body_str = str(body);
    }
    try {
        return json.loads(body_str);
    } except Exception {
        return None;
    }
}

"""Write a Content-Length framed JSON-RPC message to a stream."""
def _write_content_length_message(stream: Any, lock: Any, message: dict) -> bool {
    try {
        body = json.dumps(message);
        body_bytes = body.encode("utf-8");
        header = "Content-Length: " + str(len(body_bytes)) + "\r\n\r\n";
        lock.acquire();
        try {
            stream.write(header.encode("utf-8") if hasattr(stream, "mode") and "b" in stream.mode else header);
            stream.write(body_bytes if hasattr(stream, "mode") and "b" in stream.mode else body);
            stream.flush();
        } finally {
            lock.release();
        }
        return True;
    } except Exception as e {
        print("[lsp_manager] write error: " + str(e));
        return False;
    }
}

"""Background thread: reads Content-Length framed messages from LSP stdout."""
def _lsp_stdout_reader(key: str) -> None {
    entry = _lsp_registry.get(key);
    if not entry {
        return;
    }
    stdout = entry["process"].stdout;
    while True {
        proc = entry.get("process");
        if proc is None or proc.poll() is not None {
            break;
        }
        msg = _read_content_length_message(stdout);
        if msg is None {
            if proc.poll() is not None {
                break;
            }
            time.sleep(0.05);
            continue;
        }
        entry["outbox"].append(msg);
    }
    entry["reader_done"] = True;
}

"""Build env-sourcing shell prefix for a user's project.

Sources global.env (lower priority) then project .env (overrides).
Same pattern as preview_manager."""
def _build_env_prefix(user_id: str, workspace_dir: str) -> str {
    global_env = os.path.join(str(Path.home()), ".jac-ide", "users", user_id, "global.env");
    project_env_file = os.path.join(workspace_dir, ".env");
    if sys.platform == "win32" {
        # Windows: no env prefix needed, env vars loaded via Python
        return "";
    }
    env_sources = "";
    if os.path.isfile(global_env) {
        env_sources += "source \"" + global_env + "\"; ";
    }
    if os.path.isfile(project_env_file) {
        env_sources += "source \"" + project_env_file + "\"; ";
    }
    if env_sources {
        return "set -a; " + env_sources + "set +a; ";
    }
    return "";
}

"""Run jac install in background thread (non-blocking).

After install completes, restarts the LSP subprocess so it picks up
newly installed dependencies."""
def _run_jac_install_background(key: str, workspace_dir: str, activate_script: str, jac_bin: str, env_prefix: str) -> None {
    if sys.platform == "win32" {
        if activate_script {
            install_cmd = "call \"" + activate_script + "\" && " + jac_bin + " install";
        } else {
            install_cmd = jac_bin + " install";
        }
    } else {
        if activate_script {
            install_cmd = env_prefix + "source " + activate_script + " && jac install";
        } else {
            install_cmd = env_prefix + jac_bin + " install";
        }
    }
    print("[lsp_manager] Running jac install in background for " + workspace_dir);
    try {
        install_result = subprocess.run(
            install_cmd,
            shell=True,
            executable=None if sys.platform == "win32" else "/bin/bash",
            cwd=workspace_dir,
            capture_output=True,
            text=True,
            timeout=120,
            env=_build_clean_env()
        );
        if install_result.returncode != 0 {
            print("[lsp_manager] jac install warnings: " + install_result.stderr[:500]);
        } else {
            print("[lsp_manager] jac install completed successfully");
        }
    } except Exception as install_err {
        print("[lsp_manager] jac install failed (non-fatal): " + str(install_err));
    }
}

"""Clean up a dead LSP registry record — kill process if somehow alive, remove from registry."""
def _cleanup_dead_entry(key: str, record: dict) -> None {
    proc = record.get("process");
    if proc is not None {
        try {
            if proc.poll() is None {
                os.killpg(os.getpgid(proc.pid), signal.SIGTERM);
                proc.wait(timeout=2);
            }
        } except Exception {
            try { os.killpg(os.getpgid(proc.pid), signal.SIGKILL); } except Exception { }
        }
    }
    _lsp_registry.pop(key, None);
}

"""Clean up ALL stale/dead LSP processes. Call on project switch or periodically."""
def cleanup_stale_lsp() -> int {
    _lsp_lock.acquire();
    try {
        stale_keys = [];
        for k in _lsp_registry {
            entry = _lsp_registry[k];
            proc = entry.get("process");
            if proc is None or proc.poll() is not None {
                stale_keys.append(k);
            }
        }
        for k in stale_keys {
            entry = _lsp_registry.get(k);
            if entry {
                _cleanup_dead_entry(k, entry);
            }
        }
        return len(stale_keys);
    } finally {
        _lsp_lock.release();
    }
}

"""Stop ALL LSP processes except the one for a given project. Call on project switch."""
def stop_all_lsp_except(keep_user_id: str = "", keep_project_id: str = "") -> int {
    keep_key = _lsp_key(keep_user_id, keep_project_id) if keep_user_id and keep_project_id else "";
    _lsp_lock.acquire();
    try {
        to_stop = [];
        for k in _lsp_registry {
            if k != keep_key {
                to_stop.append(k);
            }
        }
        for k in to_stop {
            entry = _lsp_registry.get(k);
            if entry {
                proc = entry.get("process");
                if proc is not None and proc.poll() is None {
                    try {
                        os.killpg(os.getpgid(proc.pid), signal.SIGTERM);
                        proc.wait(timeout=2);
                    } except Exception {
                        try { os.killpg(os.getpgid(proc.pid), signal.SIGKILL); } except Exception { }
                    }
                }
                _lsp_registry.pop(k, None);
            }
        }
        return len(to_stop);
    } finally {
        _lsp_lock.release();
    }
}

"""Start an LSP subprocess for a project.

Starts `jac lsp` immediately, then runs `jac install` in a background thread
to resolve dependencies. LSP will work for already-installed deps right away.
Also cleans up any stale LSP processes from other projects."""
def start_lsp(user_id: str, project_id: str, workspace_dir: str) -> dict {
    # Clean up other projects' LSP processes first (before acquiring lock)
    stop_all_lsp_except(user_id, project_id);

    key = _lsp_key(user_id, project_id);
    _lsp_lock.acquire();
    try {
        if key in _lsp_registry {
            existing = _lsp_registry[key];
            proc = existing.get("process");
            if proc is not None and proc.poll() is None {
                return {"success": True, "status": "already_running"};
            }
            # Dead process — clean it up before creating a new one
            _cleanup_dead_entry(key, dict(existing));
        }
        if not workspace_dir or not os.path.isdir(workspace_dir) {
            return {"success": False, "error": "Invalid workspace directory"};
        }
        activate_script = _find_activate_script();
        jac_cmd = _find_jac_cmd();
        jac_bin = " ".join(jac_cmd);
        env_prefix = _build_env_prefix(user_id, workspace_dir);

        # Start jac lsp immediately (don't wait for jac install)
        if sys.platform == "win32" {
            # Windows: use call for activate, && for chaining
            if activate_script {
                shell_cmd = "call \"" + activate_script + "\" && " + jac_bin + " lsp";
            } else {
                shell_cmd = jac_bin + " lsp";
            }
        } else {
            if activate_script {
                shell_cmd = env_prefix + "source " + activate_script + " && jac lsp";
            } else {
                shell_cmd = env_prefix + jac_bin + " lsp";
            }
        }
        lsp_env = _build_clean_env();
        popen_kwargs = {
            "shell": True,
            "cwd": workspace_dir,
            "stdin": subprocess.PIPE,
            "stdout": subprocess.PIPE,
            "stderr": subprocess.PIPE,
            "env": lsp_env
        };
        if sys.platform != "win32" {
            popen_kwargs["executable"] = "/bin/bash";
            popen_kwargs["preexec_fn"] = os.setsid;
        }
        process = subprocess.Popen(shell_cmd, **popen_kwargs);
        write_lock = Lock();
        entry = {
            "process": process,
            "workspace_dir": workspace_dir,
            "user_id": user_id,
            "project_id": project_id,
            "write_lock": write_lock,
            "outbox": deque(),
            "notifications": deque(),
            "reader_done": False
        };
        _lsp_registry[key] = entry;
        reader_thread = Thread(target=_lsp_stdout_reader, args=(key,), daemon=True);
        reader_thread.start();

        # Run jac install in background — LSP works immediately for existing deps
        install_thread = Thread(
            target=_run_jac_install_background,
            args=(key, workspace_dir, activate_script, jac_bin, env_prefix),
            daemon=True
        );
        install_thread.start();

        return {"success": True, "status": "started"};
    } except Exception as e {
        return {"success": False, "error": str(e)};
    } finally {
        _lsp_lock.release();
    }
}

"""Send a JSON-RPC message to the LSP subprocess stdin."""
def send_lsp_message(user_id: str, project_id: str, message: dict) -> dict {
    key = _lsp_key(user_id, project_id);
    entry = _lsp_registry.get(key);
    if not entry {
        return {"success": False, "error": "LSP not running"};
    }
    proc = entry.get("process");
    if proc is None or proc.poll() is not None {
        return {"success": False, "error": "LSP process not alive"};
    }
    ok = _write_content_length_message(proc.stdin, entry["write_lock"], message);
    if ok {
        return {"success": True};
    }
    return {"success": False, "error": "Failed to write to LSP stdin"};
}

"""Wait for a response with a matching request ID from the LSP outbox."""
def wait_lsp_response(user_id: str, project_id: str, request_id: int, timeout: float = 3.0) -> Any {
    key = _lsp_key(user_id, project_id);
    entry = _lsp_registry.get(key);
    if not entry {
        return None;
    }
    deadline = time.time() + timeout;
    while time.time() < deadline {
        outbox = entry["outbox"];
        found_idx = -1;
        idx = 0;
        for msg in outbox {
            if "id" in msg and msg["id"] == request_id {
                found_idx = idx;
                break;
            }
            idx += 1;
        }
        if found_idx >= 0 {
            items_before = [];
            for i in range(found_idx) {
                items_before.append(outbox.popleft());
            }
            matched = outbox.popleft();
            for item in items_before {
                if "method" in item and "id" not in item {
                    entry["notifications"].append(item);
                } else {
                    entry["notifications"].append(item);
                }
            }
            return matched;
        }
        time.sleep(0.05);
    }
    return None;
}

"""Drain all buffered server-initiated notifications."""
def drain_lsp_notifications(user_id: str, project_id: str) -> list {
    key = _lsp_key(user_id, project_id);
    entry = _lsp_registry.get(key);
    if not entry {
        return [];
    }
    result = [];
    while len(entry["notifications"]) > 0 {
        result.append(entry["notifications"].popleft());
    }
    outbox = entry["outbox"];
    to_keep = deque();
    while len(outbox) > 0 {
        msg = outbox.popleft();
        if "method" in msg and "id" not in msg {
            result.append(msg);
        } else {
            to_keep.append(msg);
        }
    }
    for item in to_keep {
        outbox.append(item);
    }
    return result;
}

"""Stop the LSP subprocess for a project."""
def stop_lsp(user_id: str, project_id: str) -> dict {
    key = _lsp_key(user_id, project_id);
    _lsp_lock.acquire();
    try {
        entry = _lsp_registry.pop(key, None);
        if not entry {
            return {"success": False, "error": "LSP not running"};
        }
        proc = entry.get("process");
        if proc is not None and proc.poll() is None {
            shutdown_msg = {"jsonrpc": "2.0", "id": 99999, "method": "shutdown", "params": None};
            _write_content_length_message(proc.stdin, entry["write_lock"], shutdown_msg);
            exit_msg = {"jsonrpc": "2.0", "method": "exit"};
            _write_content_length_message(proc.stdin, entry["write_lock"], exit_msg);
            try {
                proc.wait(timeout=2);
            } except subprocess.TimeoutExpired {
                try {
                    os.killpg(os.getpgid(proc.pid), signal.SIGTERM);
                    proc.wait(timeout=2);
                } except Exception {
                    try {
                        os.killpg(os.getpgid(proc.pid), signal.SIGKILL);
                    } except ProcessLookupError {
                    }
                }
            }
        }
        return {"success": True, "status": "stopped"};
    } except Exception as e {
        return {"success": False, "error": str(e)};
    } finally {
        _lsp_lock.release();
    }
}

"""Get LSP status for a project."""
def get_lsp_status(user_id: str, project_id: str) -> dict {
    key = _lsp_key(user_id, project_id);
    entry = _lsp_registry.get(key);
    if not entry {
        return {"running": False, "status": "none"};
    }
    proc = entry.get("process");
    alive = proc is not None and proc.poll() is None;
    return {"running": alive, "status": ("running" if alive else "stopped")};
}
