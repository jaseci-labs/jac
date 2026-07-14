import re;
import subprocess;
import from pathlib { Path }
import from typing { Optional }
import from jaclang.cli.console { console }

glob DEFAULT_APP_ID = "com.jac.app",
     DEFAULT_APP_NAME = "Jac App",
     SUBPROCESS_TIMEOUT_SHORT: int = 5,
     SUBPROCESS_TIMEOUT_BUILD: int = 600,
     MOBILE_SETUP_MODES: list[str] = ["android", "ios", "all"],
     SUPPORTED_PLATFORMS: list[str] = ["android", "ios"];

def _check_command_available(
    cmd: list[str], timeout: int = SUBPROCESS_TIMEOUT_SHORT
) -> tuple[bool, str | None] {
    try {
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout);
        if result.returncode == 0 {
            return (True, result.stdout.strip());
        }
    } except Exception { }
    return (False, None);
}

def _parse_java_major_from_version_output(text: str) -> int | None {
    m = re.search(r'version "([^"]+)"', text);
    if not m {
        return None;
    }
    v = m.group(1);
    parts = v.split(".");
    if parts[0] == "1" and len(parts) > 1 {
        try {
            return int(parts[1]);
        } except ValueError {
            return None;
        }
    }
    try {
        return int(parts[0]);
    } except (ValueError, IndexError) {
        return None;
    }
}

def _get_java_runtime_details -> tuple[bool, str | None, int | None] {
    return _probe_java_tool_version("java");
}

def _get_jdk_compiler_details -> tuple[bool, str | None, int | None] {
    return _probe_java_tool_version("javac");
}

def _probe_java_tool_version(tool: str) -> tuple[bool, str | None, int | None] {
    try {
        result = subprocess.run(
            [tool, "-version"],
            capture_output=True,
            text=True,
            timeout=SUBPROCESS_TIMEOUT_SHORT
        );
    } except Exception {
        return (False, None, None);
    }
    if result.returncode != 0 and not (result.stdout or result.stderr) {
        return (False, None, None);
    }
    out = (result.stderr or "") + (result.stdout or "");
    if not out.strip() {
        return (False, None, None);
    }
    first_line = out.strip().split("\n")[0];
    major = _parse_java_major_from_version_output(out);
    return (True, first_line, major);
}

def _normalize_mobile_platform(platform: Optional[str] = None) -> str {
    if (platform is None) or (platform.strip() == "") {
        return "android";
    }
    value = platform.lower().strip();
    if value in SUPPORTED_PLATFORMS {
        return value;
    }
    raise ValueError(
        f"Unsupported mobile platform '{platform}'. "
        f"Supported: {', '.join(SUPPORTED_PLATFORMS)}"
    );
}

def _run_cap_cmd(project_dir: Path, args: list[str], label: str) {
    import from jaclang.runtimelib.client.targets.node_tooling_common {
        resolve_node_runner
    }
    cmd = resolve_node_runner() + ["cap"] + args;
    console.print(f"  Running {label}: {' '.join(cmd)}", style="muted");
    subprocess.run(cmd, cwd=project_dir, check=True, capture_output=False);
}

def _run_install_cmd(project_dir: Path, packages: list[str], dev: bool = False) {
    import from jaclang.runtimelib.client.vite_bundler { ViteBundler }
    ViteBundler(project_dir).add_packages(packages, dev=dev);
}

def _ensure_android_cleartext_for_lan_dev(project_dir: Path) -> None {
    man = project_dir / "android" / "app" / "src" / "main" / "AndroidManifest.xml";
    if not man.exists() {
        return;
    }
    t = man.read_text(encoding="utf-8");
    if "usesCleartextTraffic" in t {
        return;
    }
    new_t = re.sub(
        r"([ \t]*<application[ \t]*\r?\n)([ \t]+)(android:)",
        r'\1\2android:usesCleartextTraffic="true"\n\2\3',
        t,
        count=1
    );
    if new_t != t {
        man.write_text(new_t, encoding="utf-8");
        console.print(
            "  ✔ Android: allowed cleartext HTTP for dev (usesCleartextTraffic); "
            "rebuild applies on cap run",
            style="success"
        );
    } else {
        console.warning(
            "  Could not auto-patch AndroidManifest for cleartext HTTP. "
            "If the WebView will not load http://<PC-LAN-IP>:<port>, set "
            "android:usesCleartextTraffic=\"true\" on <application>."
        );
    }
}
