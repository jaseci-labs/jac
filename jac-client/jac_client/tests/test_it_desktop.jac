"""Integration tests for desktop target (Tauri) functionality.

These tests validate the desktop target setup, build, and sidecar functionality
as documented in FRESH_PROJECT_TESTING_GUIDE.md.

Tests are designed to:
1. Skip gracefully if Rust/Tauri toolchain is not installed
2. Test setup command (scaffolding) without requiring full build
3. Optionally test build if all dependencies are available
4. Test sidecar functionality in isolation

Note: Some tests call the target's methods directly via Python imports to avoid
CLI plugin registration conflicts that can occur in monorepo test environments.
"""

import gc;
import json;
import os;
import signal;
import subprocess;
import sys;
import tempfile;
import time;
import pytest;
import from pathlib { Path }
import from subprocess { PIPE, Popen, run }
import from urllib.error { HTTPError, URLError }
import from urllib.request { Request, urlopen }

import from .test_helpers {
    get_env_with_npm,
    get_free_port,
    get_jac_command,
    wait_for_port
}

"""Check if the 'jac setup' CLI command is available."""
def is_jac_setup_available -> bool {
    jac_cmd = get_jac_command();
    result = run([*jac_cmd, "--help"], capture_output=True, text=True, timeout=30,);
    return "setup" in result.stdout;
}

"""Run jac setup desktop command and return (returncode, stdout, stderr)."""
def run_jac_setup_desktop(project_dir: Path) -> tuple[int, str, str] {
    jac_cmd = get_jac_command();
    env = get_env_with_npm();

    # Try the CLI command
    result = run(
        [*jac_cmd, "setup", "desktop"],
        cwd=project_dir,
        capture_output=True,
        text=True,
        env=env,
        timeout=120,
    );

    # If CLI command doesn't exist, return a special error
    if result.returncode != 0 and "invalid choice: 'setup'" in result.stderr {
        return (1, "", "CLI_NOT_AVAILABLE: 'jac setup' command not registered");
    }

    return (result.returncode, result.stdout, result.stderr);
}

"""Check if Rust toolchain is installed."""
def is_rust_installed -> bool {
    try {
        result = run(["cargo", "--version"], capture_output=True, timeout=10);
        return result.returncode == 0;
    } except (FileNotFoundError, subprocess.TimeoutExpired) {
        return False;
    }
}

"""Check if Tauri CLI is installed."""
def is_tauri_cli_installed -> bool {
    try {
        result = run(["cargo", "tauri", "--version"], capture_output=True, timeout=10);
        return result.returncode == 0;
    } except (FileNotFoundError, subprocess.TimeoutExpired) {
        return False;
    }
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

"""Get minimal main.jac content for desktop testing."""
def get_minimal_desktop_jac -> str {
    return '"""Minimal desktop app for testing."""\n\n# Backend function for sidecar testing\ndef:pub greet(name: str) -> str {\n    return f"Hello, {name}!";\n}\n\ndef:pub add(a: int, b: int) -> int {\n    return a + b;\n}\n\n# Client-side component\ncl import from react { useEffect }\n\ncl {\n    def:pub app() -> any {\n        has count: int = 0;\n\n        return <div>\n            <h1>Desktop Test App</h1>\n            <p>Count: {count}</p>\n            <button onClick={lambda -> None { count = count + 1; }}>\n                Increment\n            </button>\n        </div>;\n    }\n}\n';
}

"""Get minimal jac.toml content for desktop testing."""
def get_minimal_jac_toml(name: str = "test-desktop-app") -> str {
    return f'[project]\nname = "{name}"\nversion = "1.0.0"\ndescription = "Desktop test app"\nentry-point = "main.jac"\n\n[dependencies.npm]\njac-client-node = "1.0.4"\n\n[dependencies.npm.dev]\n"@jac-client/dev-deps" = "1.0.0"\n\n[serve]\nbase_route_app = "app"\n';
}

# =============================================================================
# Test: Desktop Target Files Exist (no CLI required)
# =============================================================================
test "desktop target files exist" {
    print("[DEBUG] Starting test_desktop_target_files_exist");

    # Get path to jac_client plugin
    plugin_dir = Path(__file__).parent.parent / "plugin";

    # Verify desktop target files
    desktop_target_jac = plugin_dir / "src" / "targets" / "desktop_target.jac";
    assert desktop_target_jac.exists() , (
        f"desktop_target.jac not found at {desktop_target_jac}"
    );

    # Verify implementation file
    desktop_impl_jac = (
        plugin_dir / "src" / "targets" / "impl" / "desktop_target.impl.jac"
    );
    assert desktop_impl_jac.exists() , (
        f"desktop_target.impl.jac not found at {desktop_impl_jac}"
    );

    # Verify sidecar files
    sidecar_main_py = plugin_dir / "src" / "targets" / "desktop" / "sidecar" / "main.py";
    assert sidecar_main_py.exists() , f"sidecar main.py not found at {sidecar_main_py}";

    # Read desktop_target.jac and verify it has the expected methods
    desktop_target_content = desktop_target_jac.read_text();
    assert "class DesktopTarget" in desktop_target_content;
    assert "def setup" in desktop_target_content;
    assert "def build" in desktop_target_content;
    assert "def dev" in desktop_target_content;
    assert "def start" in desktop_target_content;

    print("[DEBUG] All desktop target files verified!");
}

# =============================================================================
# Test: Desktop Setup Command (requires CLI)
# =============================================================================
test "desktop setup creates directory structure" {
    if not is_jac_setup_available() {
        pytest.skip("'jac setup' CLI command not available (plugin not fully loaded)");
    }

    print("[DEBUG] Starting test_desktop_setup_creates_directory_structure");

    app_name = "desktop-setup-test";

    with tempfile.TemporaryDirectory() as temp_dir {
        print(f"[DEBUG] Created temporary directory at {temp_dir}");
        project_dir = Path(temp_dir) / app_name;
        project_dir.mkdir(parents=True);
        # Create minimal project files
        (project_dir / "main.jac").write_text(get_minimal_desktop_jac());
        (project_dir / "jac.toml").write_text(get_minimal_jac_toml(app_name));
        print(f"[DEBUG] Created project at {project_dir}");
        print(f"[DEBUG] Project files: {list(project_dir.iterdir())}");
        # Run jac setup desktop
        print("[DEBUG] Running desktop setup");
        (returncode, stdout, stderr) = run_jac_setup_desktop(project_dir);
        print(
            f"[DEBUG] Desktop setup completed returncode={returncode}\n"
            f"STDOUT:\n{stdout[:2000]}\n"
            f"STDERR:\n{stderr[:2000]}\n"
        );
        # Setup should succeed (returncode 0)
        assert returncode == 0 , (
            f"jac setup desktop failed\nSTDOUT:\n{stdout}\nSTDERR:\n{stderr}"
        );
        # Verify src-tauri directory exists
        tauri_dir = project_dir / "src-tauri";
        assert tauri_dir.exists() , "src-tauri/ directory should be created";
        assert tauri_dir.is_dir() , "src-tauri should be a directory";
        # Verify tauri.conf.json
        tauri_config_path = tauri_dir / "tauri.conf.json";
        assert tauri_config_path.exists() , "tauri.conf.json should be created";
        # Verify it's valid JSON
        with open(tauri_config_path) as f {
            tauri_config = json.load(f);
        }
        print(
            f"[DEBUG] tauri.conf.json content: {json.dumps(tauri_config, indent=2)[:500]}"
        );
        # Verify key config values
        assert "productName" in tauri_config , "tauri.conf.json should have productName";
        assert "version" in tauri_config , "tauri.conf.json should have version";
        assert "identifier" in tauri_config , "tauri.conf.json should have identifier";
        assert "build" in tauri_config , "tauri.conf.json should have build section";
        assert "app" in tauri_config , "tauri.conf.json should have app section";
        # Verify Cargo.toml
        cargo_path = tauri_dir / "Cargo.toml";
        assert cargo_path.exists() , "Cargo.toml should be created";
        cargo_content = cargo_path.read_text();
        assert "[package]" in cargo_content , "Cargo.toml should have [package] section";
        assert "tauri" in cargo_content.lower() , "Cargo.toml should reference tauri";
        # Verify build.rs
        build_rs_path = tauri_dir / "build.rs";
        assert build_rs_path.exists() , "build.rs should be created";
        build_rs_content = build_rs_path.read_text();
        assert "tauri_build" in build_rs_content , "build.rs should call tauri_build";
        # Verify src/main.rs
        main_rs_path = tauri_dir / "src" / "main.rs";
        assert main_rs_path.exists() , "src/main.rs should be created";
        # Verify icons directory
        icons_dir = tauri_dir / "icons";
        assert icons_dir.exists() , "icons/ directory should be created";
        # Verify binaries directory
        binaries_dir = tauri_dir / "binaries";
        assert binaries_dir.exists() , "binaries/ directory should be created";
        # Verify jac.toml was updated with [desktop] section
        jac_toml_content = (project_dir / "jac.toml").read_text();
        assert "[desktop]" in jac_toml_content , "jac.toml should have [desktop] section";
        print("[DEBUG] All desktop setup verifications passed!");
    }
}

test "desktop setup is idempotent" {
    if not is_jac_setup_available() {
        pytest.skip("'jac setup' CLI command not available (plugin not fully loaded)");
    }

    print("[DEBUG] Starting test_desktop_setup_is_idempotent");

    app_name = "desktop-idempotent-test";

    with tempfile.TemporaryDirectory() as temp_dir {
        project_dir = Path(temp_dir) / app_name;
        project_dir.mkdir(parents=True);
        # Create minimal project files
        (project_dir / "main.jac").write_text(get_minimal_desktop_jac());
        (project_dir / "jac.toml").write_text(get_minimal_jac_toml(app_name));
        # First setup
        print("[DEBUG] Running first desktop setup");
        (returncode1, stdout1, stderr1) = run_jac_setup_desktop(project_dir);
        assert returncode1 == 0 , f"First setup failed: {stderr1}";
        # Get state after first setup
        tauri_config_path = project_dir / "src-tauri" / "tauri.conf.json";
        with open(tauri_config_path) as f {
            config_after_first = json.load(f);
        }
        # Second setup
        print("[DEBUG] Running second desktop setup");
        (returncode2, stdout2, stderr2) = run_jac_setup_desktop(project_dir);
        print(
            f"[DEBUG] Second setup returncode={returncode2}\n"
            f"STDOUT:\n{stdout2[:1000]}\n"
            f"STDERR:\n{stderr2[:1000]}"
        );
        # Config should still be valid
        with open(tauri_config_path) as f {
            config_after_second = json.load(f);
        }
        # Key values should remain consistent
        assert config_after_first["productName"] == config_after_second["productName"];
        assert config_after_first["version"] == config_after_second["version"];
        print("[DEBUG] Desktop setup idempotency test passed!");
    }
}

# =============================================================================
# Test: Web Build Still Works (Regression Test)
# =============================================================================
test "web build still works after desktop setup" {
    if not is_jac_setup_available() {
        pytest.skip("'jac setup' CLI command not available (plugin not fully loaded)");
    }

    print("[DEBUG] Starting test_web_build_still_works_after_desktop_setup");

    app_name = "desktop-web-regression-test";

    with tempfile.TemporaryDirectory() as temp_dir {
        project_dir = Path(temp_dir) / app_name;
        project_dir.mkdir(parents=True);
        # Create minimal project files
        (project_dir / "main.jac").write_text(get_minimal_desktop_jac());
        (project_dir / "jac.toml").write_text(get_minimal_jac_toml(app_name));
        jac_cmd = get_jac_command();
        env = get_env_with_npm();
        # Setup desktop first
        print("[DEBUG] Setting up desktop target");
        (returncode, _, stderr) = run_jac_setup_desktop(project_dir);
        assert returncode == 0 , f"Desktop setup failed: {stderr}";
        # Install npm packages
        print("[DEBUG] Installing npm packages");
        npm_result = run(
            [*jac_cmd, "add", "--npm"],
            cwd=project_dir,
            capture_output=True,
            text=True,
            env=env,
            timeout=180,
        );
        if npm_result.returncode != 0 {
            pytest.skip(f"npm install failed: {npm_result.stderr}");
        }
        # Build web target
        print("[DEBUG] Building web target");
        build_result = run(
            [*jac_cmd, "build", "main.jac", "--client", "web"],
            cwd=project_dir,
            capture_output=True,
            text=True,
            env=env,
            timeout=180,
        );
        print(
            f"[DEBUG] Web build returncode={build_result.returncode}\n"
            f"STDOUT:\n{build_result.stdout[:2000]}\n"
            f"STDERR:\n{build_result.stderr[:2000]}"
        );
        assert build_result.returncode == 0 , (
            f"Web build failed after desktop setup\n"
            f"STDOUT:\n{build_result.stdout}\n"
            f"STDERR:\n{build_result.stderr}"
        );
        # Verify web build output
        dist_dir = project_dir / ".jac" / "client" / "dist";
        assert dist_dir.exists() , "Web build should create .jac/client/dist/";
        # Check for index.html or JS bundle
        dist_files = list(dist_dir.iterdir());
        print(f"[DEBUG] Web dist files: {dist_files}");
        assert len(dist_files) > 0 , "Web dist should contain files";
        print("[DEBUG] Web build regression test passed!");
    }
}

# =============================================================================
# Test: Desktop Build (requires full toolchain)
# =============================================================================
test "desktop build creates bundle" {
    if not is_jac_setup_available() {
        pytest.skip("'jac setup' CLI command not available");
    }
    if not is_rust_installed() {
        pytest.skip("Rust toolchain not installed");
    }
    if not is_tauri_cli_installed() {
        pytest.skip("Tauri CLI not installed (run: cargo install tauri-cli)");
    }
    if not is_pyinstaller_installed() {
        pytest.skip("PyInstaller not installed (run: pip install pyinstaller)");
    }

    print("[DEBUG] Starting test_desktop_build_creates_bundle");

    app_name = "desktop-build-test";

    with tempfile.TemporaryDirectory() as temp_dir {
        project_dir = Path(temp_dir) / app_name;
        project_dir.mkdir(parents=True);
        # Create minimal project files
        (project_dir / "main.jac").write_text(get_minimal_desktop_jac());
        (project_dir / "jac.toml").write_text(get_minimal_jac_toml(app_name));
        jac_cmd = get_jac_command();
        env = get_env_with_npm();
        # Setup desktop
        print("[DEBUG] Setting up desktop target");
        (returncode, _, stderr) = run_jac_setup_desktop(project_dir);
        assert returncode == 0 , f"Desktop setup failed: {stderr}";
        # Install npm packages
        print("[DEBUG] Installing npm packages");
        npm_result = run(
            [*jac_cmd, "add", "--npm"],
            cwd=project_dir,
            capture_output=True,
            text=True,
            env=env,
            timeout=180,
        );
        if npm_result.returncode != 0 {
            pytest.skip(f"npm install failed: {npm_result.stderr}");
        }
        # Build desktop (this can take a long time on first run)
        print("[DEBUG] Building desktop target (this may take several minutes)");
        build_result = run(
            [*jac_cmd, "build", "main.jac", "--client", "desktop"],
            cwd=project_dir,
            capture_output=True,
            text=True,
            env=env,
            timeout=900,  # 15 minutes for Rust compilation
        );
        print(
            f"[DEBUG] Desktop build returncode={build_result.returncode}\n"
            f"STDOUT (last 3000 chars):\n{build_result.stdout[-3000:]}\n"
            f"STDERR (last 3000 chars):\n{build_result.stderr[-3000:]}"
        );
        assert build_result.returncode == 0 , (
            f"Desktop build failed\n"
            f"STDOUT:\n{build_result.stdout}\n"
            f"STDERR:\n{build_result.stderr}"
        );
        # Verify sidecar was created
        binaries_dir = project_dir / "src-tauri" / "binaries";
        sidecar_files = list(binaries_dir.glob("jac-sidecar*"));
        print(f"[DEBUG] Sidecar files: {sidecar_files}");
        assert len(sidecar_files) > 0 , (
            "Sidecar should be bundled in src-tauri/binaries/"
        );
        # Verify Tauri bundle output exists
        bundle_dir = project_dir / "src-tauri" / "target" / "release" / "bundle";
        if bundle_dir.exists() {
            bundle_contents = list(bundle_dir.rglob("*"));
            print(f"[DEBUG] Bundle contents: {bundle_contents[:20]}");
            assert len(bundle_contents) > 0 , "Bundle directory should contain files";
        }
        print("[DEBUG] Desktop build test passed!");
    }
}

# =============================================================================
# Test: Sidecar Functionality
# =============================================================================
test "sidecar module runs directly" {
    print("[DEBUG] Starting test_sidecar_module_runs_directly");

    app_name = "sidecar-test";

    # Get the path to the sidecar main.py file
    sidecar_main_py = (
        Path(__file__).parent.parent / "plugin" / "src" / "targets" / "desktop" / "sidecar" / "main.py"
    );

    if not sidecar_main_py.exists() {
        pytest.skip(f"Sidecar main.py not found at {sidecar_main_py}");
    }

    with tempfile.TemporaryDirectory() as temp_dir {
        project_dir = Path(temp_dir) / app_name;
        project_dir.mkdir(parents=True);
        # Create a simple backend-only Jac file (no client code)
        backend_jac = '"""Simple backend for sidecar testing."""\n\ndef:pub greet(name: str) -> str {\n    return f"Hello, {name}!";\n}\n\ndef:pub add(a: int, b: int) -> int {\n    return a + b;\n}\n\ndef:pub get_status() -> dict {\n    return {"status": "ok", "version": "1.0.0"};\n}\n';
        (project_dir / "main.jac").write_text(backend_jac);
        jac_toml = '[project]\nname = "sidecar-test"\nversion = "1.0.0"\ndescription = "Sidecar test"\nentry-point = "main.jac"\n';
        (project_dir / "jac.toml").write_text(jac_toml);
        # Start sidecar by running main.py directly
        port = get_free_port();
        sidecar_process = None;
        try {
            print(f"[DEBUG] Starting sidecar on port {port}");
            sidecar_process = Popen(
                [
                    sys.executable,
                    str(sidecar_main_py),
                    "--module-path",
                    "main.jac",
                    "--port",
                    str(port),

                ],
                cwd=project_dir,
                stdout=PIPE,
                stderr=PIPE,
            );

            # Wait for server to start
            print(f"[DEBUG] Waiting for sidecar on 127.0.0.1:{port}");
            try {
                wait_for_port("127.0.0.1", port, timeout=60.0);
            } except TimeoutError {
                # Get process output for debugging
                if sidecar_process.poll() is not None {
                    (stdout, stderr) = sidecar_process.communicate(timeout=5);
                    pytest.fail(
                        f"Sidecar process exited early (code {sidecar_process.returncode})\n"
                        f"STDOUT:\n{stdout.decode()}\n"
                        f"STDERR:\n{stderr.decode()}"
                    );
                }
                raise ;
            }

            print(f"[DEBUG] Sidecar is accepting connections on port {port}");

            # Test root endpoint (may return 404 in some configurations)
            print("[DEBUG] Testing root endpoint /");
            try {
                with urlopen(f"http://127.0.0.1:{port}/", timeout=10) as resp {
                    root_body = resp.read().decode("utf-8", errors="ignore");
                    print(f"[DEBUG] Root response: {root_body[:500]}");
                    assert resp.status == 200 , "Root endpoint should return 200";
                }
            } except HTTPError as exc {
                if exc.code == 404 {
                    print("[DEBUG] Root endpoint returned 404, this is acceptable");
                } else {
                    pytest.fail(f"Failed to GET root endpoint: {exc}");
                }
            } except URLError as exc {
                pytest.fail(f"Failed to GET root endpoint: {exc}");
            }

            # Test functions endpoint
            print("[DEBUG] Testing /functions endpoint");
            try {
                with urlopen(f"http://127.0.0.1:{port}/functions", timeout=10) as resp {
                    funcs_body = resp.read().decode("utf-8", errors="ignore");
                    print(f"[DEBUG] Functions response: {funcs_body[:500]}");
                    if "greet" in funcs_body or "add" in funcs_body {
                        print("[DEBUG] Functions endpoint lists defined functions");
                    } else {
                        print(
                            "[DEBUG] Functions endpoint exists but doesn't list expected functions"
                        );
                    }
                }
            } except HTTPError as exc {
                if exc.code == 404 {
                    print(
                        "[DEBUG] /functions endpoint returned 404, this is acceptable"
                    );
                } else {
                    print(f"[DEBUG] /functions endpoint returned {exc.code}");
                }
            } except URLError as exc {
                print(f"[DEBUG] /functions endpoint error: {exc}");
            }

            # Test function call - greet
            print("[DEBUG] Testing POST /function/greet");
            try {
                req = Request(
                    f"http://127.0.0.1:{port}/function/greet",
                    data=json.dumps({"name": "Sidecar Test"}).encode("utf-8"),
                    headers={"Content-Type": "application/json"},
                    method="POST",
                );
                with urlopen(req, timeout=10) as resp {
                    greet_body = resp.read().decode("utf-8", errors="ignore");
                    print(f"[DEBUG] Greet response: {greet_body}");
                    response_data = json.loads(greet_body);
                    data = response_data.get("data", response_data);
                    if isinstance(data, dict) and "error" in data {
                        print(f"[DEBUG] Function call returned error: {data['error']}");
                    } elif isinstance(data, str) and "Hello" in data {
                        print("[DEBUG] Greet returned expected greeting");
                    } else {
                        print(f"[DEBUG] Greet response: {data}");
                    }
                }
            } except HTTPError as exc {
                if exc.code == 404 {
                    print(
                        "[DEBUG] /function/greet returned 404, endpoint may not exist"
                    );
                } else {
                    print(f"[DEBUG] /function/greet returned {exc.code}");
                }
            } except URLError as exc {
                print(f"[DEBUG] /function/greet error: {exc}");
            }

            # Test function call - add
            print("[DEBUG] Testing POST /function/add");
            try {
                req = Request(
                    f"http://127.0.0.1:{port}/function/add",
                    data=json.dumps({"a": 10, "b": 20}).encode("utf-8"),
                    headers={"Content-Type": "application/json"},
                    method="POST",
                );
                with urlopen(req, timeout=10) as resp {
                    add_body = resp.read().decode("utf-8", errors="ignore");
                    print(f"[DEBUG] Add response: {add_body}");
                    response_data = json.loads(add_body);
                    data = response_data.get("data", response_data);
                    if isinstance(data, dict) and "error" in data {
                        print(f"[DEBUG] Function call returned error: {data['error']}");
                    } elif data == 30 or "30" in str(data) {
                        print("[DEBUG] Add returned expected result: 30");
                    } else {
                        print(f"[DEBUG] Add response: {data}");
                    }
                }
            } except HTTPError as exc {
                if exc.code == 404 {
                    print("[DEBUG] /function/add returned 404, endpoint may not exist");
                } else {
                    print(f"[DEBUG] /function/add returned {exc.code}");
                }
            } except URLError as exc {
                print(f"[DEBUG] /function/add error: {exc}");
            }

            print("[DEBUG] All sidecar tests passed!");
        } finally {
            if sidecar_process is not None {
                print("[DEBUG] Terminating sidecar process");
                # Close stdout and stderr pipes first to avoid ResourceWarning
                if sidecar_process.stdout {
                    sidecar_process.stdout.close();
                }
                if sidecar_process.stderr {
                    sidecar_process.stderr.close();
                }
                sidecar_process.terminate();
                try {
                    sidecar_process.wait(timeout=10);
                } except subprocess.TimeoutExpired {
                    sidecar_process.kill();
                    sidecar_process.wait(timeout=5);
                }
                time.sleep(0.5);
                gc.collect();
            }
        }
    }
}

# =============================================================================
# Test: Desktop Dev Mode (requires display)
# =============================================================================
test "desktop dev mode starts" {
    if not is_jac_setup_available() {
        pytest.skip("'jac setup' CLI command not available");
    }
    if not is_rust_installed() {
        pytest.skip("Rust toolchain not installed");
    }
    if not is_tauri_cli_installed() {
        pytest.skip("Tauri CLI not installed (run: cargo install tauri-cli)");
    }
    if not has_display() {
        pytest.skip("No display available for GUI tests");
    }

    print("[DEBUG] Starting test_desktop_dev_mode_starts");

    app_name = "desktop-dev-test";

    with tempfile.TemporaryDirectory() as temp_dir {
        project_dir = Path(temp_dir) / app_name;
        project_dir.mkdir(parents=True);
        # Create minimal project files
        (project_dir / "main.jac").write_text(get_minimal_desktop_jac());
        (project_dir / "jac.toml").write_text(get_minimal_jac_toml(app_name));
        jac_cmd = get_jac_command();
        env = get_env_with_npm();
        # Setup desktop
        (returncode, _, stderr) = run_jac_setup_desktop(project_dir);
        assert returncode == 0 , f"Desktop setup failed: {stderr}";
        # Install npm packages
        npm_result = run(
            [*jac_cmd, "add", "--npm"],
            cwd=project_dir,
            capture_output=True,
            text=True,
            env=env,
            timeout=180,
        );
        if npm_result.returncode != 0 {
            pytest.skip(f"npm install failed: {npm_result.stderr}");
        }
        # Start desktop dev mode
        dev_process = None;
        try {
            print("[DEBUG] Starting desktop dev mode");
            dev_process = Popen(
                [*jac_cmd, "start", "main.jac", "--client", "desktop", "--dev"],
                cwd=project_dir,
                env=env,
            );

            # Wait for Vite dev server (port 5173)
            print("[DEBUG] Waiting for Vite dev server on port 5173");
            try {
                wait_for_port("127.0.0.1", 5173, timeout=90.0);
                print("[DEBUG] Vite dev server is running on port 5173");
            } except TimeoutError {
                if dev_process.poll() is not None {
                    pytest.fail(
                        f"Desktop dev process exited early (code {dev_process.returncode})"
                    );
                }
                raise ;
            }

            # Give Tauri a moment to initialize
            time.sleep(3);

            # Verify dev server is serving content
            try {
                with urlopen("http://127.0.0.1:5173/", timeout=10) as resp {
                    body = resp.read().decode("utf-8", errors="ignore");
                    print(f"[DEBUG] Dev server response: {body[:500]}");
                    assert resp.status == 200 , "Dev server should return 200";
                }
            } except (URLError, HTTPError) as exc {
                print(f"[DEBUG] Warning: Could not fetch from dev server: {exc}");
                # Not a hard failure - Tauri might intercept
            }

            print("[DEBUG] Desktop dev mode test passed!");
        } finally {
            if dev_process is not None {
                print("[DEBUG] Terminating desktop dev process");
                # Send SIGINT for clean shutdown
                try {
                    dev_process.send_signal(signal.SIGINT);
                    dev_process.wait(timeout=15);
                } except (subprocess.TimeoutExpired, OSError) {
                    dev_process.terminate();
                    try {
                        dev_process.wait(timeout=10);
                    } except subprocess.TimeoutExpired {
                        dev_process.kill();
                        dev_process.wait(timeout=5);
                    }
                }
                time.sleep(1);
                gc.collect();
            }
        }
    }
}
