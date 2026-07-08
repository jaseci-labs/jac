import json;
import os;
import subprocess;
import from pathlib { Path }
import from jaclang.cli.console { console }
import from jaclang.runtimelib.client.config_loader { JacClientConfig }
import from jaclang.runtimelib.client.targets.mobile.common { SUBPROCESS_TIMEOUT_SHORT }
import from jaclang.runtimelib.client.targets.node_tooling_common {
    resolve_node_runner
}
import from jaclang.runtimelib.client.targets.client_dev_common {
    assert_port_available,
    ensure_watchdog_common,
    setup_android_port_reverse_common,
    start_backend_server_common
}

def _get_api_base_url_str(project_dir: Path) -> str {
    loader = JacClientConfig(project_dir);
    return loader.get_api_config().get("base_url", "") or "";
}

def _assert_mobile_port_available(port: int, role: str) {
    assert_port_available(
        port,
        role,
        "Mobile dev needs deterministic ports so adb reverse and "
        "capacitor.config.json match what the server actually binds. Stop "
        "the conflicting process, choose a different port "
        f"(e.g. --port {port + 100}), or set "
        "[client].vite.server.port in jac.toml."
    );
}

def _warn_mobile_dev_api_url(project_dir: Path) {
    base = _get_api_base_url_str(project_dir);
    if base {
        if ("localhost" in base.lower()) or ("127.0.0.1" in base) {
            console.warning(
                "  Physical devices cannot reach localhost on your PC. "
                "Clear [client.api] base_url for same-origin dev proxy, "
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
    ports = [vite_port];
    if server_port != vite_port {
        ports.append(server_port);
    }
    setup_android_port_reverse_common(ports, timeout=SUBPROCESS_TIMEOUT_SHORT);
}

def _mobile_ensure_watchdog -> bool {
    return ensure_watchdog_common("the WebView");
}

def _mobile_start_backend_server(
    entry_file: Path, project_dir: Path, port: int
) -> any {
    return start_backend_server_common(entry_file, project_dir, port);
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
    cmd = resolve_node_runner() + ["cap", "run", plat];
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
