import json;
import os;
import shutil;
import socket;
import subprocess;
import from pathlib { Path }
import from typing { Any, cast }
import from jaclang.cli.console { console }
import from jaclang.runtimelib.watcher { FileChangeEvent }
import from jaclang.runtimelib.client.config_loader { JacClientConfig }
import from jaclang.runtimelib.client.targets.mobile.common {
    SUBPROCESS_TIMEOUT_SHORT,
    _resolve_npx
}

def _get_api_base_url_str(project_dir: Path) -> str {
    loader = JacClientConfig(project_dir);
    return loader.get_api_config().get("base_url", "") or "";
}

def _assert_mobile_port_available(port: int, role: str) {
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM);
    try {
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1);
        s.bind(("0.0.0.0", port));
    } except OSError as e {
        raise RuntimeError(
            f"{role} port {port} is already in use ({e}). Mobile dev needs "
            "deterministic ports so adb reverse and capacitor.config.json "
            "match what the server actually binds. Stop the conflicting "
            f"process, choose a different port (e.g. --port {port + 100}), "
            f"or set [plugins.client].vite.server.port in jac.toml."
        );
    } finally {
        s.close();
    }
}

def _warn_mobile_dev_api_url(project_dir: Path) {
    base = _get_api_base_url_str(project_dir);
    if base {
        if ("localhost" in base.lower()) or ("127.0.0.1" in base) {
            console.warning(
                "  Physical devices cannot reach localhost on your PC. "
                "Clear [plugins.client.api] base_url for same-origin dev proxy, "
                "or set base_url to your machine's LAN URL."
            );
        }
    }
}

def _mobile_read_dev_env -> tuple[str, str] {
    host_ov = os.environ.get("JAC_MOBILE_DEV_HOST", "");
    plat_mode = os.environ.get("JAC_MOBILE_PLATFORM", "auto");
    return (host_ov, plat_mode);
}

def _mobile_setup_android_port_reverse(vite_port: int, server_port: int) {
    if not shutil.which("adb") {
        return;
    }

    def _try_adb_reverse_port(port: int) {
        cmd = ["adb", "reverse", f"tcp:{port}", f"tcp:{port}"];
        try {
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=SUBPROCESS_TIMEOUT_SHORT,
                check=False
            );
            if result.returncode == 0 {
                console.print(
                    f"  ✔ adb reverse tcp:{port} tcp:{port}", style="success"
                );
            } else {
                err = (result.stderr or "").strip() or "unknown adb error";
                console.warning(f"  ⚠ adb reverse failed for tcp:{port} ({err})");
            }
        } except Exception as e {
            console.warning(f"  ⚠ adb reverse failed for tcp:{port} ({e})");
        }
    }

    _try_adb_reverse_port(vite_port);
    if server_port != vite_port {
        _try_adb_reverse_port(server_port);
    }
}

def _mobile_ensure_watchdog -> bool {
    try {
        import watchdog;
        return True;
    } except ImportError {
        console.warning(
            "  watchdog not installed - saving .jac files will not refresh the WebView. "
            "Install with: pip install 'watchdog>=3.0.0' (or add to [dev-dependencies]).",
            style="muted"
        );
        return False;
    }
}

def _mobile_invalidate_runtime_module_cache(paths: list[str]) -> None {
    try {
        import from jaclang { JacRuntime as Jac }
        program = Jac.program;
        if not program or not program.mod or not program.mod.hub {
            return;
        }
        hub = program.mod.hub;
        norm_targets: set[str] = set();
        for p in paths {
            if not p {
                continue;
            }
            try {
                norm_targets.add(os.path.normcase(str(Path(p).resolve())));
            } except Exception {
                norm_targets.add(os.path.normcase(str(p)));
            }
        }
        if not norm_targets {
            return;
        }
        to_delete: list[str] = [];
        for k in list(hub.keys()) {
            if os.path.normcase(str(k)) in norm_targets {
                to_delete.append(k);
            }
        }
        for k in to_delete {
            del hub[k];
        }
    } except Exception {
        return;
    }
}

def _mobile_hmr_on_jac_changed(
    event: FileChangeEvent, compiler: any, entry_file: Path, project_dir: Path
) -> None {
    try {
        pth = event.path or "";
        if not pth {
            return;
        }
        if not pth.endswith(".jac") {
            return;
        }
        try {
            Path(pth).resolve().relative_to(project_dir.resolve());
        } except ValueError {
            return;
        }
        _mobile_invalidate_runtime_module_cache([pth, str(entry_file)]);
        compile_out = cast(Any, compiler.jac_compiler.compile_module(entry_file));
        mod2 = compile_out[1];
        if not mod2 {
            return;
        }
        compiler.compile(mod2, entry_file);
        try {
            console.print("  ✔ Client recompiled after save", style="success");
        } except Exception { }
    } except Exception as e {
        try {
            console.error(f"  HMR recompile failed: {e}");
        } except Exception { }
    }
}

def _mobile_start_backend_server(
    entry_file: Path, project_dir: Path, port: int
) -> any {
    import sys;
    return subprocess.Popen(
        [
            sys.executable,
            "-m",
            "jaclang",
            "start",
            str(entry_file),
            "--port",
            str(port),
            "--no_client"
        ],
        cwd=str(project_dir),
        stdout=None,
        stderr=None
    );
}

def _inject_capacitor_dev_url(project_dir: Path, dev_url: str) -> str | None {
    config_path = project_dir / "capacitor.config.json";
    if not config_path.exists() {
        return None;
    }
    t = config_path.read_text(encoding="utf-8");
    original = t;
    try {
        cfg = json.loads(t);
    } except Exception {
        return None;
    }
    server = cfg.get("server", {});
    server["url"] = dev_url;
    server["cleartext"] = True;
    cfg["server"] = server;
    config_path.write_text(json.dumps(cfg, indent=2), encoding="utf-8");
    console.print(
        f"  ✔ capacitor.config.json → server.url = {dev_url}", style="success"
    );
    return original;
}

def _restore_capacitor_config(project_dir: Path, original: str | None) -> None {
    if original is None {
        return;
    }
    config_path = project_dir / "capacitor.config.json";
    config_path.write_text(original, encoding="utf-8");
    console.print("  ✔ Restored capacitor.config.json", style="muted");
}

def _run_cap_run_live_reload(
    project_dir: Path, plat: str, _lr_host: str, _lr_port: int
) -> int {
    npx = _resolve_npx();
    cmd = [npx, "cap", "run", plat];
    console.print(f"  Running: {' '.join(cmd)}", style="muted");
    console.print("  (Press Ctrl+C to stop)\n", style="muted");
    result = subprocess.run(cmd, cwd=project_dir, check=False);
    return result.returncode;
}

def _describe_cap_run_completion(rc: int, dev_url: str) -> dict {
    if rc == 0 {
        return {
            "ok": True,
            "messages": [
                "📱 App deployed. Vite + API servers running.",
                f"WebView loads: {dev_url}",
                "Press Ctrl+C to quit."
            ]
        };
    }
    return {
        "ok": False,
        "messages": [
            f"⚠ cap run exited with code {rc} - app was not deployed.",
            f"Vite + API servers are still running at {dev_url}.",
            "Fix the underlying error (e.g. missing Android SDK / no device) and "
            "re-run `cap run` manually, or press Ctrl+C to stop."
        ]
    };
}
