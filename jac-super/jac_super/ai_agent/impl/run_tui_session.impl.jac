"""Spawn a TUI renderer sidecar as a subprocess for `jac ai --tui`.

This module is the *backend-agnostic seam* between the Jac/Python agent control
plane and a renderer sidecar.  The control plane streams UI frames to the
sidecar's stdin and reads single-line commands back from its stdout.  Which
renderer is spawned is selected by `JAC_AI_TUI_BACKEND` (default: "js").

Backends:
  js   OpenTUI renderer authored in Jac under ai_tui_js/  (default)
  na   Native (nacompile'd) OpenTUI renderer under ai_tui_na/  (fallback)

When the env is unset (js implicit default) and js isn't launchable yet - `bun`
missing or `ai_tui_js/dist/` not built - the launcher transparently falls back to
na so `jac ai --tui` keeps working.  An *explicitly* requested backend is never
overridden; its failure is surfaced as-is.

The wire protocol is identical across backends and is documented authoritatively
in ai_tui/PROTOCOL.md (frames + commands) and ai_tui/BACKENDS.md (selection).

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
    import from jaclang.cli.ai_agent { ui_configure, ui_stop, ui_stream }
    import from jaclang.cli.console { console }

    # run_tui_session.jac lives in jac_super/ai_agent/; sidecars in jac_super/ai_tui_*/
    pkg_root = Path(__file__).resolve().parent.parent;

    typed_req: AgentRequest = req;
    r: any = typed_req;
    initial = str(r?.prompt or "").strip();

    backend = _resolve_tui_backend();
    resolved = _resolve_tui_command(backend, pkg_root, initial);

    # Auto-fallback: when js is the implicit default (env unset) but isn't
    # launchable - bun missing or dist/ not built - transparently retry na so the
    # cutover doesn't hard-break environments that haven't built the js sidecar.
    # An explicitly requested backend is honored even when it fails.
    explicit_backend = os.environ.get("JAC_AI_TUI_BACKEND", "").strip();
    if (not resolved.get("ok")) and backend == "js" and (not explicit_backend) {
        na_resolved = _resolve_tui_command("na", pkg_root, initial);
        if na_resolved.get("ok") {
            _debug_log(
                "js backend unavailable (" + str(resolved.get("error", "")) + "); falling back to na"
            );
            console.error(
                "jac ai TUI: js backend unavailable, falling back to na " + "(set JAC_AI_TUI_BACKEND=js to see the underlying error)."
            );
            backend = "na";
            resolved = na_resolved;
        }
    }

    if not resolved.get("ok") {
        console.error(str(resolved.get("error", "failed to resolve TUI backend")));
        hint = str(resolved.get("hint", ""));
        if hint {
            console.error(hint);
        }
        return 1;
    }
    cmd_args = resolved.get("cmd_args");

    project = os.path.normpath(str(r?.cwd or os.getcwd()));
    os.environ["JAC_AI_UI_PROJECT"] = project;
    os.environ["JAC_AI_UI_MODEL"] = str(r?.model or "");
    os.environ["JAC_AI_UI_NCTX"] = str(int(r?.n_ctx or 0));
    old_active = os.environ.get("JAC_AI_UI_ACTIVE");
    os.environ["JAC_AI_UI_ACTIVE"] = "1";

    ui_configure();

    try {
        proc = _spawn_tui_backend(cmd_args);
        _debug_log(f"spawned pid={proc.pid} backend={backend} cmd={cmd_args}");
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
        console.error(f"Failed to launch jac ai TUI backend ({backend}): {e}");
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

def _resolve_tui_backend -> str {
    # Select the renderer sidecar via JAC_AI_TUI_BACKEND (default: js).
    import os;

    backend = os.environ.get("JAC_AI_TUI_BACKEND", "").strip().lower();
    if not backend {
        backend = "js";
    }
    return backend;
}

def _resolve_tui_command(backend: str, pkg_root: any, initial: str) -> dict {
    # Map a backend name to a spawn command, validating its presence.
    # Returns {ok, cmd_args, error, hint}.  `initial`, when non-empty, is passed
    # to the sidecar as its first positional arg (the seed prompt).
    import os;

    if backend == "na" {
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

    if backend == "js" {
        # OpenTUI JS sidecar authored in Jac (.cl.jac -> JS via ai_tui_js/build.sh).
        # Runtime defaults to bun; override with JAC_AI_TUI_JS_RUNTIME.
        runtime = os.environ.get("JAC_AI_TUI_JS_RUNTIME", "").strip() or "bun";
        entry = str(pkg_root / "ai_tui_js" / "dist" / "main.js");
        if not os.path.exists(entry) {
            return {
                "ok": False,
                "cmd_args": [],
                "error": f"jac ai JS TUI sidecar not built at {entry}",
                "hint": "Build it: (cd jac_super/ai_tui_js && bun install && " + "./build.sh), or set JAC_AI_TUI_BACKEND=na.",

            };
        }
        cmd_args = [runtime, "run", entry];
        if initial {
            cmd_args.append(initial);
        }
        return {"ok": True, "cmd_args": cmd_args, "error": "", "hint": ""};
    }

    return {
        "ok": False,
        "cmd_args": [],
        "error": f"unknown TUI backend: {backend!r}",
        "hint": "Set JAC_AI_TUI_BACKEND to 'na' or 'js'.",

    };
}

def _spawn_tui_backend(cmd_args: list) -> any {
    # Spawn a sidecar with line-buffered text pipes on stdin/stdout.
    import subprocess;

    return subprocess.Popen(
        cmd_args, stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, bufsize=1,
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
