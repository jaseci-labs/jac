import from jaclang.cli.ai_tui.ipc_schema {
    FIELD_TYPE,
    FIELD_STATUS,
    FIELD_ACTIVE,
    FIELD_MODEL,
    FIELD_NEEDS_KEY,
    FIELD_KEY_ENV,
    FIELD_EV,
    FIELD_EVA,
    FIELD_LEN,
    FTYPE_FULL,
    FTYPE_DELTA,
    FTYPE_HB,
    CMD_SEND,
    CMD_STOP,
    CMD_RESET,
    CMD_QUIT,
    CMD_APPLY,
    FRAME_SEP
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
    return f"{FIELD_EV}:{ev_id}:{ev_kind}:{ev_node}:{ev_text}";
}


def _frame_blob(frame: dict) -> str {
    parts = [];
    if frame.get("full") {
        parts.append(f"{FIELD_TYPE}:{FTYPE_FULL}");
    } else {
        parts.append(f"{FIELD_TYPE}:{FTYPE_DELTA}");
    }
    parts.append(f"{FIELD_STATUS}:{frame.get('status', '')}");
    parts.append(f"{FIELD_ACTIVE}:{frame.get('active', '')}");
    parts.append(f"{FIELD_MODEL}:{frame.get('model_name', '')}");
    parts.append(f"{FIELD_NEEDS_KEY}:{'1' if frame.get('needs_key') else '0'}");
    parts.append(f"{FIELD_KEY_ENV}:{frame.get('key_env', '')}");

    if frame.get("full") {
        for ev in (frame.get("events") or []) {
            parts.append(_ev_line(ev));
        }
    } elif frame.get("ev") {
        ev = frame["ev"];
        delta = ev.get("_delta");
        if delta is not None {
            ev_id = str(ev.get("id", 0));
            parts.append(f"{FIELD_EVA}:{ev_id}:{_esc_text(delta)}");
        } else {
            parts.append(_ev_line(ev));
        }
    }

    body = "\n".join(parts);
    return f"{FIELD_LEN}:{len(parts)}\n{body}\n{FRAME_SEP}";
}


def _list_project_files(project: str) -> str {
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


def _first_tty_stream -> object {
    import sys;

    for stream in (sys.stderr, sys.stdin, sys.stdout) {
        try {
            if stream.isatty() {
                return stream;
            }
        } except Exception { }
    }
    return None;
}


def _probe_tty -> dict {
    import os;

    stream = _first_tty_stream();
    if stream is None {
        return {"available": False, "device": ""};
    }
    try {
        return {"available": True, "device": os.ttyname(stream.fileno())};
    } except Exception {
        return {"available": True, "device": ""};
    }
}


def _require_tty -> str | None {
    import from jaclang.cli.console { console }
    probe = _probe_tty();
    if not probe["available"] {
        console.error(
            "jac ai --tui needs an interactive terminal (stdin or stderr must be a TTY)"
        );
        return None;
    }
    return probe["device"];
}


def _configure_ui_env(r: any) {
    import os;

    project = os.path.normpath(str(r?.cwd or os.getcwd()));
    files_env = _list_project_files(project);
    presets_env = "";
    try {
        import from jaclang.cli.ai_agent { _MODEL_PRESETS }
        presets_env = "\n".join(_MODEL_PRESETS);
    } except Exception { }

    os.environ["JAC_AI_UI_PROJECT"] = project;
    os.environ["JAC_AI_UI_MODEL"] = str(r?.model or "");
    os.environ["JAC_AI_UI_NCTX"] = str(int(r?.n_ctx or 0));
    os.environ["JAC_AI_UI_FILES"] = files_env;
    os.environ["JAC_AI_UI_MODEL_PRESETS"] = presets_env;
}


def _cmd_send(payload: str, stop_evt: any, proc: any) {
    import from jaclang.cli.ai_agent { ui_send }
    try {
        _debug_log(f"ui_send({payload!r}) -> {ui_send(payload)}");
    } except Exception as e {
        _debug_log(f"ui_send({payload!r}) error: {e}");
    }
}

def _cmd_stop(payload: str, stop_evt: any, proc: any) {
    import from jaclang.cli.ai_agent { ui_stop }
    try {
        ui_stop();
        _debug_log("ui_stop()");
    } except Exception as e {
        _debug_log(f"ui_stop error: {e}");
    }
}

def _cmd_reset(payload: str, stop_evt: any, proc: any) {
    import from jaclang.cli.ai_agent { ui_reset }
    try {
        ui_reset();
        _debug_log("ui_reset()");
    } except Exception as e {
        _debug_log(f"ui_reset error: {e}");
    }
}

def _cmd_quit(payload: str, stop_evt: any, proc: any) {
    import from jaclang.cli.ai_agent { ui_stop }
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
}

def _cmd_apply(payload: str, stop_evt: any, proc: any) {
    import from jaclang.cli.ai_agent { ui_apply_settings }
    settings: dict = {};
    for part in payload.split(",") {
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

glob _CMD_HANDLERS: dict = {
         CMD_SEND: _cmd_send,
         CMD_STOP: _cmd_stop,
         CMD_RESET: _cmd_reset,
         CMD_QUIT: _cmd_quit,
         CMD_APPLY: _cmd_apply,

     };

def _dispatch_cmd(line: str, stop_evt: any, proc: any) {
    colon = line.find(":");
    if colon > 0 {
        token = line[:colon];
        payload = line[colon + 1:];
    } else {
        token = line;
        payload = "";
    }
    handler = _CMD_HANDLERS.get(token);
    if handler is not None {
        handler(payload, stop_evt, proc);
    }
}


def _resolve_jac_build_bin(pkg_root: any) -> str | None {
    import os;

    explicit = os.environ.get("JAC_BIN", "").strip();
    if explicit and os.path.isfile(explicit) and os.access(explicit, os.X_OK) {
        return explicit;
    }
    repo_root = os.path.normpath(os.path.join(str(pkg_root), "..", "..", ".."));
    repo_jac = os.path.join(repo_root, "jac", "zig-out", "bin", "jac");
    if os.path.isfile(repo_jac) and os.access(repo_jac, os.X_OK) {
        return repo_jac;
    }
    return None;
}


def _embed_module_dir(name: str) -> str | None {
    import os;
    import from importlib { util }

    try {
        spec = util.find_spec(name);
    } except Exception {
        return None;
    }
    if spec is None {
        return None;
    }
    locs = spec?.submodule_search_locations;
    if locs {
        for loc in locs {
            if loc {
                return os.path.dirname(str(loc));
            }
        }
    }
    origin = spec?.origin;
    if origin and origin not in ("built-in", "frozen") {
        return os.path.dirname(str(origin));
    }
    return None;
}


def _embed_byllm_seams -> dict {
    import os;

    out: dict = {};
    src = _embed_module_dir("byllm");
    if src {
        out["src"] = src;
    }

    dep_dirs: list = [];
    for mod in [
        "litellm",
        "openai",
        "pydantic",
        "pydantic_core",
        "tokenizers",
        "httpx",
        "tiktoken"
    ] {
        d = _embed_module_dir(mod);
        if d and d not in dep_dirs {
            dep_dirs.append(d);
        }
    }
    if dep_dirs {
        out["deps"] = os.pathsep.join(dep_dirs);
    }
    return out;
}


def _ensure_embed_host(cli_root: any) -> dict {
    import os;
    import subprocess;
    import from jaclang.cli.console { console }

    na_dir = str(cli_root / "ai_tui_na");
    artifact = os.path.join(na_dir, "bin", "jac-ai-tui");
    source = os.path.join(na_dir, "host_embed.na.jac");
    build_sh = os.path.join(na_dir, "build_embed.sh");
    manual_hint = f"bash {build_sh}";

    force = os.environ.get("JAC_AI_TUI_REBUILD", "").strip().lower() in (
        "1",
        "true",
        "yes",
        "on"
    );
    exists = os.path.exists(artifact);
    if exists and not force {
        return {"ok": True, "path": artifact, "error": "", "hint": ""};
    }
    if not os.path.isfile(source) or not os.path.isfile(build_sh) {
        if exists {
            return {"ok": True, "path": artifact, "error": "", "hint": ""};
        }
        return {
            "ok": False,
            "path": artifact,
            "error": f"embed TUI host not found at {artifact}",
            "hint": f"Build it with: {manual_hint}",

        };
    }
    if force and exists {
        console.print(
            "[tui] JAC_AI_TUI_REBUILD set; rebuilding embed host ...", style="dim"
        );
    } else {
        console.print(
            "[tui] embed host missing; compiling (first run, ~1-2 min) ...", style="dim"
        );
    }
    build_env = dict(os.environ);
    jac_bin = _resolve_jac_build_bin(cli_root);
    if jac_bin {
        build_env["JAC_BIN"] = jac_bin;
    }
    try {
        res = subprocess.run(
            ["bash", build_sh],
            cwd=na_dir,
            env=build_env,
            capture_output=True,
            text=True,
            timeout=900,
        );
        if res.returncode != 0 {
            detail = (res.stderr or res.stdout or "").strip();
            if detail {
                console.error(detail);
            }
            return {
                "ok": False,
                "path": artifact,
                "error": "embed TUI host compile failed",
                "hint": f"Run manually: {manual_hint}",

            };
        }
    } except Exception as e {
        return {
            "ok": False,
            "path": artifact,
            "error": f"embed TUI host compile failed: {e}",
            "hint": f"Run manually: {manual_hint}",

        };
    }
    if not os.path.exists(artifact) {
        return {
            "ok": False,
            "path": artifact,
            "error": f"embed TUI host not found at {artifact} after compile",
            "hint": f"Run manually: {manual_hint}",

        };
    }
    return {"ok": True, "path": artifact, "error": "", "hint": ""};
}
