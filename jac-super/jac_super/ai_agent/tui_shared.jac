"""Shared helpers for both `jac ai --tui` backends.

The frame/command grammar (ai_tui/PROTOCOL.md) is identical across the subprocess
and in-process transports; only the carrier differs. These helpers are the one
copy of the wire grammar + command dispatcher + project-file/tty plumbing that
`run_tui_session` (subprocess) and `run_tui_in_process` (in-process) both import,
so the two backends can never drift on the protocol. See PLAN-tui-in-process
§3/§6/§12.

`_frame_blob` is the body of the old `_write_frame` (it joins the same KEY:VALUE
lines, just returns the string instead of flushing it to a pipe). `_dispatch_cmd`
is the shared command dispatcher: it takes an optional `proc` so the subprocess
backend can still `terminate()` on QUIT while the in-process backend passes
`None` (quit there flows through `stop_evt` + the native `tui_quit_requested`).

`_configure_ui_env` is the one copy of the JAC_AI_UI_* env contract
(PROJECT/MODEL/NCTX/FILES/MODEL_PRESETS plus the JAC_AI_UI_ACTIVE=1 capture
gate). Both backends set this exact block before `ui_configure()`; the helper
returns the computed project/files/presets (the in-process backend hands them to
`host.start`) and a zero-arg `restore` closure that unwinds JAC_AI_UI_ACTIVE,
so the two backends cannot drift on the env contract.

`_ensure_na_artifact` is the one copy of the NA build-artifact ensure logic
(compile `bin/jac-na-tui` / `bin/libtui.so` from `*.na.jac` on first launch);
both backends' `_ensure_tui_binary` / `_ensure_tui_lib` delegate to it so the
build contract cannot drift between them.
"""

def _debug_log(msg: str) -> None {
    # Append-only trace, enabled only when JAC_AI_TUI_DEBUG_LOG points at a file.
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


def _frame_blob(frame: dict) -> str {
    # Build the exact KEY:VALUE\n...\n--- text PROTOCOL.md specifies. The
    # subprocess path writes this to the sidecar's stdin; the in-process path
    # hands it to tui_apply_frame via ctypes. Byte-for-byte identical either way.
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
    return "\n".join(parts);
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


def _any_stream_is_tty -> bool {
    # Single isatty probe shared by _sidecar_tty_device (POSIX) and
    # _tty_is_available (Windows). stderr first — matches historical probe order.
    import sys;

    for stream in (sys.stderr, sys.stdin, sys.stdout) {
        try {
            if stream.isatty() {
                return True;
            }
        } except Exception { }
    }
    return False;
}


def _sidecar_tty_device -> str {
    # Resolve the interactive terminal the user is sitting at. Both backends use
    # it: the subprocess sidecar gets it via JAC_AI_TUI_TTY (its stdin is a pipe);
    # the in-process host opens it directly with tui_init's tty_dev arg.
    #
    # On Windows there is no /dev/pts path — return "" and let tty_open_dev("")
    # attach the parent console. Availability is checked separately via
    # _tty_is_available (which calls _any_stream_is_tty on win32).
    import os;
    import sys;

    if sys.platform == "win32" {
        return "";
    }
    for stream in (sys.stderr, sys.stdin, sys.stdout) {
        try {
            if stream.isatty() {
                return os.ttyname(stream.fileno());
            }
        } except Exception { }
    }
    return "";
}


def _tty_is_available(tty_dev: str) -> bool {
    # True when the process has an interactive terminal. On POSIX, `tty_dev`
    # is the non-empty path from `_sidecar_tty_device`. On Windows, `tty_dev`
    # is always "" — probe streams via the shared _any_stream_is_tty helper.
    import sys;

    if sys.platform == "win32" {
        return _any_stream_is_tty();
    }
    return bool(tty_dev);
}


def _configure_ui_env(r: any) -> dict {
    # Set the JAC_AI_UI_* env contract shared by both `jac ai --tui` backends and
    # gate agent bus capture with JAC_AI_UI_ACTIVE=1. The agent reads these on
    # ui_configure(); the native sidecar/host reads PROJECT/MODEL/NCTX/FILES/
    # MODEL_PRESETS at startup. Returns the computed project/files_env/presets_env
    # (the in-process backend hands them to host.start) plus a zero-arg `restore`
    # closure that unwinds JAC_AI_UI_ACTIVE to its prior value, so each backend
    # restores the env on every exit path without duplicating the save/restore
    # dance. One copy here = the two backends cannot drift on the env contract.
    import os;
    import from jaclang.cli.ai_agent { _MODEL_PRESETS }

    project = os.path.normpath(str(r?.cwd or os.getcwd()));
    files_env = _list_project_files(project);
    presets_env = "\n".join(_MODEL_PRESETS);

    os.environ["JAC_AI_UI_PROJECT"] = project;
    os.environ["JAC_AI_UI_MODEL"] = str(r?.model or "");
    os.environ["JAC_AI_UI_NCTX"] = str(int(r?.n_ctx or 0));
    os.environ["JAC_AI_UI_FILES"] = files_env;
    os.environ["JAC_AI_UI_MODEL_PRESETS"] = presets_env;

    old_active = os.environ.get("JAC_AI_UI_ACTIVE");
    os.environ["JAC_AI_UI_ACTIVE"] = "1";

    def _restore_active {
        if old_active is None {
            os.environ.pop("JAC_AI_UI_ACTIVE", None);
        } else {
            os.environ["JAC_AI_UI_ACTIVE"] = old_active;
        }
    }

    return {
        "restore": _restore_active,
        "project": project,
        "files_env": files_env,
        "presets_env": presets_env,

    };
}


def _dispatch_cmd(line: str, stop_evt: any, proc: any) {
    # Map one command line (SEND:/STOP/RESET/QUIT/APPLY:) onto the agent UI API.
    # Shared by both backends. `proc` is the subprocess handle for the subprocess
    # backend (terminated on QUIT) and None for the in-process backend, where quit
    # is signalled purely through stop_evt + the native tui_quit_requested poll.
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
        if proc is not None {
            try {
                proc.terminate();
                _debug_log("proc.terminate()");
            } except Exception as e {
                _debug_log(f"proc.terminate error: {e}");
            }
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


def _ensure_na_artifact(
    pkg_root: any, artifact_path: str, source_file: str, label: str
) -> dict {
    # Compile a NA build artifact on first launch when NA sources are present
    # (dev tree); installed packages ship a prebuilt artifact. JAC_AI_TUI_REBUILD=1
    # forces a recompile (dev iteration: pick up edits to *.na.jac without deleting
    # bin/* by hand). build.sh / build.ps1 --quick builds both jac-na-tui and the
    # shared lib, so the same invocation works for either artifact.
    #
    # pkg_root: jac_super/ package root (parent of ai_tui_na/).
    # artifact_path: full path to the built artifact -- also used in error messages.
    # source_file: full path to a NA source file used to detect a dev tree.
    # label: human-readable name used in console messages and error hints.
    import os;
    import sys;
    import subprocess;
    import from jaclang.cli.console { console }

    exists = os.path.exists(artifact_path);
    force = os.environ.get("JAC_AI_TUI_REBUILD", "").strip().lower() in (
        "1",
        "true",
        "yes",
        "on"
    );
    if exists and not force {
        return {"ok": True, "error": "", "hint": ""};
    }
    na_dir = str(pkg_root / "ai_tui_na");
    build_sh = str(pkg_root / "ai_tui_na" / "build.sh");
    build_ps1 = str(pkg_root / "ai_tui_na" / "build.ps1");

    # Select the build script and command for this platform.
    if sys.platform == "win32" {
        build_script = build_ps1;
        build_cmd = [
            "powershell",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            build_ps1,
            "-Quick"
        ];
        manual_hint = f"powershell -ExecutionPolicy Bypass -File {build_ps1} -Quick";
    } else {
        build_script = build_sh;
        build_cmd = ["bash", build_sh, "--quick"];
        manual_hint = f"{build_sh} --quick";
    }

    if not os.path.isfile(source_file) or not os.path.isfile(build_script) {
        # No sources to (re)build from. Use a prebuilt artifact if present
        # (installed package); only fail when there is nothing to load.
        if exists {
            return {"ok": True, "error": "", "hint": ""};
        }
        return {
            "ok": False,
            "error": f"{label} not found at {artifact_path}",
            "hint": f"Build it with: {manual_hint}",

        };
    }
    if force and exists {
        console.print(
            f"[tui] JAC_AI_TUI_REBUILD set; recompiling {label} ...", style="dim"
        );
    } else {
        console.print(f"[tui] {label} missing; compiling (first run) ...", style="dim");
    }
    try {
        res = subprocess.run(
            build_cmd, cwd=na_dir, capture_output=True, text=True, timeout=300,
        );
        if res.returncode != 0 {
            detail = (res.stderr or res.stdout or "").strip();
            if detail {
                console.error(detail);
            }
            return {
                "ok": False,
                "error": f"{label} compile failed",
                "hint": f"Run manually: {manual_hint}",

            };
        }
    } except Exception as e {
        return {
            "ok": False,
            "error": f"{label} compile failed: {e}",
            "hint": f"Run manually: {manual_hint}",

        };
    }
    if not os.path.exists(artifact_path) {
        return {
            "ok": False,
            "error": f"{label} not found at {artifact_path} after compile",
            "hint": f"Run manually: {manual_hint}",

        };
    }
    return {"ok": True, "error": "", "hint": ""};
}
