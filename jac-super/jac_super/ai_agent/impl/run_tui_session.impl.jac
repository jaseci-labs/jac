"""Spawn the NA-native TUI binary as a subprocess sidecar for `jac ai --tui`.

IPC overview:
  Python feeds ui_stream() frames to the binary's stdin as key:value lines
  terminated by "---".  The binary sends single-line commands to Python via
  its stdout (SEND:, STOP, RESET, QUIT, APPLY:).

Frame format (Python -> binary):
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

impl run_tui_session(req: any) -> int {
    import os;
    import subprocess;
    import threading;
    import from pathlib { Path }
    import from jaclang.cli.ai_agent {
        ui_configure,
        ui_send,
        ui_stop,
        ui_reset,
        ui_apply_settings,
        ui_stream
    }
    import from jaclang.cli.console { console }

    # run_tui_session.jac lives in jac_super/ai_agent/; binary in jac_super/ai_tui_na/
    pkg_root = Path(__file__).resolve().parent.parent;
    binary = str(pkg_root / "ai_tui_na" / "bin" / "jac-na-tui");

    if not os.path.exists(binary) {
        console.error(f"jac-na-tui not found at {binary}");
        console.error("Build it with:  jac-super/jac_super/ai_tui_na/build.sh");
        return 1;
    }

    r: any = req;
    project = os.path.normpath(str(r?.cwd or os.getcwd()));
    os.environ["JAC_AI_UI_PROJECT"] = project;
    os.environ["JAC_AI_UI_MODEL"] = str(r?.model or "");
    os.environ["JAC_AI_UI_NCTX"] = str(int(r?.n_ctx or 0));

    ui_configure();

    initial = str(r?.prompt or "").strip();
    cmd_args = [binary];
    if initial {
        cmd_args.append(initial);
    }

    try {
        proc = subprocess.Popen(
            cmd_args,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            text=True,
            bufsize=1,
        );
        _debug_log(f"spawned pid={proc.pid} binary={binary}");
    } except Exception as e {
        _debug_log(f"launch failed: {e}");
        console.error(f"Failed to launch jac-na-tui: {e}");
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
