"""Terminal Manager - Manages per-project interactive PTY terminal sessions.

Provides interactive shell access to project sandbox directories.
Local mode: pty.fork() for real PTY with ANSI support.
K8s mode: kubernetes exec API with tty=True for pod shell access.

Follows the same registry + Lock + background reader thread pattern as lsp_manager.jac.
"""

import os;
import sys;
import struct;
import signal;
import time;
import base64;
import importlib;

glob pty = importlib.import_module("pty") if sys.platform != "win32" else None;
glob fcntl = importlib.import_module("fcntl") if sys.platform != "win32" else None;
glob termios = importlib.import_module("termios") if sys.platform != "win32" else None;
glob select = importlib.import_module("select") if sys.platform != "win32" else None;
import from threading { Lock, Thread, Event }
import from collections { deque }
import from pathlib { Path }


glob _term_registry: dict = {};
glob _term_lock = Lock();
glob _MAX_OUTBOX_SIZE: int = 10000;


def _term_key(user_id: str, project_id: str) -> str {
    return str(user_id) + "::" + str(project_id);
}

def _find_activate_script() -> str {
    import sys;
    is_windows = sys.platform == "win32";
    bin_dir = "Scripts" if is_windows else "bin";
    activate_name = "activate.bat" if is_windows else "activate";
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
    return "";
}

def _is_k8s_mode() -> bool {
    try {
        import from services.preview_manager { _is_k8s_sandbox }
        return _is_k8s_sandbox;
    } except Exception {
        return False;
    }
}


# ===========================================================================
# Local PTY Terminal
# ===========================================================================

"""Background reader thread for local PTY master fd.
Reads raw bytes from the PTY, base64-encodes them, and appends to outbox."""
def _local_pty_reader(key: str, stop_event: Any) -> None {
    entry = _term_registry.get(key);
    if not entry {
        return;
    }
    master_fd = entry["master_fd"];
    while not stop_event.is_set() {
        try {
            ready = select.select([master_fd], [], [], 0.05);
            if ready[0] {
                data = os.read(master_fd, 4096);
                if not data {
                    break;
                }
                encoded = base64.b64encode(data).decode("ascii");
                outbox = entry["outbox"];
                if len(outbox) < _MAX_OUTBOX_SIZE {
                    outbox.append(encoded);
                }
            }
        } except OSError {
            break;
        } except Exception {
            break;
        }
    }
    entry["reader_done"] = True;
}

"""Start a Windows terminal session using subprocess with conhost."""
def _start_windows_terminal(user_id: str, project_id: str, cwd: str) -> dict {
    import subprocess;
    import from queue { Queue, Empty }
    key = _term_key(user_id, project_id);

    env = os.environ.copy();
    activate_script = _find_activate_script();
    shell = os.environ.get("COMSPEC", "cmd.exe");

    # Use conhost to get a real console; pipe stdout/stderr separately
    process = subprocess.Popen(
        [shell, "/Q"],
        cwd=cwd,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=env,
        bufsize=0
    );

    if activate_script {
        try {
            process.stdin.write(f"call \"{activate_script}\"\r\n".encode());
            process.stdin.flush();
        } except Exception { }
    }

    output_queue: Queue = Queue();
    stop_evt = Event();

    # Reader thread — reads stdout in a non-blocking way
    def _pipe_reader(pipe: Any) -> None {
        import msvcrt;
        import _winapi;
        try {
            fd = pipe.fileno();
            handle = msvcrt.get_osfhandle(fd);
            while not stop_evt.is_set() {
                # Check if data is available before reading
                try {
                    avail = _winapi.PeekNamedPipe(handle, 0)[1];
                    if avail > 0 {
                        data = pipe.read(min(avail, 4096));
                        if data {
                            output_queue.put(data);
                        }
                    } else {
                        # No data — check if process is still alive
                        if process.poll() is not None {
                            # Read any remaining data
                            remaining = pipe.read();
                            if remaining {
                                output_queue.put(remaining);
                            }
                            break;
                        }
                        time.sleep(0.05);
                    }
                } except (OSError, BrokenPipeError) {
                    break;
                }
            }
        } except Exception { }
    }

    # Buffer drainer — moves queued output into the entry buffer
    def _buffer_drainer() -> None {
        while not stop_evt.is_set() {
            try {
                data = output_queue.get(timeout=0.1);
                with _term_lock {
                    if key in _term_registry {
                        _term_registry[key]["buffer"].append(data);
                    }
                }
            } except Empty { }
        }
        entry["reader_done"] = True;
    }

    entry = {
        "process": process,
        "master_fd": None,
        "child_pid": process.pid,
        "cwd": cwd,
        "user_id": user_id,
        "project_id": project_id,
        "buffer": deque(maxlen=5000),
        "reader_done": False,
        "stop_event": stop_evt,
        "mode": "local"
    };

    with _term_lock {
        _term_registry[key] = entry;
    }

    Thread(target=_pipe_reader, args=(process.stdout,), daemon=True).start();
    Thread(target=_pipe_reader, args=(process.stderr,), daemon=True).start();
    Thread(target=_buffer_drainer, daemon=True).start();

    return {"success": True, "message": "Terminal started (Windows mode)"};
}

"""Start a local PTY terminal session."""
def _start_local_terminal(user_id: str, project_id: str, cwd: str) -> dict {
    if not cwd or not os.path.isdir(cwd) {
        return {"success": False, "error": "Invalid working directory: " + str(cwd)};
    }

    import sys;
    if sys.platform == "win32" {
        return {"success": False, "error": "Terminal not supported on Windows desktop. Use your system terminal instead."};
    }

    # Build environment
    env = os.environ.copy();
    env["TERM"] = "xterm-256color";
    env["COLORTERM"] = "truecolor";

    # Source activate script if available
    activate_script = _find_activate_script();
    import sys;
    if sys.platform == "win32" {
        shell_args = [os.environ.get("COMSPEC", "cmd.exe")];
    } else {
        shell_args = ["/bin/bash", "--login"];
    }

    # Build rcfile content to source venv + env files + sandbox guard
    real_cwd = os.path.realpath(cwd);
    rc_lines = [];
    if activate_script {
        rc_lines.append("source \"" + activate_script + "\"");
    }
    global_env = os.path.join(str(Path.home()), ".jac-ide", "users", user_id, "global.env");
    project_env = os.path.join(cwd, ".env");
    if os.path.isfile(global_env) {
        rc_lines.append("set -a; source \"" + global_env + "\"; set +a");
    }
    if os.path.isfile(project_env) {
        rc_lines.append("set -a; source \"" + project_env + "\"; set +a");
    }

    # Sandbox guard: restrict navigation to project directory only
    rc_lines.append("export JAC_PROJECT_ROOT=\"" + real_cwd + "\"");
    rc_lines.append("cd() {");
    rc_lines.append("  if [ $# -eq 0 ]; then builtin cd \"$JAC_PROJECT_ROOT\"; return; fi");
    rc_lines.append("  local target");
    rc_lines.append("  target=$(builtin cd \"$1\" 2>/dev/null && pwd -P)");
    rc_lines.append("  if [ -z \"$target\" ]; then echo \"cd: no such directory: $1\"; return 1; fi");
    rc_lines.append("  case \"$target\" in");
    rc_lines.append("    \"$JAC_PROJECT_ROOT\"*) builtin cd \"$1\" ;;");
    rc_lines.append("    *) echo \"restricted: cannot navigate outside project directory\" ;;");
    rc_lines.append("  esac");
    rc_lines.append("}");
    rc_lines.append("PROMPT_COMMAND='case \"$(pwd -P)\" in \"$JAC_PROJECT_ROOT\"*) ;; *) builtin cd \"$JAC_PROJECT_ROOT\" ;; esac'");
    rc_lines.append("export PS1=\"\\[\\033[1;33m\\]jac\\[\\033[0m\\]:\\[\\033[1;34m\\]\\w\\[\\033[0m\\]\\$ \"");

    # Fork PTY
    child_pid = 0;
    master_fd = 0;
    pid_fd = pty.fork();
    child_pid = pid_fd[0];
    master_fd = pid_fd[1];

    if child_pid == 0 {
        # Child process
        try {
            os.chdir(cwd);
            # Set up env
            for k in env {
                os.environ[k] = env[k];
            }
            # Write a temp rcfile for bash to source
            rc_content = "\n".join(rc_lines) + "\n" if rc_lines else "";
            if rc_content {
                rc_path = os.path.join(cwd, ".jac-ide-bashrc");
                with open(rc_path, "w") as f {
                    f.write(rc_content);
                }
                os.execvpe("/bin/bash", ["bash", "--rcfile", rc_path, "-i"], os.environ);
            } else {
                os.execvpe("/bin/bash", ["bash", "-i"], os.environ);
            }
        } except Exception {
            os._exit(1);
        }
    }

    # Parent process
    # Set initial terminal size
    try {
        winsize = struct.pack("HHHH", 24, 80, 0, 0);
        fcntl.ioctl(master_fd, termios.TIOCSWINSZ, winsize);
    } except Exception {
        ;
    }

    key = _term_key(user_id, project_id);
    stop_event = Event();
    entry = {
        "master_fd": master_fd,
        "child_pid": child_pid,
        "ws_client": None,
        "outbox": deque(),
        "write_lock": Lock(),
        "reader_done": False,
        "stop_event": stop_event,
        "mode": "local",
        "user_id": user_id,
        "project_id": project_id,
        "cwd": cwd
    };
    _term_registry[key] = entry;

    reader_thread = Thread(target=_local_pty_reader, args=(key, stop_event), daemon=True);
    reader_thread.start();
    entry["reader_thread"] = reader_thread;

    return {"success": True, "status": "started"};
}


# ===========================================================================
# K8s Terminal
# ===========================================================================

"""Background reader thread for K8s exec WSClient."""
def _k8s_pty_reader(key: str, stop_event: Any) -> None {
    entry = _term_registry.get(key);
    if not entry {
        return;
    }
    ws_client = entry["ws_client"];
    while not stop_event.is_set() {
        try {
            if not ws_client.is_open() {
                break;
            }
            ws_client.update(timeout=0.1);
            stdout_data = ws_client.read_stdout();
            if stdout_data {
                encoded = base64.b64encode(stdout_data.encode("utf-8") if isinstance(stdout_data, str) else stdout_data).decode("ascii");
                outbox = entry["outbox"];
                if len(outbox) < _MAX_OUTBOX_SIZE {
                    outbox.append(encoded);
                }
            }
            stderr_data = ws_client.read_stderr();
            if stderr_data {
                encoded = base64.b64encode(stderr_data.encode("utf-8") if isinstance(stderr_data, str) else stderr_data).decode("ascii");
                outbox = entry["outbox"];
                if len(outbox) < _MAX_OUTBOX_SIZE {
                    outbox.append(encoded);
                }
            }
        } except Exception {
            break;
        }
    }
    entry["reader_done"] = True;
}

"""Start a K8s terminal session by exec-ing into the sandbox pod."""
def _start_k8s_terminal(user_id: str, project_id: str) -> dict {
    try {
        import from services.preview_manager { _sandbox_id_map, _get_sandbox, _preview_key }
        import from kubernetes { client as k8s_client }
        import from kubernetes.stream { stream }

        key_preview = _preview_key(user_id, project_id);
        sid = _sandbox_id_map.get(key_preview);
        if not sid {
            return {"success": False, "error": "No sandbox running for this project. Start the preview first."};
        }

        sandbox = _get_sandbox();
        if sandbox is None {
            return {"success": False, "error": "Sandbox not available"};
        }

        # Resolve pod name and namespace from sandbox
        namespace = "default";
        if hasattr(sandbox, "config") and hasattr(sandbox.config, "namespace") {
            namespace = sandbox.config.namespace or "default";
        }

        # Create K8s API client
        core_v1 = k8s_client.CoreV1Api();

        # Warm pool pods keep their jac-warm-* name but get labeled with the sandbox ID.
        # Look up the actual pod name by label instead of using sid directly.
        pods = core_v1.list_namespaced_pod(
            namespace=namespace,
            label_selector=f"jac-sandbox-id={sid}"
        );
        if pods.items and len(pods.items) > 0 {
            pod_name = pods.items[0].metadata.name;
        } else {
            # Fallback: try sid as pod name (non-warm-pool case)
            pod_name = sid;
        }

        # Open interactive exec
        ws = stream(
            core_v1.connect_get_namespaced_pod_exec,
            pod_name,
            namespace,
            container="sandbox",
            command=["/bin/bash", "-i"],
            stderr=True,
            stdout=True,
            stdin=True,
            tty=True,
            _preload_content=False
        );

        key = _term_key(user_id, project_id);
        stop_event = Event();
        entry = {
            "master_fd": -1,
            "child_pid": -1,
            "ws_client": ws,
            "outbox": deque(),
            "write_lock": Lock(),
            "reader_done": False,
            "stop_event": stop_event,
            "mode": "k8s",
            "user_id": user_id,
            "project_id": project_id,
            "cwd": "/app"
        };
        _term_registry[key] = entry;

        reader_thread = Thread(target=_k8s_pty_reader, args=(key, stop_event), daemon=True);
        reader_thread.start();
        entry["reader_thread"] = reader_thread;

        return {"success": True, "status": "started"};
    } except Exception as e {
        return {"success": False, "error": "K8s terminal error: " + str(e)};
    }
}


# ===========================================================================
# Public API
# ===========================================================================

"""Start an interactive terminal session for a project."""
def start_terminal(user_id: str, project_id: str, cwd: str = "") -> dict {
    key = _term_key(user_id, project_id);
    _term_lock.acquire();
    try {
        # Idempotency: return existing session if alive
        if key in _term_registry {
            existing = _term_registry[key];
            if not existing["reader_done"] {
                if existing["mode"] == "local" {
                    try {
                        os.kill(existing["child_pid"], 0);
                        return {"success": True, "status": "already_running"};
                    } except OSError {
                        ;
                    }
                } elif existing["mode"] == "k8s" {
                    ws = existing.get("ws_client");
                    if ws and ws.is_open() {
                        return {"success": True, "status": "already_running"};
                    }
                }
            }
            # Dead session — clean up stale entry
            _term_registry.pop(key, None);
        }

        if _is_k8s_mode() {
            return _start_k8s_terminal(user_id, project_id);
        } else {
            return _start_local_terminal(user_id, project_id, cwd);
        }
    } except Exception as e {
        return {"success": False, "error": str(e)};
    } finally {
        _term_lock.release();
    }
}

"""Send input (keystrokes) to the terminal. Warns if user tries jac start."""
def send_terminal_input(user_id: str, project_id: str, data: str) -> dict {
    key = _term_key(user_id, project_id);
    entry = _term_registry.get(key);
    if not entry {
        return {"success": False, "error": "Terminal not running"};
    }

    # Detect "jac start" command and inject a warning
    if data == "\r" or data == "\n" {
        cmd_buf = entry.get("_cmd_buf", "");
        stripped = cmd_buf.strip();
        if stripped.startswith("jac start") or stripped.startswith("jac serve") {
            warn = "\r\n\033[1;33m⚠ Warning: A preview server is managed by the IDE. Running 'jac start' here may cause port conflicts.\033[0m\r\n\033[1;33m  Use the Run button instead, or use 'jac run' for scripts.\033[0m\r\n";
            encoded_warn = base64.b64encode(warn.encode("utf-8")).decode("ascii");
            outbox = entry["outbox"];
            if len(outbox) < _MAX_OUTBOX_SIZE {
                outbox.append(encoded_warn);
            }
        }
        entry["_cmd_buf"] = "";
    } else {
        # Accumulate printable chars into command buffer
        buf = entry.get("_cmd_buf", "");
        for ch in data {
            if ch == "\x7f" or ch == "\x08" {
                buf = buf[:-1] if buf else "";
            } elif ch >= " " {
                buf = buf + ch;
            }
        }
        entry["_cmd_buf"] = buf;
    }

    try {
        entry["write_lock"].acquire();
        try {
            if entry["mode"] == "local" {
                if entry["master_fd"] is None and entry.get("process") {
                    # Windows mode — write to process stdin
                    entry["process"].stdin.write(data.encode("utf-8"));
                    entry["process"].stdin.flush();
                } else {
                    os.write(entry["master_fd"], data.encode("utf-8"));
                }
            } elif entry["mode"] == "k8s" {
                ws = entry["ws_client"];
                if ws and ws.is_open() {
                    ws.write_stdin(data);
                } else {
                    return {"success": False, "error": "K8s connection closed"};
                }
            }
        } finally {
            entry["write_lock"].release();
        }
        return {"success": True};
    } except Exception as e {
        return {"success": False, "error": str(e)};
    }
}

"""Resize the terminal."""
def resize_terminal(user_id: str, project_id: str, cols: int, rows: int) -> dict {
    key = _term_key(user_id, project_id);
    entry = _term_registry.get(key);
    if not entry {
        return {"success": False, "error": "Terminal not running"};
    }
    try {
        if entry["mode"] == "local" {
            winsize = struct.pack("HHHH", rows, cols, 0, 0);
            fcntl.ioctl(entry["master_fd"], termios.TIOCSWINSZ, winsize);
        } elif entry["mode"] == "k8s" {
            import json;
            ws = entry["ws_client"];
            if ws and ws.is_open() {
                resize_msg = json.dumps({"Width": cols, "Height": rows});
                ws.write_channel(4, resize_msg);
            }
        }
        return {"success": True};
    } except Exception as e {
        return {"success": False, "error": str(e)};
    }
}

"""Drain all buffered output chunks from the terminal."""
def drain_terminal_output(user_id: str, project_id: str) -> list {
    key = _term_key(user_id, project_id);
    entry = _term_registry.get(key);
    if not entry {
        return [];
    }
    result = [];
    outbox = entry["outbox"];
    while len(outbox) > 0 {
        result.append(outbox.popleft());
    }
    return result;
}

"""Stop the terminal session."""
def stop_terminal(user_id: str, project_id: str) -> dict {
    key = _term_key(user_id, project_id);
    _term_lock.acquire();
    try {
        entry = _term_registry.pop(key, None);
        if not entry {
            return {"success": False, "error": "Terminal not running"};
        }

        # Signal reader thread to stop
        stop_event = entry.get("stop_event");
        if stop_event {
            stop_event.set();
        }

        if entry["mode"] == "local" {
            # Close master fd or process
            if entry["master_fd"] is None and entry.get("process") {
                # Windows mode
                try {
                    entry["process"].terminate();
                } except Exception { }
            } else {
                try {
                    os.close(entry["master_fd"]);
                } except Exception { }
            }
            # Kill child process
            child_pid = entry.get("child_pid", -1);
            if child_pid > 0 {
                try {
                    os.kill(child_pid, signal.SIGTERM);
                    # Wait briefly for clean exit
                    for _ in range(10) {
                        result = os.waitpid(child_pid, os.WNOHANG);
                        if result[0] != 0 {
                            break;
                        }
                        time.sleep(0.1);
                    }
                } except ChildProcessError {
                    ;
                } except OSError {
                    ;
                }
                # Force kill if still alive
                try {
                    os.kill(child_pid, signal.SIGKILL);
                    os.waitpid(child_pid, 0);
                } except Exception {
                    ;
                }
            }
            # Clean up temp rcfile
            rc_path = os.path.join(entry.get("cwd", ""), ".jac-ide-bashrc");
            try {
                if os.path.exists(rc_path) {
                    os.remove(rc_path);
                }
            } except Exception {
                ;
            }
        } elif entry["mode"] == "k8s" {
            ws = entry.get("ws_client");
            if ws {
                try {
                    ws.close();
                } except Exception {
                    ;
                }
            }
        }

        return {"success": True, "status": "stopped"};
    } except Exception as e {
        return {"success": False, "error": str(e)};
    } finally {
        _term_lock.release();
    }
}

"""Get terminal status."""
def get_terminal_status(user_id: str, project_id: str) -> dict {
    key = _term_key(user_id, project_id);
    entry = _term_registry.get(key);
    if not entry {
        return {"running": False, "status": "none"};
    }
    if entry["reader_done"] {
        return {"running": False, "status": "stopped"};
    }
    if entry["mode"] == "local" {
        try {
            os.kill(entry["child_pid"], 0);
            return {"running": True, "status": "running"};
        } except OSError {
            return {"running": False, "status": "stopped"};
        }
    } elif entry["mode"] == "k8s" {
        ws = entry.get("ws_client");
        if ws and ws.is_open() {
            return {"running": True, "status": "running"};
        }
        return {"running": False, "status": "stopped"};
    }
    return {"running": False, "status": "unknown"};
}
