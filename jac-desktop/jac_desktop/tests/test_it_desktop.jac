"""Integration tests for PyTauri desktop target functionality.

These tests validate desktop setup, build, and sidecar behavior for the
jac-desktop plugin. Rust/cargo is not required.
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

import from _helpers {
    _JAC_DESKTOP_ROOT,
    _PYTAURI_TARGET_IMPL,
    _PYTAURI_TARGET_JAC,
    _SIDECAR_MAIN,
    _JAC_CLIENT_FIXTURES,
    get_env_with_npm,
    get_free_port,
    get_jac_command,
    get_minimal_desktop_jac,
    get_minimal_jac_toml,
    has_display,
    is_jac_setup_available,
    is_pyinstaller_installed,
    is_pytauri_wheel_installed,
    pytauri_setup_target_active,
    require_pytauri_setup_target,
    run_jac_setup_desktop,
    wait_for_port
}

test "pytauri desktop target files exist" {
    assert _PYTAURI_TARGET_JAC.exists() , (
        f"pytauri_desktop_target.jac not found at {_PYTAURI_TARGET_JAC}"
    );
    assert _PYTAURI_TARGET_IMPL.exists() , (
        f"pytauri_desktop_target.impl.jac not found at {_PYTAURI_TARGET_IMPL}"
    );
    assert _SIDECAR_MAIN.exists() , f"sidecar main.py not found at {_SIDECAR_MAIN}";

    target_content = _PYTAURI_TARGET_JAC.read_text(encoding="utf-8");
    assert "obj PyTauriDesktopTarget" in target_content;
    assert "def setup" in target_content;
    assert "def build" in target_content;
    assert "def dev" in target_content;
    assert "def start" in target_content;
}

test "pyinstaller spec excludes litellm bloat for windows max_path" {
    import from _helpers { _DESKTOP_HELPERS_IMPL }
    assert _DESKTOP_HELPERS_IMPL.exists();
    content = _DESKTOP_HELPERS_IMPL.read_text(encoding="utf-8");
    assert "EXCLUDE_DATA_PATTERNS = [" in content;
    assert "'guardrail_benchmarks'" in content;
    assert "_should_exclude" in content;
    assert "if not _should_exclude(d)" in content;
}

test "desktop setup creates directory structure" {
    if not is_jac_setup_available() {
        pytest.skip("'jac setup' CLI command not available (install jac-desktop)");
    }
    require_pytauri_setup_target();

    app_name = "desktop-setup-test";
    with tempfile.TemporaryDirectory() as temp_dir {
        project_dir = Path(temp_dir) / app_name;
        project_dir.mkdir(parents=True);
        (project_dir / "main.jac").write_text(get_minimal_desktop_jac());
        (project_dir / "jac.toml").write_text(get_minimal_jac_toml(app_name));
        (returncode, stdout, stderr) = run_jac_setup_desktop(project_dir);
        assert returncode == 0 , (
            f"jac setup desktop failed\nSTDOUT:\n{stdout}\nSTDERR:\n{stderr}"
        );
        pytauri_dir = project_dir / "src-pytauri";
        assert pytauri_dir.exists() , "src-pytauri/ directory should be created";
        assert (pytauri_dir / "tauri.conf.json").exists() , "tauri.conf.json should be created";
        assert (pytauri_dir / "app.py").exists() , "app.py should be created";
        assert (pytauri_dir / "pyproject.toml").exists() , "pyproject.toml should be created";
        assert (pytauri_dir / "capabilities" / "default.json").exists() , (
            "capabilities/default.json should be created"
        );
        assert (pytauri_dir / "icons").exists() , "icons/ directory should be created";
        assert (pytauri_dir / "binaries").exists() , "binaries/ directory should be created";
        with open(pytauri_dir / "tauri.conf.json") as f {
            tauri_config = json.load(f);
        }
        assert "productName" in tauri_config;
        assert "version" in tauri_config;
        assert "identifier" in tauri_config;
        assert "build" in tauri_config;
        assert "app" in tauri_config;
        app_py = (pytauri_dir / "app.py").read_text(encoding="utf-8");
        assert "def run_shell(" in app_py;
    }
}

test "desktop setup is idempotent" {
    if not is_jac_setup_available() {
        pytest.skip("'jac setup' CLI command not available");
    }
    require_pytauri_setup_target();

    app_name = "desktop-idempotent-test";
    with tempfile.TemporaryDirectory() as temp_dir {
        project_dir = Path(temp_dir) / app_name;
        project_dir.mkdir(parents=True);
        (project_dir / "main.jac").write_text(get_minimal_desktop_jac());
        (project_dir / "jac.toml").write_text(get_minimal_jac_toml(app_name));
        (returncode1, _, stderr1) = run_jac_setup_desktop(project_dir);
        assert returncode1 == 0 , f"First setup failed: {stderr1}";
        tauri_config_path = project_dir / "src-pytauri" / "tauri.conf.json";
        with open(tauri_config_path) as f {
            config_after_first = json.load(f);
        }
        (returncode2, _, stderr2) = run_jac_setup_desktop(project_dir);
        assert returncode2 == 0 , f"Second setup failed: {stderr2}";
        with open(tauri_config_path) as f {
            config_after_second = json.load(f);
        }
        assert config_after_first["productName"] == config_after_second["productName"];
        assert config_after_first["version"] == config_after_second["version"];
    }
}

test "web build still works after desktop setup" {
    if not is_jac_setup_available() {
        pytest.skip("'jac setup' CLI command not available");
    }
    require_pytauri_setup_target();

    app_name = "desktop-web-regression-test";
    with tempfile.TemporaryDirectory() as temp_dir {
        project_dir = Path(temp_dir) / app_name;
        project_dir.mkdir(parents=True);
        (project_dir / "main.jac").write_text(get_minimal_desktop_jac());
        (project_dir / "jac.toml").write_text(get_minimal_jac_toml(app_name));
        jac_cmd = get_jac_command();
        env = get_env_with_npm();
        (returncode, _, stderr) = run_jac_setup_desktop(project_dir);
        assert returncode == 0 , f"Desktop setup failed: {stderr}";
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
        build_result = run(
            [*jac_cmd, "build", "main.jac", "--client", "web"],
            cwd=project_dir,
            capture_output=True,
            text=True,
            env=env,
            timeout=180,
        );
        assert build_result.returncode == 0 , (
            f"Web build failed after desktop setup\nSTDOUT:\n{build_result.stdout}\nSTDERR:\n{build_result.stderr}"
        );
        dist_dir = project_dir / ".jac" / "client" / "dist";
        assert dist_dir.exists() , "Web build should create .jac/client/dist/";
        assert len(list(dist_dir.iterdir())) > 0 , "Web dist should contain files";
    }
}

test "desktop build creates sidecar bundle" {
    if not is_jac_setup_available() {
        pytest.skip("'jac setup' CLI command not available");
    }
    require_pytauri_setup_target();
    if not is_pyinstaller_installed() {
        pytest.skip("PyInstaller not installed (run: pip install pyinstaller)");
    }

    app_name = "desktop-build-test";
    with tempfile.TemporaryDirectory() as temp_dir {
        project_dir = Path(temp_dir) / app_name;
        project_dir.mkdir(parents=True);
        (project_dir / "main.jac").write_text(get_minimal_desktop_jac());
        (project_dir / "jac.toml").write_text(get_minimal_jac_toml(app_name));
        jac_cmd = get_jac_command();
        env = get_env_with_npm();
        (returncode, _, stderr) = run_jac_setup_desktop(project_dir);
        assert returncode == 0 , f"Desktop setup failed: {stderr}";
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
        build_result = run(
            [*jac_cmd, "build", "main.jac", "--client", "desktop"],
            cwd=project_dir,
            capture_output=True,
            text=True,
            env=env,
            timeout=900,
        );
        assert build_result.returncode == 0 , (
            f"Desktop build failed\nSTDOUT:\n{build_result.stdout}\nSTDERR:\n{build_result.stderr}"
        );
        binaries_dir = project_dir / "src-pytauri" / "binaries";
        sidecar_files = list(binaries_dir.glob("jac-sidecar*"));
        assert len(sidecar_files) > 0 , (
            "Sidecar should be bundled in src-pytauri/binaries/"
        );
        dist_dir = project_dir / "src-pytauri" / "dist";
        assert dist_dir.exists() , "Build should stage output under src-pytauri/dist/";
        launcher = dist_dir / "run.sh";
        if not launcher.exists() {
            launcher = dist_dir / "run.bat";
        }
        assert launcher.exists() , "Build should write a run.sh or run.bat launcher";
    }
}

test "sidecar module runs directly" {
    if not _SIDECAR_MAIN.exists() {
        pytest.skip(f"Sidecar main.py not found at {_SIDECAR_MAIN}");
    }

    with tempfile.TemporaryDirectory() as temp_dir {
        project_dir = Path(temp_dir) / "sidecar-test";
        project_dir.mkdir(parents=True);
        backend_jac = (
            '"""Simple backend for sidecar testing."""\n\n'
            'def:pub greet(name: str) -> str {\n'
            '    return f"Hello, {name}!";\n'
            '}\n\n'
            'def:pub add(a: int, b: int) -> int {\n'
            '    return a + b;\n'
            '}\n'
        );
        (project_dir / "main.jac").write_text(backend_jac);
        (project_dir / "jac.toml").write_text(
            '[project]\nname = "sidecar-test"\nversion = "1.0.0"\n'
            'description = "Sidecar test"\nentry-point = "main.jac"\n'
        );
        port = get_free_port();
        sidecar_process = None;
        try {
            sidecar_process = Popen(
                [
                    sys.executable,
                    str(_SIDECAR_MAIN),
                    "--module-path",
                    "main.jac",
                    "--port",
                    str(port),

                ],
                cwd=project_dir,
                stdout=PIPE,
                stderr=PIPE,
            );
            try {
                wait_for_port("127.0.0.1", port, timeout=60.0);
            } except TimeoutError {
                if sidecar_process.poll() is not None {
                    (_, stderr) = sidecar_process.communicate(timeout=5);
                    pytest.skip(
                        f"Sidecar exited early (code {sidecar_process.returncode}): "
                        f"{stderr.decode(errors='ignore')[:500]}"
                    );
                }
                pytest.skip(f"Sidecar did not start on port {port} within timeout");
            }

            try {
                with urlopen(f"http://127.0.0.1:{port}/", timeout=10) as resp {
                    assert resp.status == 200 , "Root endpoint should return 200";
                }
            } except HTTPError as exc {
                if exc.code != 404 {
                    pytest.fail(f"Failed to GET root endpoint: {exc}");
                }
            }
        } finally {
            if sidecar_process is not None {
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

test "desktop dev mode starts vite server" {
    if not is_jac_setup_available() {
        pytest.skip("'jac setup' CLI command not available");
    }
    require_pytauri_setup_target();

    app_name = "desktop-dev-test";
    with tempfile.TemporaryDirectory() as temp_dir {
        project_dir = Path(temp_dir) / app_name;
        project_dir.mkdir(parents=True);
        (project_dir / "main.jac").write_text(get_minimal_desktop_jac());
        (project_dir / "jac.toml").write_text(get_minimal_jac_toml(app_name));
        jac_cmd = get_jac_command();
        env = get_env_with_npm();
        (returncode, _, stderr) = run_jac_setup_desktop(project_dir);
        assert returncode == 0 , f"Desktop setup failed: {stderr}";
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
        vite_port = 5173;
        dev_process = None;
        try {
            dev_process = Popen(
                [
                    *jac_cmd,
                    "start",
                    "main.jac",
                    "--client",
                    "desktop",
                    "--dev",
                    "--port",
                    str(vite_port),

                ],
                cwd=project_dir,
                env=env,
            );
            wait_for_port("127.0.0.1", vite_port, timeout=90.0, process=dev_process);
            with urlopen(f"http://127.0.0.1:{vite_port}/", timeout=10) as resp {
                assert resp.status == 200 , "Dev server should return 200";
            }
        } finally {
            if dev_process is not None {
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

test "desktop build copies assets to dist" {
    if not is_jac_setup_available() {
        pytest.skip("'jac setup' CLI command not available");
    }
    require_pytauri_setup_target();
    if not is_pyinstaller_installed() {
        pytest.skip("PyInstaller not installed");
    }

    app_name = "desktop-assets-test";
    with tempfile.TemporaryDirectory() as temp_dir {
        project_dir = Path(temp_dir) / app_name;
        project_dir.mkdir(parents=True);
        assets_dir = project_dir / "assets";
        assets_dir.mkdir(parents=True);
        png_data = bytes(
            [
                0x89,
                0x50,
                0x4E,
                0x47,
                0x0D,
                0x0A,
                0x1A,
                0x0A,
                0x00,
                0x00,
                0x00,
                0x0D,
                0x49,
                0x48,
                0x44,
                0x52,
                0x00,
                0x00,
                0x00,
                0x01,
                0x00,
                0x00,
                0x00,
                0x01,
                0x08,
                0x02,
                0x00,
                0x00,
                0x00,
                0x90,
                0x77,
                0x53,
                0xDE,
                0x00,
                0x00,
                0x00,
                0x0C,
                0x49,
                0x44,
                0x41,
                0x54,
                0x08,
                0xD7,
                0x63,
                0xF8,
                0xFF,
                0xFF,
                0x3F,
                0x00,
                0x05,
                0xFE,
                0x02,
                0xFE,
                0xDC,
                0xCC,
                0x59,
                0xE7,
                0x00,
                0x00,
                0x00,
                0x00,
                0x49,
                0x45,
                0x4E,
                0x44,
                0xAE,
                0x42,
                0x60,
                0x82,

            ]
        );
        (assets_dir / "test-image.png").write_bytes(png_data);
        main_jac_with_asset = '''"""App with asset for testing."""

cl {
    def:pub app() -> Any {
        return <div>
            <h1>Asset Test App</h1>
            <img src="/static/assets/test-image.png" alt="Test" />
        </div>;
    }
}
''';
        (project_dir / "main.jac").write_text(main_jac_with_asset);
        (project_dir / "jac.toml").write_text(get_minimal_jac_toml(app_name));
        jac_cmd = get_jac_command();
        env = get_env_with_npm();
        (returncode, _, stderr) = run_jac_setup_desktop(project_dir);
        assert returncode == 0 , f"Desktop setup failed: {stderr}";
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
        build_result = run(
            [*jac_cmd, "build", "main.jac", "--client", "desktop"],
            cwd=project_dir,
            capture_output=True,
            text=True,
            env=env,
            timeout=900,
        );
        assert build_result.returncode == 0 , (
            f"Desktop build failed\nSTDOUT:\n{build_result.stdout}\nSTDERR:\n{build_result.stderr}"
        );
        compiled_assets = project_dir / ".jac" / "client" / "compiled" / "assets";
        assert compiled_assets.exists() , "compiled/assets/ should exist after build";
        assert (compiled_assets / "test-image.png").exists();
        dist_static_assets = (
            project_dir / ".jac" / "client" / "dist" / "static" / "assets"
        );
        assert dist_static_assets.exists() , "dist/static/assets/ should exist after desktop build";
        dist_test_image = dist_static_assets / "test-image.png";
        assert dist_test_image.exists();
        assert dist_test_image.read_bytes() == png_data;
    }
}

test "desktop build generates index.html with correct paths" {
    if not is_jac_setup_available() {
        pytest.skip("'jac setup' CLI command not available");
    }
    require_pytauri_setup_target();

    app_dir = _JAC_CLIENT_FIXTURES / "multi_segment_app";
    if not app_dir.exists() {
        pytest.skip("multi_segment_app fixture not found");
    }

    with tempfile.TemporaryDirectory() as temp_dir {
        project_dir = Path(temp_dir) / "multi_segment_app";
        import shutil;
        shutil.copytree(app_dir, project_dir);
        jac_cmd = get_jac_command();
        env = get_env_with_npm();
        (returncode, _, stderr) = run_jac_setup_desktop(project_dir);
        assert returncode == 0 , f"Desktop setup failed: {stderr}";
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
        run(
            [*jac_cmd, "build", "main.jac", "--client", "desktop"],
            cwd=project_dir,
            capture_output=True,
            text=True,
            env=env,
            timeout=300,
        );
        index_html = project_dir / ".jac" / "client" / "dist" / "index.html";
        assert index_html.exists() , "index.html should be generated";
        html_content = index_html.read_text(encoding="utf-8");
        assert "/client." in html_content , (
            f"index.html should use absolute paths by default. Content:\n{html_content}"
        );
    }
}

test "desktop build generates index.html with custom base_path" {
    if not is_jac_setup_available() {
        pytest.skip("'jac setup' CLI command not available");
    }
    require_pytauri_setup_target();

    app_dir = _JAC_CLIENT_FIXTURES / "multi_segment_app";
    if not app_dir.exists() {
        pytest.skip("multi_segment_app fixture not found");
    }

    with tempfile.TemporaryDirectory() as temp_dir {
        project_dir = Path(temp_dir) / "multi_segment_app";
        import shutil;
        shutil.copytree(app_dir, project_dir);
        jac_toml_path = project_dir / "jac.toml";
        jac_toml_content = jac_toml_path.read_text(encoding="utf-8");
        if "[plugins.client]" in jac_toml_content {
            jac_toml_content = jac_toml_content.replace(
                "[plugins.client]", '[plugins.client]\nbase_path = "/myapp/"'
            );
        } else {
            jac_toml_content += '\n[plugins.client]\nbase_path = "/myapp/"\n';
        }
        jac_toml_path.write_text(jac_toml_content);
        jac_cmd = get_jac_command();
        env = get_env_with_npm();
        (returncode, _, stderr) = run_jac_setup_desktop(project_dir);
        assert returncode == 0 , f"Desktop setup failed: {stderr}";
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
        run(
            [*jac_cmd, "build", "main.jac", "--client", "desktop"],
            cwd=project_dir,
            capture_output=True,
            text=True,
            env=env,
            timeout=300,
        );
        index_html = project_dir / ".jac" / "client" / "dist" / "index.html";
        assert index_html.exists();
        html_content = index_html.read_text(encoding="utf-8");
        assert "/myapp/client." in html_content;
        vite_config_path = project_dir / ".jac" / "client" / "configs" / "vite.config.js";
        assert vite_config_path.exists();
        vite_config_content = vite_config_path.read_text(encoding="utf-8");
        assert 'base: "/myapp/"' in vite_config_content;
        jac_toml_content = jac_toml_path.read_text(encoding="utf-8");
        jac_toml_content = jac_toml_content.replace(
            'base_path = "/myapp/"', 'base_path = "./"'
        );
        jac_toml_path.write_text(jac_toml_content);
        run(
            [*jac_cmd, "build", "main.jac", "--client", "desktop"],
            cwd=project_dir,
            capture_output=True,
            text=True,
            env=env,
            timeout=300,
        );
        html_content2 = index_html.read_text(encoding="utf-8");
        assert "./client." in html_content2;
        vite_config_content2 = vite_config_path.read_text(encoding="utf-8");
        assert 'base: "./"' in vite_config_content2;
    }
}
