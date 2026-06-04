"""Shared test utilities for jac-desktop tests."""

import os;
import shutil;
import socket;
import subprocess;
import sys;
import time;
import from pathlib { Path }
import from subprocess { run }
import from jac_desktop.helpers.desktop_helpers { get_jac_command }

glob _TESTS_DIR: Path = Path(str(__file__)).parent,
     _JAC_DESKTOP_ROOT: Path = _TESTS_DIR.parent,
     _JAC_CLIENT_ROOT: Path = _TESTS_DIR.parent.parent.parent / "jac-client" / "jac_client",
     _JACLANG_ROOT: Path = _TESTS_DIR.parent.parent.parent / "jac" / "jaclang",
     _DESKTOP_HELPERS_JAC: Path = _JAC_DESKTOP_ROOT / "helpers" / "desktop_helpers.jac",
     _DESKTOP_HELPERS_IMPL: Path = (
         _JAC_DESKTOP_ROOT / "helpers" / "impl" / "desktop_helpers.impl.jac"
     ),
     _PYTAURI_TARGET_IMPL: Path = (
         _JAC_DESKTOP_ROOT / "targets" / "impl" / "pytauri_desktop_target.impl.jac"
     ),
     _PYTAURI_TARGET_JAC: Path = (
         _JAC_DESKTOP_ROOT / "targets" / "pytauri_desktop_target.jac"
     ),
     _SIDECAR_MAIN: Path = (
         _JAC_CLIENT_ROOT / "plugin" / "src" / "targets" / "desktop" / "sidecar" / "main.py"
     ),
     _RUNTIME_PY: Path = _DESKTOP_HELPERS_JAC,
     _JAC_CLIENT_FIXTURES: Path = _JAC_CLIENT_ROOT / "tests" / "fixtures",
     _VITE_BUNDLER_JAC: Path = _JACLANG_ROOT / "runtimelib" / "client" / "vite_bundler.jac",
     _VITE_BUNDLER_IMPL: Path = (
         _JACLANG_ROOT / "runtimelib" / "client" / "impl" / "vite_bundler.impl.jac"
     ),
     _JAC_CLIENT_CLI: Path = _JAC_CLIENT_ROOT / "plugin" / "cli.jac";

"""Resolve jac-client root when running against an installed wheel."""
def resolve_jac_client_root -> Path {
    if _JAC_CLIENT_ROOT.is_dir() {
        return _JAC_CLIENT_ROOT;
    }
    import jac_client;
    paths = list(getattr(jac_client, "__path__", []) or []);
    if not paths {
        raise RuntimeError("jac_client package root not found");
    }
    return Path(str(paths[0]));
}

"""Get a free port by binding to port 0 and releasing it."""
def get_free_port -> int {
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s {
        s.bind(("", 0));
        s.listen(1);
        port = int(s.getsockname()[1]);
    }
    return port;
}

"""Get environment dict with bun in PATH."""
def get_env_with_bun -> dict[str, str] {
    import from jaclang.runtimelib.client { get_bun }
    env = os.environ.copy();
    bun_path = get_bun();
    if not bun_path {
        bun_path = shutil.which("bun");
    }
    if bun_path {
        bun_dir = str(Path(bun_path).parent);
        current_path = env.get("PATH", "");
        if bun_dir not in current_path {
            env["PATH"] = f"{bun_dir}:{current_path}";
        }
    }
    return env;
}

glob get_env_with_npm = get_env_with_bun;

"""Block until a TCP port is accepting connections or timeout."""
def wait_for_port(host: str, port: int, timeout: float = 60.0) -> None {
    deadline = time.time() + timeout;
    while time.time() < deadline {
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock {
            sock.settimeout(0.5);
            try {
                sock.connect((host, port));
                return;
            } except OSError {
                time.sleep(0.5);
            }
        }
    }
    raise TimeoutError(f"Timed out waiting for {host}:{port}");
}

"""Check if the 'jac setup' CLI command is available."""
def is_jac_setup_available -> bool {
    jac_cmd = get_jac_command();
    result = run([*jac_cmd, "--help"], capture_output=True, text=True, timeout=30);
    return "setup" in result.stdout;
}

"""Check if PyInstaller is installed."""
def is_pyinstaller_installed -> bool {
    try {
        result = run(["pyinstaller", "--version"], capture_output=True, timeout=10);
        return result.returncode == 0;
    } except (FileNotFoundError, subprocess.TimeoutExpired) {
        return False;
    }
}

"""Check if pytauri-wheel is importable."""
def is_pytauri_wheel_installed -> bool {
    try {
        result = run(
            [sys.executable, "-c", "import pytauri_wheel.lib; print('ok')"],
            capture_output=True,
            text=True,
            timeout=15,
        );
        return result.returncode == 0 and "ok" in result.stdout;
    } except (FileNotFoundError, subprocess.TimeoutExpired) {
        return False;
    }
}

"""Check if a display is available (for GUI tests)."""
def has_display -> bool {
    if os.environ.get("DISPLAY") {
        return True;
    }
    if os.environ.get("WAYLAND_DISPLAY") {
        return True;
    }
    if os.environ.get("CI") {
        return False;
    }
    return False;
}

"""Run jac setup desktop command and return (returncode, stdout, stderr)."""
def run_jac_setup_desktop(project_dir: Path) -> tuple[int, str, str] {
    jac_cmd = get_jac_command();
    env = get_env_with_npm();
    result = run(
        [*jac_cmd, "setup", "desktop"],
        cwd=project_dir,
        capture_output=True,
        text=True,
        env=env,
        timeout=120,
    );
    if result.returncode != 0 and "invalid choice: 'setup'" in result.stderr {
        return (1, "", "CLI_NOT_AVAILABLE: 'jac setup' command not registered");
    }
    return (result.returncode, result.stdout, result.stderr);
}

"""Minimal main.jac content for desktop testing."""
def get_minimal_desktop_jac -> str {
    return (
        '"""Minimal desktop app for testing."""\n\n'
        'def:pub greet(name: str) -> str {\n'
        '    return f"Hello, {name}!";\n'
        '}\n\n'
        'def:pub add(a: int, b: int) -> int {\n'
        '    return a + b;\n'
        '}\n\n'
        'cl import from react { useEffect }\n\n'
        'cl {\n'
        '    def:pub app() -> Any {\n'
        '        has count: int = 0;\n'
        '        return <div>\n'
        '            <h1>Desktop Test App</h1>\n'
        '            <p>Count: {count}</p>\n'
        '            <button onClick={lambda -> None { count = count + 1; }}>\n'
        '                Increment\n'
        '            </button>\n'
        '        </div>;\n'
        '    }\n'
        '}\n'
    );
}

"""Check if setup uses the PyTauri desktop target (src-pytauri/) not legacy Rust."""
def is_pytauri_setup_target -> bool {
    import tempfile;
    td = tempfile.mkdtemp(prefix="jac-desktop-probe-");
    project_dir = Path(td);
    try {
        (project_dir / "main.jac").write_text('def:pub x() -> int { return 1; }\n');
        (project_dir / "jac.toml").write_text(
            '[project]\nname = "probe"\nversion = "1.0.0"\nentry-point = "main.jac"\n'
        );
        (returncode, _, _) = run_jac_setup_desktop(project_dir);
        if returncode != 0 {
            return False;
        }
        return (project_dir / "src-pytauri" / "app.py").exists();
    } finally {
        import shutil;
        shutil.rmtree(td, ignore_errors=True);
    }
}

glob _pytauri_target_active_cache: list = [None];

"""Cached probe: True when `jac setup desktop` scaffolds src-pytauri/ (PyTauri target)."""
def pytauri_setup_target_active -> bool {
    if _pytauri_target_active_cache[0] is None {
        _pytauri_target_active_cache[0] = is_pytauri_setup_target();
    }
    return bool(_pytauri_target_active_cache[0]);
}

"""Skip the current test when the active jac CLI still uses legacy Rust desktop."""
def require_pytauri_setup_target {
    import from unittest { SkipTest }
    if not pytauri_setup_target_active() {
        raise SkipTest(
            "PyTauri desktop target not active (install jac-client + jac-desktop from branch)"
        );
    }
}

"""Minimal jac.toml content for desktop testing."""
def get_minimal_jac_toml(name: str = "test-desktop-app") -> str {
    return (
        f'[project]\n'
        f'name = "{name}"\n'
        f'version = "1.0.0"\n'
        f'description = "Desktop test app"\n'
        f'entry-point = "main.jac"\n\n'
        f'[dependencies.npm]\n'
        f'react = "^18.2.0"\n'
        f'react-dom = "^18.2.0"\n'
        f'react-router-dom = "^6.22.0"\n'
        f'react-error-boundary = "^5.0.0"\n'
        f'react-hook-form = "^7.71.0"\n'
        f'zod = "^4.3.6"\n'
        f'"@hookform/resolvers" = "^5.2.2"\n\n'
        f'[dependencies.npm.dev]\n'
        f'vite = "^6.4.1"\n'
        f'"@vitejs/plugin-react" = "^4.2.1"\n'
        f'typescript = "^5.3.3"\n'
        f'"@types/react" = "^18.2.0"\n'
        f'"@types/react-dom" = "^18.2.0"\n\n'
        f'[serve]\n'
        f'base_route_app = "app"\n'
    );
}
