"""Spawn a TUI renderer sidecar as a subprocess for `jac ai --tui`.

This module is the seam between the Jac/Python agent control plane and the
native (`na`) renderer sidecar.  The control plane streams UI frames to the
sidecar's stdin and reads single-line commands back from its stdout.

The wire protocol is documented authoritatively in ai_tui/PROTOCOL.md (frames +
commands) and ai_tui/BACKENDS.md (spawn details).

IPC overview:
  Python feeds ui_stream() frames to the sidecar's stdin as key:value lines
  terminated by "---".  The sidecar sends single-line commands to Python via
  its stdout (SEND:, STOP, RESET, QUIT, APPLY:).

Frame format (Python -> sidecar):
  TYPE:full|delta|hb
  STATUS:<str>
  ACTIVE:<str>
  MODEL:<str>
  NEEDS_KEY:0|1
  KEY_ENV:<str>
  EV:<id>:<kind>:<node>:<text_escaped>
  ---

text_escaped: \n -> \\n, \\ -> \\\\
"""

import from jaclang.cli.agent_api { AgentRequest }
import from jaclang.cli.ai_tui.tui_shared {
    _configure_ui_env,
    _debug_log,
    _dispatch_cmd,
    _ensure_na_artifact,
    _frame_blob,
    _require_tty
}

impl run_tui_session(req: AgentRequest) -> int {
    import os;
    import threading;
    import from pathlib { Path }
    import from jaclang.cli.ai_agent { ui_configure, ui_stop, ui_stream }
    import from jaclang.cli.console { console }

    # run_tui_session.jac lives in jaclang/cli/ai_tui/; sidecars in jaclang/cli/ai_tui_na/
    pkg_root = Path(__file__).resolve().parent.parent;

    typed_req: AgentRequest = req;
    r: any = typed_req;
    initial = str(r?.prompt or "").strip();

    ensured = _ensure_tui_binary(pkg_root);
    if not ensured.get("ok") {
        console.error(str(ensured.get("error", "failed to build TUI backend")));
        hint = str(ensured.get("hint", ""));
        if hint {
            console.error(hint);
        }
        return 1;
    }
    resolved = _resolve_tui_command(pkg_root, initial);

    if not resolved.get("ok") {
        console.error(str(resolved.get("error", "failed to resolve TUI backend")));
        hint = str(resolved.get("hint", ""));
        if hint {
            console.error(hint);
        }
        return 1;
    }
    cmd_args = resolved.get("cmd_args");

    tty_dev = _require_tty();
    if tty_dev is None {
        return 1;
    }
    old_tty_env = os.environ.get("JAC_AI_TUI_TTY");
    os.environ["JAC_AI_TUI_TTY"] = tty_dev;

    # JAC_AI_UI_* env contract + ACTIVE capture gate, set through tui_shared so
    # the subprocess and in-process backends share one copy of the contract. The
    # returned closure unwinds JAC_AI_UI_ACTIVE on every exit path; JAC_AI_TUI_TTY
    # (below) is subprocess-only and restored separately.
    restore_ui = _configure_ui_env(r)["restore"];

    ui_configure();

    try {
        proc = _spawn_tui_backend(cmd_args);
        _debug_log(f"spawned pid={proc.pid} cmd={cmd_args}");
    } except Exception as e {
        _debug_log(f"launch failed: {e}");
        try {
            ui_stop();
        } except Exception as e {
            _debug_log(f"ui_stop error (on launch fail): {e}");
        }
        restore_ui();
        if old_tty_env is None {
            os.environ.pop("JAC_AI_TUI_TTY", None);
        } else {
            os.environ["JAC_AI_TUI_TTY"] = old_tty_env;
        }
        console.error(f"Failed to launch jac ai TUI: {e}");
        return 1;
    }

    stop_evt = threading.Event();

    def _cmd_reader {
        try {
            for raw_line in proc.stdout {
                line = raw_line.strip();
                if not line {
                    continue;
                }
                _debug_log(f"cmd <- {line}");
                _dispatch_cmd(line, stop_evt, proc);
            }
            _debug_log("cmd reader: stdout closed");
        } except Exception as e {
            _debug_log(f"cmd reader error: {e}");
        }
    }

    def _stream_writer {
        try {
            for frame in ui_stream() {
                if proc.poll() is not None {
                    break;
                }
                if stop_evt.is_set() {
                    break;
                }
                if frame.get("heartbeat") {
                    continue;
                }
                _debug_log(
                    "frame -> " + str(frame.get("status", "")) + " active=" + str(
                        frame.get("active", "")
                    ) + " full=" + str(bool(frame.get("full"))) + " ev=" + str(
                        (frame.get("ev") or {}).get("kind", "")
                    )
                );
                _write_frame(proc.stdin, frame);
            }
            _debug_log("stream writer: ui_stream ended");
        } except Exception as e {
            _debug_log(f"stream writer error: {e}");
        }
        try {
            proc.stdin.close();
        } except Exception as e {
            _debug_log(f"stdin close error: {e}");
        }
    }

    cmd_thread = threading.Thread(target=_cmd_reader, daemon=True);
    stream_thread = threading.Thread(target=_stream_writer, daemon=True);
    cmd_thread.start();
    stream_thread.start();

    try {
        proc.wait();
    } except KeyboardInterrupt {
        proc.terminate();
        proc.wait();
    } finally {
        stop_evt.set();
        try {
            ui_stop();
        } except Exception as e {
            _debug_log(f"ui_stop error: {e}");
        }
        restore_ui();
        if old_tty_env is None {
            os.environ.pop("JAC_AI_TUI_TTY", None);
        } else {
            os.environ["JAC_AI_TUI_TTY"] = old_tty_env;
        }
    }

    rc: any = proc.returncode;
    _debug_log(f"session exit rc={rc}");
    return int(rc if rc is not None else 0);
}

def _tui_binary_path(pkg_root: any) -> str {
    import sys;
    name = "jac-na-tui.exe" if sys.platform == "win32" else "jac-na-tui";
    return str(pkg_root / "ai_tui_na" / "bin" / name);
}

def _ensure_tui_binary(pkg_root: any) -> dict {
    # jac-na-tui is the subprocess sidecar binary; tui.na.jac is its entry source,
    # used to detect a dev tree. Delegates to the shared NA artifact ensure so the
    # build contract stays identical to the in-process backend's _ensure_tui_lib
    # (build.sh --quick builds both artifacts in one pass).
    return _ensure_na_artifact(
        pkg_root,
        _tui_binary_path(pkg_root),
        str(pkg_root / "ai_tui_na" / "tui.na.jac"),
        "jac-na-tui",
    );
}

def _resolve_tui_command(pkg_root: any, initial: str) -> dict {
    # Map the NA sidecar to a spawn command, validating its presence.
    # Returns {ok, cmd_args, error, hint}.  `initial`, when non-empty, is passed
    # to the sidecar as its first positional arg (the seed prompt).
    import os;

    binary = _tui_binary_path(pkg_root);
    if not os.path.exists(binary) {
        return {
            "ok": False,
            "cmd_args": [],
            "error": f"jac-na-tui not found at {binary}",
            "hint": "Build it with:  jac/jaclang/cli/ai_tui_na/build.sh",

        };
    }
    cmd_args = [binary];
    if initial {
        cmd_args.append(initial);
    }
    return {"ok": True, "cmd_args": cmd_args, "error": "", "hint": ""};
}

def _spawn_tui_backend(cmd_args: list) -> any {
    # Spawn a sidecar with line-buffered text pipes on stdin/stdout. On POSIX,
    # start_new_session=True calls setsid() so keyboard signals don't reach the
    # parent. On Windows, CREATE_NEW_PROCESS_GROUP is the equivalent (subprocess
    # backend is Phase 6 / out of scope for v1; this just avoids crashes).
    import sys;
    import subprocess;

    if sys.platform == "win32" {
        return subprocess.Popen(
            cmd_args,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            text=True,
            bufsize=1,
            creationflags=subprocess.CREATE_NEW_PROCESS_GROUP,
        );
    }
    return subprocess.Popen(
        cmd_args,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        text=True,
        bufsize=1,
        start_new_session=True,
    );
}

def _write_frame(pipe: any, frame: dict) {
    # Same KEY:VALUE\n...\n--- text the in-process path builds (shared _frame_blob),
    # just flushed to the sidecar's stdin instead of handed to ctypes.
    try {
        pipe.write(_frame_blob(frame) + "\n");
        pipe.flush();
    } except Exception as e {
        _debug_log(f"frame write error: {e}");
    }
}
