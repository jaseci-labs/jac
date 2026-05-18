"""Resolve dev-server host for Capacitor live reload."""
import os;
import platform as platform_mod;
import shutil;
import socket;
import subprocess;
import from pathlib { Path }
import from jac_client.plugin.src.config_loader { JacClientConfig }

glob JAC_MOBILE_VITE_PORT_ENV: str = "JAC_MOBILE_VITE_PORT";

glob ADB_STATE_TIMEOUT_SEC: int = 2,
     ADB_PROPS_TIMEOUT_SEC: int = 2,
     XCRUN_SIMCTL_TIMEOUT_SEC: int = 3;

# Android emulator: loopback to host (see Android docs for AVD networking).
glob ANDROID_EMULATOR_HOST_ALIAS: str = "10.0.2.2";

"""Best-effort LAN IPv4 of this machine (connects outbound to discover primary route)."""
def detect_lan_ipv4 -> str | None {
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM);
    try {
        s.settimeout(0.5);
        s.connect(("8.8.8.8", 80));
        addr = s.getsockname()[0];
        if addr and addr != "127.0.0.1" {
            return addr;
        }
    } except OSError {
        ;
    } finally {
        s.close();
    }
    return None;
}

"""Resolve backend API port from jac.toml base_url or CLI default."""
def resolve_mobile_server_port(toml_base_url: str, api_port: int) -> int {
    if toml_base_url {
        import from urllib.parse { urlparse }

        parsed = urlparse(toml_base_url);
        return parsed.port or api_port;
    }
    return api_port;
}

"""Vite HMR port for mobile dev: JAC_MOBILE_VITE_PORT, then [plugins.client].vite.server.port, else `cli_vite_port`
(same as core `jac start --dev --port`, default 8000)."""
def resolve_mobile_vite_port(project_dir: Path, cli_vite_port: int = 8000) -> int {
    raw = os.environ.get(JAC_MOBILE_VITE_PORT_ENV, "");
    if raw and str(raw).strip() {
        return int(str(raw).strip());
    }
    loader = JacClientConfig(project_dir);
    vite_cfg = loader.get_vite_config();
    if not vite_cfg {
        return cli_vite_port;
    }
    server = vite_cfg.get("server", None);
    if not isinstance(server, dict) {
        return cli_vite_port;
    }
    p = server.get("port", None);
    if p is not None and str(p).strip() {
        return int(p);
    }
    return cli_vite_port;
}

"""True if the default `adb` device is an Android emulator (AVD), else False.

If adb is missing, no device is online, or detection fails, returns False and callers
should fall back to LAN / 127.0.0.1. Multiple devices: uses adb's default target."""
def is_android_emulator_adb -> bool {
    if not shutil.which("adb") {
        return False;
    }
    try {
        st = subprocess.run(
            ["adb", "get-state"],
            capture_output=True,
            text=True,
            timeout=ADB_STATE_TIMEOUT_SEC,
            check=False
        );
    } except Exception {
        return False;
    }
    if st.returncode != 0 or (st.stdout or "").strip() != "device" {
        return False;
    }
    def _shell_getprop(name: str) -> str {
        try {
            r = subprocess.run(
                ["adb", "shell", "getprop", name],
                capture_output=True,
                text=True,
                timeout=ADB_PROPS_TIMEOUT_SEC,
                check=False
            );
            if r.returncode == 0 {
                return (r.stdout or "").strip();
            }
        } except Exception { }
        return "";
    }
    if _shell_getprop("ro.kernel.qemu") == "1" {
        return True;
    }
    hardware = _shell_getprop("ro.hardware").lower();
    if hardware in ["goldfish", "ranchu"] {
        return True;
    }
    if "emulator" in _shell_getprop("ro.build.characteristics").lower() {
        return True;
    }
    try {
        sn = subprocess.run(
            ["adb", "get-serialno"],
            capture_output=True,
            text=True,
            timeout=ADB_PROPS_TIMEOUT_SEC,
            check=False
        );
        s = (sn.stdout or "").strip().lower();
        if s.startswith("emulator-") {
            return True;
        }
    } except Exception { }
    return False;
}

"""True if a booted iOS Simulator is present (macOS + simctl)."""
def is_ios_simulator -> bool {
    if platform_mod.system() != "Darwin" {
        return False;
    }
    if not shutil.which("xcrun") {
        return False;
    }
    try {
        r = subprocess.run(
            ["xcrun", "simctl", "list", "devices", "booted"],
            capture_output=True,
            text=True,
            timeout=XCRUN_SIMCTL_TIMEOUT_SEC,
            check=False
        );
    } except Exception {
        return False;
    }
    if r.returncode != 0 {
        return False;
    }
    out = (r.stdout or "") + (r.stderr or "");
    if "Booted" in out {
        return True;
    }
    return False;
}

"""Pick the host string the WebView uses to reach the dev machine (Vite / HMR / API).

Override: JAC_MOBILE_DEV_HOST or `jac start --dev --client mobile --host`.

Else: Android AVD (adb) -> 10.0.2.2; iOS Simulator (simctl booted) -> 127.0.0.1;
otherwise LAN IPv4, then 127.0.0.1."""
def resolve_mobile_dev_host(plat: str, host_override: str = "") -> str {
    if host_override and host_override.strip() {
        return host_override.strip();
    }
    p = plat.lower().strip();
    if p not in ["android", "ios"] {
        p = "android";
    }
    if p == "android" {
        if is_android_emulator_adb() {
            return ANDROID_EMULATOR_HOST_ALIAS;
        }
        ip = detect_lan_ipv4();
        if ip {
            return ip;
        }
        return "127.0.0.1";
    }
    if is_ios_simulator() {
        return "127.0.0.1";
    }
    ip = detect_lan_ipv4();
    if ip {
        return ip;
    }
    return "127.0.0.1";
}
