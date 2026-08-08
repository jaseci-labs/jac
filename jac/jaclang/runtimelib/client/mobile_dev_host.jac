import os;
import platform as platform_mod;
import shutil;
import socket;
import subprocess;
import time;
import from pathlib { Path }
import from jaclang.cli.console { console }
import from jaclang.runtimelib.client.config_loader { JacClientConfig }

glob JAC_MOBILE_VITE_PORT_ENV: str = "JAC_MOBILE_VITE_PORT";
glob JAC_ANDROID_AVD_ENV: str = "JAC_ANDROID_AVD";

glob ADB_STATE_TIMEOUT_SEC: int = 2,
     ADB_PROPS_TIMEOUT_SEC: int = 2,
     ADB_DEVICES_TIMEOUT_SEC: int = 5,
     ADB_BOOT_TIMEOUT_SEC: int = 120,
     EMULATOR_LIST_TIMEOUT_SEC: int = 10,
     XCRUN_SIMCTL_TIMEOUT_SEC: int = 3;

glob ANDROID_EMULATOR_HOST_ALIAS: str = "10.0.2.2";

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

def resolve_mobile_server_port(toml_base_url: str, api_port: int) -> int {
    if toml_base_url {
        import from urllib.parse { urlparse }

        parsed = urlparse(toml_base_url);
        return parsed.port or api_port;
    }
    return api_port;
}

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

def list_adb_devices(adb: str = "") -> list[str] {
    if not adb {
        found = shutil.which("adb");
        if not found {
            return [];
        }
        adb = found;
    }
    try {
        r = subprocess.run(
            [adb, "devices"],
            capture_output=True,
            text=True,
            timeout=ADB_DEVICES_TIMEOUT_SEC,
            check=False
        );
    } except Exception {
        return [];
    }
    devices: list[str] = [];
    for line in (r.stdout or "").splitlines() {
        line = line.strip();
        if not line or line.startswith("List of devices") {
            continue;
        }
        parts = line.split();
        if len(parts) >= 2 and parts[1] == "device" {
            devices.append(parts[0]);
        }
    }
    return devices;
}

def locate_android_emulator -> str | None {
    sdk = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT");
    if sdk {
        emu = Path(sdk) / "emulator" / "emulator";
        if emu.is_file() {
            return str(emu);
        }
    }
    return shutil.which("emulator");
}

def list_android_avds(emulator_bin: str = "") -> list[str] {
    if not emulator_bin {
        emulator_bin = locate_android_emulator() or "";
    }
    if not emulator_bin {
        return [];
    }
    try {
        r = subprocess.run(
            [emulator_bin, "-list-avds"],
            capture_output=True,
            text=True,
            timeout=EMULATOR_LIST_TIMEOUT_SEC,
            check=False
        );
    } except Exception {
        return [];
    }
    if r.returncode != 0 {
        return [];
    }
    return [
        line.strip()
        for line in (r.stdout or "").splitlines()
        if line.strip()
    ];
}

def wait_for_adb_device_boot(
    adb: str, timeout_sec: int = ADB_BOOT_TIMEOUT_SEC
) -> None {
    deadline = time.time() + timeout_sec;
    while time.time() < deadline {
        try {
            r = subprocess.run(
                [adb, "shell", "getprop", "sys.boot_completed"],
                capture_output=True,
                text=True,
                timeout=ADB_PROPS_TIMEOUT_SEC,
                check=False
            );
            if r.returncode == 0 and (r.stdout or "").strip() == "1" {
                return;
            }
        } except Exception { }
        time.sleep(2);
    }
    raise RuntimeError(
        f"Timed out after {timeout_sec}s waiting for the Android device to finish booting."
    );
}

def ensure_adb_device(avd: str = "") -> str {
    adb = shutil.which("adb");
    if not adb {
        raise RuntimeError("adb not found on PATH (install Android platform-tools).");
    }
    if list_adb_devices(adb) {
        return adb;
    }
    emulator = locate_android_emulator();
    if not emulator {
        raise RuntimeError(
            "No Android device/emulator connected and the emulator binary was not found. "
            "Set ANDROID_HOME or start a device manually."
        );
    }
    avds = list_android_avds(emulator);
    if not avds {
        raise RuntimeError(
            "No Android device/emulator connected and no AVDs are configured. "
            "Create one in Android Studio → Device Manager."
        );
    }
    chosen = "";
    want = (avd or os.environ.get(JAC_ANDROID_AVD_ENV, "") or "").strip();
    if want {
        if want in avds {
            chosen = want;
        } else {
            console.warning(f"  AVD '{want}' not found; using '{avds[0]}'.");
            chosen = avds[0];
        }
    } else {
        chosen = avds[0];
    }
    console.print(
        f"  No device connected — starting emulator '{chosen}'...", style="muted"
    );
    subprocess.Popen(
        [emulator, "-avd", chosen, "-no-snapshot-load"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    );
    subprocess.run([adb, "wait-for-device"], check=True, timeout=ADB_BOOT_TIMEOUT_SEC);
    wait_for_adb_device_boot(adb);
    console.success(f"  Emulator '{chosen}' ready.");
    return adb;
}

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
