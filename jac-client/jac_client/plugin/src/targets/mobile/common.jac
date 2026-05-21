"""Shared constants and low-level helpers for the mobile (Capacitor) target."""
import json;
import re;
import subprocess;
import from pathlib { Path }
import from typing { Optional }
import from jaclang.cli.console { console }

# ==============================================================================
# Constants
# ==============================================================================
glob DEFAULT_APP_ID = "com.jac.app",
     DEFAULT_APP_NAME = "Jac App",
     SUBPROCESS_TIMEOUT_SHORT: int = 5,
     SUBPROCESS_TIMEOUT_BUILD: int = 600,
     MOBILE_SETUP_MODES: list[str] = ["android", "ios", "all"],
     SUPPORTED_PLATFORMS: list[str] = ["android", "ios"];

# ==============================================================================
# Helper Functions
# ==============================================================================
"""Check if a command is available and optionally return its version."""
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

"""Parse major Java version from `java -version` / `javac -version` output.
"""
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

"""Return (ok, first_line, major) for the default java on PATH.
"""
def _get_java_runtime_details -> tuple[bool, str | None, int | None] {
    return _probe_java_tool_version("java");
}

"""Return (ok, first_line, major) for the default javac (JDK compiler) on PATH.

Capacitor Android builds need a JDK, not just a JRE. Distros (e.g. Ubuntu)
ship `default-jre` and `default-jdk` as separate packages — `java` can be
present without `javac`, in which case Gradle fails much later with an opaque
"Toolchain ... does not provide [JAVA_COMPILER]" error.
"""
def _get_jdk_compiler_details -> tuple[bool, str | None, int | None] {
    return _probe_java_tool_version("javac");
}

"""Common (ok, first_line, major) probe for java/javac tools.

`tool` must be the executable name (java or javac). Both print their version
banner to stderr (java) or stdout (javac); we merge both streams.
"""
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

"""Normalize and validate mobile platform string.

Defaults to 'android'. Accepts 'android' or 'ios'.
"""
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

"""Resolve npx command prefix."""
def _resolve_npx -> str {
    (ok, _) = _check_command_available(["npx", "--version"]);
    if ok {
        return "npx";
    }
    (ok, _) = _check_command_available(["bunx", "--version"]);
    if ok {
        return "bunx";
    }
    raise RuntimeError(
        "npx or bunx not found. Install Node.js (https://nodejs.org) "
        "or Bun (https://bun.sh)."
    );
}

"""Run a Capacitor CLI command from project root."""
def _run_cap_cmd(project_dir: Path, args: list[str], label: str) {
    npx = _resolve_npx();
    cmd = [npx, "cap"] + args;
    console.print(f"  Running {label}: {' '.join(cmd)}", style="muted");
    subprocess.run(cmd, cwd=project_dir, check=True, capture_output=False);
}

"""Run an npm/bun install command."""
def _run_install_cmd(project_dir: Path, packages: list[str], dev: bool = False) {
    pkg_json = project_dir / "package.json";
    if not pkg_json.exists() {
        pkg_data = {
            "name": "jac-mobile-app",
            "version": "1.0.0",
            "private": True,
            "type": "module"
        };
        pkg_json.write_text(json.dumps(pkg_data, indent=2), encoding="utf-8");
        console.print("  ✔ Created package.json", style="success");
    }
    (npm_ok, _) = _check_command_available(["npm", "--version"]);
    if npm_ok {
        cmd = ["npm", "install"];
        if dev {
            cmd.append("--save-dev");
        }
        cmd.extend(packages);
    } else {
        cmd = ["bun", "add"];
        if dev {
            cmd.append("--dev");
        }
        cmd.extend(packages);
    }
    console.print(f"  Installing: {' '.join(packages)}", style="muted");
    subprocess.run(cmd, cwd=project_dir, check=True, capture_output=False);
}

"""Allow http:// LAN dev URLs in the WebView (Android 9+ blocks cleartext by default)."""
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
