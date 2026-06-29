"""Shared helpers for the `jac ai --tui` embed host launch + NA renderer. """

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
        ev = frame["ev"];
        delta = ev.get("_delta");
        if delta is not None {
            # Streaming append: ship only the new token (O(token) not O(full_body)).
            # Sidecar handles EVA by appending to the existing event text.
            ev_id = str(ev.get("id", 0));
            parts.append(f"EVA:{ev_id}:{_esc_text(delta)}");
        } else {
            parts.append(_ev_line(ev));
        }
    }

    parts.append("---");
    return "\n".join(parts);
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
    # stderr first -- matches historical probe order.
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
    import sys;

    stream = _first_tty_stream();
    if stream is None {
        return {"available": False, "device": ""};
    }
    if sys.platform == "win32" {
        return {"available": True, "device": ""};
    }
    try {
        return {"available": True, "device": os.ttyname(stream.fileno())};
    } except Exception {
        return {"available": True, "device": ""};
    }
}


def _require_tty -> str | None {
    # return None on failure. Returns the tty device path on success ('' on Windows).
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


def _restore_ui_env_var(key: str, prev: str | None) {
    import os;

    if prev is None {
        os.environ.pop(key, None);
    } else {
        os.environ[key] = prev;
    }
}


def _configure_ui_env(r: any) -> dict {
    import os;

    project = os.path.normpath(str(r?.cwd or os.getcwd()));
    files_env = _list_project_files(project);
    presets_env = "";
    try {
        import from jaclang.cli.ai_agent { _MODEL_PRESETS }
        presets_env = "\n".join(_MODEL_PRESETS);
    } except Exception { }

    old_project = os.environ.get("JAC_AI_UI_PROJECT", None);
    old_model = os.environ.get("JAC_AI_UI_MODEL", None);
    old_nctx = os.environ.get("JAC_AI_UI_NCTX", None);
    old_files = os.environ.get("JAC_AI_UI_FILES", None);
    old_presets = os.environ.get("JAC_AI_UI_MODEL_PRESETS", None);
    old_resume = os.environ.get("JAC_AI_UI_RESUME", None);
    old_continue = os.environ.get("JAC_AI_UI_CONTINUE", None);
    old_session = os.environ.get("JAC_AI_UI_SESSION", None);
    old_active = os.environ.get("JAC_AI_UI_ACTIVE", None);

    os.environ["JAC_AI_UI_PROJECT"] = project;
    os.environ["JAC_AI_UI_MODEL"] = str(r?.model or "");
    os.environ["JAC_AI_UI_NCTX"] = str(int(r?.n_ctx or 0));
    os.environ["JAC_AI_UI_FILES"] = files_env;
    os.environ["JAC_AI_UI_MODEL_PRESETS"] = presets_env;
    # Session resume controls: forwarded from the AgentRequest so ui_configure
    # can resolve/restore the right session instead of always starting fresh.
    os.environ["JAC_AI_UI_RESUME"] = str(r?.resume or "");
    os.environ["JAC_AI_UI_CONTINUE"] = "1" if bool(r?.continue_last) else "";
    os.environ["JAC_AI_UI_SESSION"] = str(r?.session_name or "");
    os.environ["JAC_AI_UI_ACTIVE"] = "1";

    def _restore_ui_env {
        _restore_ui_env_var("JAC_AI_UI_PROJECT", old_project);
        _restore_ui_env_var("JAC_AI_UI_MODEL", old_model);
        _restore_ui_env_var("JAC_AI_UI_NCTX", old_nctx);
        _restore_ui_env_var("JAC_AI_UI_FILES", old_files);
        _restore_ui_env_var("JAC_AI_UI_MODEL_PRESETS", old_presets);
        _restore_ui_env_var("JAC_AI_UI_RESUME", old_resume);
        _restore_ui_env_var("JAC_AI_UI_CONTINUE", old_continue);
        _restore_ui_env_var("JAC_AI_UI_SESSION", old_session);
        _restore_ui_env_var("JAC_AI_UI_ACTIVE", old_active);
    }

    return {
        "restore": _restore_ui_env,
        "project": project,
        "files_env": files_env,
        "presets_env": presets_env,

    };
}


def _dispatch_cmd(line: str, stop_evt: any, proc: any) {
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


def _resolve_jac_build_bin(pkg_root: any) -> str | None {
    import os;
    import sys;

    explicit = os.environ.get("JAC_BIN", "").strip();
    if explicit and os.path.isfile(explicit) and os.access(explicit, os.X_OK) {
        return explicit;
    }
    repo_root = os.path.normpath(os.path.join(str(pkg_root), "..", "..", ".."));
    jac_name = "jac.exe" if sys.platform == "win32" else "jac";
    repo_jac = os.path.join(repo_root, "jac", "zig-out", "bin", jac_name);
    if os.path.isfile(repo_jac) and os.access(repo_jac, os.X_OK) {
        return repo_jac;
    }
    return None;
}


def _embed_module_dir(name: str) -> str | None {
    # The directory CONTAINING top-level module/package `name`, located WITHOUT
    # importing it (find_spec only) -- so this works even where `name` cannot be
    # imported into *this* interpreter. For a package, that is the parent of its
    # package dir; for a single-file module, the parent of its origin file.
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
    # Locate byLLM + its LLM-stack deps for the embed TUI host's runtime sys.path
    # seams (host_embed.na.jac's _byllm_runtime_hook_py): the fused payload that
    # host carries is jaclang-only, so its embedded interpreter resolves byLLM at
    # launch from these env dirs. Computed by find_spec (never import) so it works
    # from a fused parent where byLLM itself isn't importable. Returns
    # {"src": <dir containing byllm/>, "deps": <os.pathsep-joined dep dirs>}; keys
    # absent when nothing is found (the host then surfaces its own clean hint).
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
    # Ensure the self-hosting embed TUI host (bin/jac-ai-tui) exists -- the sole
    # `jac ai --tui` backend. Installed payloads ship it prebuilt (trailerless,
    # runtime-borrowing); a dev tree compiles the self-contained (trailered) build
    # on first launch via build_embed.sh, mirroring _ensure_na_artifact. Returns
    # {"ok", "path", "error", "hint"}. JAC_AI_TUI_REBUILD=1 forces a rebuild.
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
        # Installed payload: no sources to (re)build from -- trust the prebuilt
        # artifact if present, only fail when there is nothing to launch.
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


def _ensure_na_artifact(
    pkg_root: any, artifact_path: str, source_file: str, label: str
) -> dict {
    # Compile a NA build artifact on first launch when NA sources are present
    # (dev tree); installed packages ship a prebuilt artifact. JAC_AI_TUI_REBUILD=1
    # forces a recompile (dev iteration: pick up edits to *.na.jac without deleting
    # bin/* by hand). build.sh / build.ps1 --quick builds both jac-na-tui and the
    # shared lib, so the same invocation works for either artifact.
    #
    # pkg_root: jaclang/cli/ package root (parent of ai_tui_na/).
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
    build_env = dict(os.environ);
    jac_bin = _resolve_jac_build_bin(pkg_root);
    if jac_bin {
        build_env["JAC_BIN"] = jac_bin;
    }
    try {
        res = subprocess.run(
            build_cmd,
            cwd=na_dir,
            env=build_env,
            capture_output=True,
            text=True,
            timeout=300,
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
