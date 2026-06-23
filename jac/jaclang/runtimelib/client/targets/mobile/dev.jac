"""Mobile target: Vite HMR, Capacitor live-reload, and dev workflow helpers."""
import json;
import os;
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
import from jaclang.runtimelib.client.targets.client_dev_common {
    assert_port_available,
    ensure_watchdog_common,
    invalidate_runtime_module_cache,
    setup_android_port_reverse_common,
    start_backend_server_common
}

"""Read [plugins.client.api] base_url for warnings and port resolution."""
def _get_api_base_url_str(project_dir: Path) -> str {
    loader = JacClientConfig(project_dir);
    return loader.get_api_config().get("base_url", "") or "";
}

"""Fail fast if a port is already bound.

The mobile dev flow reserves ports via adb reverse and rewrites
capacitor.config.json with a fixed Vite URL. The API subprocess
(`jaclang start`) silently bumps the port on EADDRINUSE - which leaves
adb-reverse / cap-config pointing at a port nothing is listening on, so the
device can never reach the API. Probing the port before we configure
anything makes the failure mode explicit instead of arriving as a confusing
"WebView won't connect" issue later.

`role` is a short label (e.g. "Vite" or "API") used in the error message.
"""
def _assert_mobile_port_available(port: int, role: str) {
    assert_port_available(
        port,
        role,
        "Mobile dev needs deterministic ports so adb reverse and "
        "capacitor.config.json match what the server actually binds. Stop "
        "the conflicting process, choose a different port "
        f"(e.g. --port {port + 100}), or set "
        "[plugins.client].vite.server.port in jac.toml."
    );
}

"""API connectivity for mobile dev."""
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

"""Read mobile dev options set by jac-client CLI (see cli.jac). Vite port: resolve_mobile_vite_port."""
def _mobile_read_dev_env -> tuple[str, str] {
    host_ov = os.environ.get("JAC_MOBILE_DEV_HOST", "");
    plat_mode = os.environ.get("JAC_MOBILE_PLATFORM", "auto");
    return (host_ov, plat_mode);
}

"""Best-effort ADB reverse for Android mobile dev connectivity.

No-op when adb is not on PATH - adb only exists when the Android SDK platform
tools are installed, so a missing binary means there is no device to reverse
ports to anyway. The previous implementation called subprocess unconditionally
and emitted noisy "[Errno 2] No such file" warnings on every dev run on hosts
without adb.
"""
def _mobile_setup_android_port_reverse(vite_port: int, server_port: int) {
    ports = [vite_port];
    if server_port != vite_port {
        ports.append(server_port);
    }
    setup_android_port_reverse_common(ports, timeout=SUBPROCESS_TIMEOUT_SHORT);
}

"""Return True if watchdog is available (required for .jac → client HMR)."""
def _mobile_ensure_watchdog -> bool {
    return ensure_watchdog_common("the WebView");
}

"""Recompile the Vite client graph after a .jac file change (runs on watchdog thread).
"""
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
        invalidate_runtime_module_cache([pth, str(entry_file)]);
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

"""Start Jac API only for mobile dev."""
def _mobile_start_backend_server(
    entry_file: Path, project_dir: Path, port: int
) -> any {
    return start_backend_server_common(entry_file, project_dir, port);
}

"""Write server.url into capacitor.config.json for live-reload.

During dev, the Capacitor WebView loads directly from the Vite dev server
instead of the static webDir. We save the original config and restore it on exit.
"""
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

"""Restore capacitor.config.json to its pre-dev state."""
def _restore_capacitor_config(project_dir: Path, original: str | None) -> None {
    if original is None {
        return;
    }
    config_path = project_dir / "capacitor.config.json";
    config_path.write_text(original, encoding="utf-8");
    console.print("  ✔ Restored capacitor.config.json", style="muted");
}

"""Run cap run (no --live-reload; server.url in config points to Vite)."""
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

"""Describe the user-facing outcome of `cap run`. Pure / no side effects.

Returns a dict with:
  ok       - True when rc == 0 (cap run succeeded).
  messages - list[str] for the user. Must NOT claim deployment when rc != 0
             (the original code printed "📱 App deployed" unconditionally,
             misleading users when there was no device or no Android SDK).
"""
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
