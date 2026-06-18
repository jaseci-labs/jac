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

impl run_tui_session(req: AgentRequest) -> int {
    import os;
    import threading;
    import from pathlib { Path }
    import from jaclang.cli.ai_agent {
        _MODEL_PRESETS,
        ui_configure,
        ui_stop,
        ui_stream
    }
    import from jaclang.cli.console { console }

    # run_tui_session.jac lives in jac_super/ai_agent/; sidecars in jac_super/ai_tui_*/
    pkg_root = Path(__file__).resolve().parent.parent;

    typed_req: AgentRequest = req;
    r: any = typed_req;
    initial = str(r?.prompt or "").strip();

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

    tty_dev = _sidecar_tty_device();
    if not tty_dev {
        console.error(
            "jac ai --tui needs an interactive terminal (stdin or stderr must be a TTY)"
        );
        return 1;
    }
    old_tty_env = os.environ.get("JAC_AI_TUI_TTY");
    os.environ["JAC_AI_TUI_TTY"] = tty_dev;

    project = os.path.normpath(str(r?.cwd or os.getcwd()));
    os.environ["JAC_AI_UI_PROJECT"] = project;
    os.environ["JAC_AI_UI_MODEL"] = str(r?.model or "");
    os.environ["JAC_AI_UI_NCTX"] = str(int(r?.n_ctx or 0));
    # File-picker source: a newline-separated project file list, capped. Computed
    # here (control plane) so the native sidecar needs no filesystem FFI; it reads
    # JAC_AI_UI_FILES via os.getenv at startup. Prefer tracked files, else walk.
    os.environ["JAC_AI_UI_FILES"] = _list_project_files(project);
    # Model-picker defaults: same one-click list as `ai_agent._MODEL_PRESETS`.
    os.environ["JAC_AI_UI_MODEL_PRESETS"] = "\n".join(_MODEL_PRESETS);
    old_active = os.environ.get("JAC_AI_UI_ACTIVE");
    os.environ["JAC_AI_UI_ACTIVE"] = "1";

    ui_configure();

    try {
        proc = _spawn_tui_backend(cmd_args);
        _debug_log(f"spawned pid={proc.pid} cmd={cmd_args}");
    } except Exception as e {
        _debug_log(f"launch failed: {e}");
        try {
            ui_stop();
        } except Exception { }
        if old_active is None {
            os.environ.pop("JAC_AI_UI_ACTIVE", None);
        } else {
            os.environ["JAC_AI_UI_ACTIVE"] = old_active;
        }
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
                _dispatch_cmd(line, proc, stop_evt);
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
        } except Exception { }
        if old_active is None {
            os.environ.pop("JAC_AI_UI_ACTIVE", None);
        } else {
            os.environ["JAC_AI_UI_ACTIVE"] = old_active;
        }
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

def _debug_log(msg: str) -> None {
    import os;
    import time;

    path = os.environ.get("JAC_AI_TUI_DEBUG_LOG", "").strip();
    if not path {
        return;
    }
    try {
        with open(path, "a", encoding="utf-8") as f {
            stamp = time.strftime("%Y-%m-%d %H:%M:%S");
            f.write(f"[{stamp}] {msg}\n");
        }
    } except Exception { }
}

def _list_project_files(project: str) -> str {
    # Newline-separated relative file paths under `project` for the file picker.
    # Tracked files first (git ls-files), else a bounded filesystem walk. Capped
    # so the value stays well within env-var size limits.
    import os;
    import subprocess;

    cap = 2000;
    out_lines: list = [];
    try {
        res = subprocess.run(
            ["git", "-C", project, "ls-files"],
            capture_output=True,
            text=True,
            timeout=5
        );
        if res.returncode == 0 {
            for line in res.stdout.split("\n") {
                s = line.strip();
                if s {
                    out_lines.append(s);
                }
                if len(out_lines) >= cap {
                    break;
                }
            }
        }
    } except Exception { }

    if not out_lines {
        try {
            for entry in os.walk(project) {
                dirpath = entry[0];
                if ".git" in dirpath.split(os.sep) {
                    continue;
                }
                for fn in entry[2] {
                    rel = os.path.relpath(os.path.join(dirpath, fn), project);
                    out_lines.append(rel);
                    if len(out_lines) >= cap {
                        break;
                    }
                }
                if len(out_lines) >= cap {
                    break;
                }
            }
        } except Exception { }
    }

    return "\n".join(out_lines);
}

def _sidecar_tty_device -> str {
    # Resolve the interactive terminal the user is sitting at. The NA sidecar's
    # stdin is a pipe, so it cannot use isatty(stdin); pass the real device path.
    import os;
    import sys;

    for stream in (sys.stderr, sys.stdin, sys.stdout) {
        try {
            if stream.isatty() {
                return os.ttyname(stream.fileno());
            }
        } except Exception { }
    }
    return "";
}

def _resolve_tui_command(pkg_root: any, initial: str) -> dict {
    # Map the NA sidecar to a spawn command, validating its presence.
    # Returns {ok, cmd_args, error, hint}.  `initial`, when non-empty, is passed
    # to the sidecar as its first positional arg (the seed prompt).
    import os;

    binary = str(pkg_root / "ai_tui_na" / "bin" / "jac-na-tui");
    if not os.path.exists(binary) {
        return {
            "ok": False,
            "cmd_args": [],
            "error": f"jac-na-tui not found at {binary}",
            "hint": "Build it with:  jac-super/jac_super/ai_tui_na/build.sh",

        };
    }
    cmd_args = [binary];
    if initial {
        cmd_args.append(initial);
    }
    return {"ok": True, "cmd_args": cmd_args, "error": "", "hint": ""};
}

def _spawn_tui_backend(cmd_args: list) -> any {
    # Spawn a sidecar with line-buffered text pipes on stdin/stdout.
    # Own session so keyboard input is not stolen by the parent foreground group.
    # The sidecar opens JAC_AI_TUI_TTY (/dev/pts/N) directly -- not /dev/tty,
    # which fails once setsid() drops the controlling terminal.
    import subprocess;

    return subprocess.Popen(
        cmd_args,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        text=True,
        bufsize=1,
        start_new_session=True,
    );
}

def _esc_text(text: str) -> str {
    return text.replace("\\", "\\\\").replace("\n", "\\n");
}

def _ev_line(ev: dict) -> str {
    ev_id = str(ev.get("id", 0));
    ev_kind = str(ev.get("kind", ""));
    ev_node = str(ev.get("node", ""));
    ev_text = _esc_text(str(ev.get("text", "")));
    return f"EV:{ev_id}:{ev_kind}:{ev_node}:{ev_text}";
}

def _write_frame(pipe: any, frame: dict) {
    parts = [];
    if frame.get("full") {
        parts.append("TYPE:full");
    } else {
        parts.append("TYPE:delta");
    }
    parts.append(f"STATUS:{frame.get('status', '')}");
    parts.append(f"ACTIVE:{frame.get('active', '')}");
    parts.append(f"MODEL:{frame.get('model_name', '')}");
    parts.append(f"NEEDS_KEY:{'1' if frame.get('needs_key') else '0'}");
    parts.append(f"KEY_ENV:{frame.get('key_env', '')}");

    if frame.get("full") {
        for ev in (frame.get("events") or []) {
            parts.append(_ev_line(ev));
        }
    } elif frame.get("ev") {
        parts.append(_ev_line(frame["ev"]));
    }

    parts.append("---");
    try {
        pipe.write("\n".join(parts) + "\n");
        pipe.flush();
    } except Exception { }
}

def _dispatch_cmd(line: str, proc: any, stop_evt: any) {
    # Resolve the UI bridge in this helper's own scope. `run_tui_session()`
    # imports these names lazily for its nested closures, but this dispatcher is
    # module-level and is also called from the cmd-reader thread.
    import from jaclang.cli.ai_agent { ui_send, ui_stop, ui_reset, ui_apply_settings }

    if line.startswith("SEND:") {
        prompt = line[5:];
        try {
            ok = ui_send(prompt);
            _debug_log(f"ui_send({prompt!r}) -> {ok}");
        } except Exception as e {
            _debug_log(f"ui_send({prompt!r}) error: {e}");
        }
    } elif line == "STOP" {
        try {
            ui_stop();
            _debug_log("ui_stop()");
        } except Exception as e {
            _debug_log(f"ui_stop error: {e}");
        }
    } elif line == "RESET" {
        try {
            ui_reset();
            _debug_log("ui_reset()");
        } except Exception as e {
            _debug_log(f"ui_reset error: {e}");
        }
    } elif line == "QUIT" {
        stop_evt.set();
        try {
            ui_stop();
            _debug_log("ui_stop() before quit");
        } except Exception as e {
            _debug_log(f"ui_stop before quit error: {e}");
        }
        try {
            proc.terminate();
            _debug_log("proc.terminate()");
        } except Exception as e {
            _debug_log(f"proc.terminate error: {e}");
        }
    } elif line.startswith("APPLY:") {
        args_str = line[6:];
        settings: dict = {};
        for part in args_str.split(",") {
            eq = part.find("=");
            if eq > 0 {
                k = part[:eq].strip();
                v = part[eq + 1:].strip();
                settings[k] = v;
            }
        }
        try {
            result = ui_apply_settings(
                model=settings.get("model", ""),
                n_ctx=settings.get("n_ctx", ""),
                api_key=settings.get("api_key", ""),
                base_url=settings.get("base_url", ""),
                temperature=settings.get("temperature", ""),
            );
            _debug_log(f"ui_apply_settings({settings}) -> {result}");
        } except Exception as e {
            _debug_log(f"ui_apply_settings({settings}) error: {e}");
        }
    }
}
