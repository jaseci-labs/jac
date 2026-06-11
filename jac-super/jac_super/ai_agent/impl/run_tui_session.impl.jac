"""Ink TUI launcher for `jac ai --tui`.

Spawns the real Jac API server and the compiled Ink client.
"""
import os;
import shutil;
import signal;
import subprocess;
import sys;
import tempfile;
import time;
import jac_super;
import from pathlib { Path }
import from jaclang.cli.console { console }
import from jac_super.ink_compile.compile { compile_ink_app, CompileError }

impl run_tui_session(req: object) -> int {
    r: any = req;
    super_pkg = Path(jac_super.__file__).parent;
    server_dir = super_pkg / "ai_tui_server";
    ink_dir = super_pkg / "ai_tui_ink";
    ink_out = ink_dir / ".jac" / "tui";
    server_entry = server_dir / "main.jac";
    ink_source = ink_dir / "runtime.cl.jac";
    runner_mjs = ink_out / "runner.mjs";

    if not server_entry.is_file() {
        console.error("Ink TUI server entry is missing", hint=str(server_entry));
        return 1;
    }
    if not ink_source.is_file() {
        console.error("Ink TUI source is missing", hint=str(ink_source));
        return 1;
    }
    if shutil.which("node") is None {
        console.error(
            "`jac ai --tui` requires Node.js 22+", hint="Install Node.js, then retry."
        );
        return 1;
    }
    env = dict(os.environ);
    env["JAC_AI_UI_PROJECT"] = os.path.normpath(str(r?.cwd or os.getcwd()));
    env["JAC_AI_UI_MODEL"] = str(r?.model or "");
    env["JAC_AI_UI_NCTX"] = str(int(r?.n_ctx or 0));
    repo_root = super_pkg.parent.parent;
    py_paths = [
        str(repo_root / name)
        for name in ["jac", "jac-scale", "jac-super"]
        if (repo_root / name).is_dir()
    ];
    existing_py_path = str(env.get("PYTHONPATH", "")).strip();
    if existing_py_path {
        py_paths.append(existing_py_path);
    }
    env["PYTHONPATH"] = os.pathsep.join(
        [
            p
            for p in py_paths
            if p
        ]
    );

    def make_temp(prefix: str, suffix: str = "") -> str {
        path = "";
        try {
            (fd, path) = tempfile.mkstemp(prefix=prefix, suffix=suffix, text=True);
            os.close(fd);
        } except Exception as e {
            console.error(f"Failed to create temp file ({prefix}): {e}");
        }
        return path;
    }

    ready_path = make_temp("jac-ai-tui-port-");
    if not ready_path {
        return 1;
    }

    server_proc: any = None;
    tui_proc: any = None;
    server_log_path = "";
    actual_server_port = 0;
    api_url = "";
    try {
        console.print("");
        console.print(f"  project: {env['JAC_AI_UI_PROJECT']}", style="muted");
        console.print("  starting agent server…", style="muted");

        env["JAC_SERVER_READY_FILE"] = ready_path;
        env["JAC_ALLOW_EPHEMERAL_PORT"] = "1";
        env["JAC_AI_TUI"] = "1";
        server_cmd = (
            "import sys;"
            f" sys.argv = ['jac', 'start', {repr(str(server_entry))}"
            ", '--port', '0'"
            ", '--no_client'];"
            " from jaclang.jac0core.cli_boot import start_cli;"
            " sys.exit(start_cli())"
        );
        # Write server output to a log file, not an unread PIPE — a full pipe
        # blocks console.print in the child and stalls SSE heartbeats.
        server_log_path = make_temp("jac-ai-tui-server-", ".log");
        if not server_log_path {
            return 1;
        }
        server_log_f = open(server_log_path, "w", encoding="utf-8");
        server_proc = subprocess.Popen(
            [sys.executable, "-c", server_cmd],
            cwd=str(server_dir),
            stdout=server_log_f,
            stderr=subprocess.STDOUT,
            text=True,
            env=env,
            start_new_session=True
        );
        server_log_f.close();

        start = time.time();
        deadline = start + 120.0;
        ready = False;
        last_log = start;
        while time.time() < deadline {
            if server_proc.poll() is not None {
                break;
            }
            try {
                if ready_path and os.path.exists(ready_path) {
                    ready_raw = str(
                        Path(ready_path).read_text(encoding="utf-8") or ""
                    ).strip();
                    if ready_raw.isdigit() and int(ready_raw) > 0 {
                        actual_server_port = int(ready_raw);
                        api_url = f"http://127.0.0.1:{actual_server_port}";
                        ready = True;
                        break;
                    }
                }
            } except Exception { }
            now = time.time();
            if now - last_log >= 5.0 {
                elapsed = int(now - start);
                console.print(
                    f"  still compiling modules ({elapsed}s)…", style="muted"
                );
                last_log = now;
            }
            time.sleep(0.05);
        }

        if not ready {
            err_tail = "";
            try {
                if server_log_path {
                    err_tail = "\n".join(
                        Path(server_log_path).read_text(encoding="utf-8").splitlines()[-25:]
                    ).strip();
                }
            } except Exception { }
            if server_proc.poll() is None {
                console.error("Agent server did not start within 120s");
            } else {
                console.error("Agent server exited during startup");
            }
            if err_tail {
                console.print(err_tail, style="muted");
            }
            return 1;
        }

        ink_compile_dir = super_pkg / "ink_compile";
        compile_jac = ink_compile_dir / "compile.jac";
        bundle_patch_jac = ink_compile_dir / "bundle_patch.jac";
        ink_jac_toml = ink_dir / "jac.toml";
        sources = [ink_source, compile_jac, bundle_patch_jac];
        if ink_jac_toml.is_file() {
            sources.append(ink_jac_toml);
        }
        need_compile = not runner_mjs.is_file();
        if not need_compile {
            runner_mtime = runner_mjs.stat().st_mtime;
            for src in sources {
                if src.is_file() and src.stat().st_mtime > runner_mtime {
                    need_compile = True;
                    break;
                }
            }
        }
        if need_compile {
            console.print("  compiling Ink TUI…", style="muted");
            try {
                compile_ink_app(ink_source, ink_out);
            } except CompileError as e {
                console.error(f"Ink TUI compilation failed: {e}");
                return 1;
            } except Exception as e {
                console.error(f"Ink TUI compilation failed: {e}");
                return 1;
            }
        }

        pkg_json = ink_out / "package.json";
        node_modules = ink_out / "node_modules";
        first_install = not node_modules.is_dir();
        need_install = first_install;
        if not need_install and pkg_json.is_file() {
            if need_compile
            or pkg_json.stat().st_mtime > node_modules.stat().st_mtime {
                need_install = True;
            }
        }
        if need_install {
            if first_install {
                console.print(
                    "  installing Ink dependencies (first run)…", style="muted"
                );
            } else {
                console.print("  syncing Ink dependencies…", style="muted");
            }
            if shutil.which("npm") is None {
                console.error(
                    "`jac ai --tui` requires npm for Ink dependencies",
                    hint="Install npm, then retry."
                );
                return 1;
            }
            install_ret = subprocess.call(
                ["npm", "install", "--ignore-scripts"], cwd=str(ink_out)
            );
            if install_ret != 0 {
                console.error("npm install failed for Ink TUI");
                return 1;
            }
        }

        tui_env = dict(os.environ);
        tui_env["JAC_TUI_API_URL"] = api_url;
        tui_env["JAC_TUI_CWD"] = env["JAC_AI_UI_PROJECT"];
        initial = str(r?.prompt or "").strip();
        if initial {
            tui_env["JAC_TUI_INITIAL_PROMPT"] = initial;
        }

        if server_log_path {
            console.print(f"  server logs: {server_log_path}", style="muted");
        }
        console.print("  launching TUI…", style="muted");
        tui_proc = subprocess.Popen(
            ["node", "runner.mjs"], cwd=str(ink_out), env=tui_env
        );
        try {
            return tui_proc.wait();
        } except KeyboardInterrupt {
            return 130;
        }
    } except KeyboardInterrupt {
        return 130;
    } except Exception as e {
        console.error(f"Failed to launch Ink TUI: {e}");
        return 1;
    } finally {
        if ready_path {
            try {
                os.unlink(ready_path);
            } except Exception { }
        }
        if tui_proc and tui_proc.poll() is None {
            try {
                tui_proc.terminate();
            } except Exception { }
            try {
                tui_proc.wait(timeout=5);
            } except Exception {
                try {
                    tui_proc.kill();
                } except Exception { }
            }
        }
        if server_proc and server_proc.poll() is None {
            try {
                os.killpg(os.getpgid(server_proc.pid), signal.SIGTERM);
            } except Exception { }
        }
    }
}
