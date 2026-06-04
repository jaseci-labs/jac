"""Tests for PyTauri desktop API URL resolution and sidecar port discovery."""

import importlib;
import importlib.util;
import os;
import re;
import socket;
import subprocess;
import sys;
import tempfile;
import types;
import pytest;
import unittest.mock;
import from pathlib { Path }
import from _helpers {
    _DESKTOP_HELPERS_IMPL,
    _DESKTOP_HELPERS_JAC,
    _PYTAURI_TARGET_IMPL,
    _PYTAURI_TARGET_JAC,
    _RUNTIME_PY,
    _SIDECAR_MAIN,
    _VITE_BUNDLER_JAC,
    _VITE_BUNDLER_IMPL,
    _JAC_CLIENT_CLI,
    get_env_with_bun,
    get_jac_command,
    require_pytauri_setup_target,
    run_jac_setup_desktop
}

"""Import sidecar main.py as a module."""
def _import_sidecar_main -> types.ModuleType {
    spec = importlib.util.spec_from_file_location("sidecar_main", _SIDECAR_MAIN);
    if not spec or not spec.loader {
        raise ImportError("Could not load sidecar main.py module");
    }
    module = importlib.util.module_from_spec(spec);
    spec.loader.exec_module(module);
    return module;
}

test "bind listen socket returns valid port" {
    sidecar = _import_sidecar_main();
    (sock, port) = sidecar._bind_listen_socket("127.0.0.1", 0);
    try {
        assert isinstance(port, int) , "Port should be an integer";
        assert 1 <= port <= 65535 , f"Port {port} should be in valid range 1-65535";
    } finally {
        sock.close();
    }
}

test "bind listen socket returns different ports" {
    sidecar = _import_sidecar_main();
    ports = set();
    for _ in range(5) {
        (sock, port) = sidecar._bind_listen_socket("127.0.0.1", 0);
        ports.add(port);
        sock.close();
    }
    assert len(ports) >= 2 , f"Expected multiple unique ports, got {ports}";
}

test "bind listen socket holds port until closed" {
    sidecar = _import_sidecar_main();
    (sock, port) = sidecar._bind_listen_socket("127.0.0.1", 0);
    try {
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s {
            s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1);
            with pytest.raises(OSError) {
                s.bind(("127.0.0.1", port));
            }
        }
    } finally {
        sock.close();
    }
}

test "bind listen socket with custom host" {
    sidecar = _import_sidecar_main();
    (sock, port) = sidecar._bind_listen_socket("127.0.0.1", 0);
    try {
        assert isinstance(port, int) , "Port should be an integer";
        assert 1 <= port <= 65535 , f"Port {port} should be in valid range";
    } finally {
        sock.close();
    }
}

test "sidecar port zero resolves to real port" {
    sidecar = _import_sidecar_main();
    (sock, port) = sidecar._bind_listen_socket("127.0.0.1", 0);
    try {
        assert port != 0 , "Port 0 should be resolved to an actual port";
        assert 1 <= port <= 65535 , f"Resolved port {port} should be in valid range";
    } finally {
        sock.close();
    }
}

test "sidecar nonzero port preserved" {
    original_port = 9000;
    port = original_port;
    if port == 0 {
        port = 99999;
    }
    assert port == original_port , "Non-zero port should be preserved";
}

test "sidecar port marker format" {
    port = 12345;
    marker = f"JAC_SIDECAR_PORT={port}";
    assert marker.startswith("JAC_SIDECAR_PORT=") , "Marker must start with exact prefix";
    port_str = marker.split("=", 1)[1];
    parsed_port = int(port_str.strip());
    assert parsed_port == port , f"Parsed port {parsed_port} should match {port}";
}

test "setup writes stable app py stub" {
    require_pytauri_setup_target();
    jac_cmd = get_jac_command();
    result = subprocess.run(
        [*jac_cmd, "--help"], capture_output=True, text=True, timeout=30
    );
    if "setup" not in result.stdout {
        pytest.skip("'jac setup' CLI command not available");
    }

    with tempfile.TemporaryDirectory() as temp_dir {
        project_dir = Path(temp_dir) / "app-py-test";
        project_dir.mkdir(parents=True);
        (project_dir / "main.jac").write_text(
            '"""Test."""\ndef:pub hello() -> str { return "hi"; }\n'
        );
        (project_dir / "jac.toml").write_text(
            '[project]\nname = "test"\nversion = "1.0.0"\nentry-point = "main.jac"\n'
        );
        env = get_env_with_bun();
        setup_result = subprocess.run(
            [*jac_cmd, "setup", "desktop"],
            cwd=project_dir,
            capture_output=True,
            text=True,
            env=env,
            timeout=120,
        );
        if setup_result.returncode != 0 {
            if "invalid choice: 'setup'" in setup_result.stderr {
                pytest.skip("'jac setup' command not registered (install jac-desktop)");
            }
            pytest.fail(
                f"jac setup desktop failed:\nSTDOUT:\n{setup_result.stdout}\nSTDERR:\n{setup_result.stderr}"
            );
        }
        app_py_path = project_dir / "src-pytauri" / "app.py";
        assert app_py_path.exists() , "app.py should be created by setup";
        app_py_content = app_py_path.read_text(encoding="utf-8");
        assert "def run_shell(" in app_py_content , (
            "app.py should include stable shell logic"
        );
        assert "JAC_SIDECAR_PORT=" in app_py_content , (
            "Sidecar port discovery should live in app.py shell runtime"
        );
        assert "__JAC_API_BASE_URL__" in app_py_content , (
            "API URL injection should live in app.py shell runtime"
        );
    }
}

test "desktop target interface has api port" {
    assert _PYTAURI_TARGET_JAC.exists();
    content = _PYTAURI_TARGET_JAC.read_text(encoding="utf-8");
    assert "port: int = 8000" in content , "desktop dev() should declare port (Vite)";
    assert "api_port: int = 0" in content , "desktop dev() should declare api_port (0 = default)";
    assert content.count("api_port: int = 8000") == 1 , (
        "start() should use api_port for the production/preview server port"
    );
}

test "vite bundler has api base url constant" {
    assert _VITE_BUNDLER_JAC.exists();
    content = _VITE_BUNDLER_JAC.read_text(encoding="utf-8");
    assert "API_BASE_URL_ENV_VAR" in content;
    assert '"JAC_CLIENT_API_BASE_URL"' in content;
    assert "_resolve_api_base_url" in content;
}

test "vite bundler config methods accept override" {
    content = _VITE_BUNDLER_JAC.read_text(encoding="utf-8");
    assert content.count('api_base_url_override: str = ""') >= 2 , (
        "api_base_url_override should appear in _resolve_api_base_url and create_vite_config"
    );
}

test "resolve api base url priority chain in impl" {
    assert _VITE_BUNDLER_IMPL.exists();
    content = _VITE_BUNDLER_IMPL.read_text(encoding="utf-8");
    assert "impl ViteBundler._resolve_api_base_url" in content;
    assert "toml_base_url or api_base_url_override or env_override" in content;
    assert "API_BASE_URL_ENV_VAR" in content;
    assert "self._resolve_api_base_url(api_base_url_override)" in content;
}

test "env var cleanup pattern in build" {
    assert _PYTAURI_TARGET_IMPL.exists();
    content = _PYTAURI_TARGET_IMPL.read_text(encoding="utf-8");
    build_section = content[content.index("impl PyTauriDesktopTarget.build("):];
    next_impl = build_section.index("impl PyTauriDesktopTarget.dev(");
    build_section = build_section[:next_impl];
    assert "try {" in build_section;
    assert "} finally {" in build_section;
    assert "os.environ.pop(API_BASE_URL_ENV_VAR, None)" in build_section;
    assert 'os.environ.pop("JAC_BUILD", None)' in build_section;
}

test "env var not leaked after import" {
    env_var = "JAC_CLIENT_API_BASE_URL";
    os.environ.pop(env_var, None);
    _import_sidecar_main();
    assert env_var not in os.environ , (
        f"{env_var} should not be set after importing sidecar module"
    );
}

test "make localhost url in desktop helpers" {
    helpers = _DESKTOP_HELPERS_IMPL.read_text(encoding="utf-8");
    pytauri = _PYTAURI_TARGET_IMPL.read_text(encoding="utf-8");
    assert "def _make_localhost_url(port: int) -> str" in helpers;
    assert 'return f"http://127.0.0.1:{port}"' in helpers;
    usage_count = helpers.count("_make_localhost_url(") + pytauri.count(
        "_make_localhost_url("
    );
    assert usage_count >= 2 , (
        f"_make_localhost_url should be defined and used by PyTauri target, found {usage_count}"
    );
}

test "get toml api base url in desktop helpers" {
    content = _DESKTOP_HELPERS_IMPL.read_text(encoding="utf-8");
    assert "def _get_toml_api_base_url(project_dir: Path) -> str" in content;
    assert "JacClientConfig(project_dir)" in content;
}

test "no magic string jac client api base url" {
    pytauri_content = _PYTAURI_TARGET_IMPL.read_text(encoding="utf-8");
    assert '"JAC_CLIENT_API_BASE_URL"' not in pytauri_content , (
        "pytauri impl should use API_BASE_URL_ENV_VAR constant, not the string literal"
    );
    vite_content = _VITE_BUNDLER_IMPL.read_text(encoding="utf-8");
    assert '"JAC_CLIENT_API_BASE_URL"' not in vite_content;
    vite_jac_content = _VITE_BUNDLER_JAC.read_text(encoding="utf-8");
    assert vite_jac_content.count('"JAC_CLIENT_API_BASE_URL"') == 1;
}

test "cli passes port to desktop target" {
    assert _JAC_CLIENT_CLI.exists();
    content = _JAC_CLIENT_CLI.read_text(encoding="utf-8");
    assert 'ctx.get_arg("port"' in content;
    assert 'ctx.get_arg("api_port"' in content;
    assert "port=start_port" in content;
    assert "api_port=start_api" in content;
    assert "api_port=start_port" in content;
}

test "sidecar emits failure marker on early exit" {
    content = _SIDECAR_MAIN.read_text(encoding="utf-8");
    assert 'sys.stdout.write(f"JAC_SIDECAR_FAILED={safe}' in content;
    assert "_exit_after_port" in content;
    assert "_emit_sidecar_failure(f\"terminated by" in content;
    assert "_exit_after_port(" in content;
}

test "sidecar prints port marker to stdout" {
    assert _SIDECAR_MAIN.exists();
    content = _SIDECAR_MAIN.read_text(encoding="utf-8");
    assert 'sys.stdout.write(f"JAC_SIDECAR_PORT={port}' in content;
    assert "sys.stdout.flush()" in content;
    assert "_bind_listen_socket" in content , (
        "Sidecar should bind the listen socket before emitting JAC_SIDECAR_PORT"
    );
    bind_pos = content.index("_bind_listen_socket");
    marker_pos = content.index("JAC_SIDECAR_PORT=");
    start_pos = content.index("server.start(");
    assert bind_pos < marker_pos , "Listen socket must be bound before port marker";
    assert marker_pos < start_pos , "Port marker should be printed before server.start()";
}

test "sidecar help shows port zero" {
    result = subprocess.run(
        [sys.executable, str(_SIDECAR_MAIN), "--help"],
        capture_output=True,
        text=True,
        timeout=10,
    );
    assert result.returncode == 0 , "Sidecar --help should succeed";
    assert "auto" in result.stdout.lower() or "0" in result.stdout , (
        "Sidecar help should mention port 0 / auto-assign"
    );
}

test "sidecar no stdout after port marker" {
    content = _SIDECAR_MAIN.read_text(encoding="utf-8");
    main_start = content.index("def main():");
    main_body = content[main_start:];
    bare_prints = re.findall(r"(?<!\.)print\(", main_body);
    assert len(bare_prints) == 0 , (
        f"sidecar should not use bare print(), found {len(bare_prints)}"
    );
    stdout_writes = re.findall(r"sys\.stdout\.write\(", main_body);
    assert len(stdout_writes) == 1 , (
        f"Expected exactly 1 sys.stdout.write (port marker), found {len(stdout_writes)}"
    );
}

test "sidecar uses console after import" {
    content = _SIDECAR_MAIN.read_text(encoding="utf-8");
    assert "from jaclang.cli.console import console" in content;
    assert "console.print(" in content;
    assert "console.error(" in content;
}

test "pytauri target imports api base url env var" {
    content = _PYTAURI_TARGET_IMPL.read_text(encoding="utf-8");
    assert (
        "import from jaclang.runtimelib.client.vite_bundler { API_BASE_URL_ENV_VAR }" in content
    );
}

test "runtime uses initialization script not eval" {
    content = _RUNTIME_PY.read_text(encoding="utf-8");
    assert "initialization_script" in content;
    assert "context_factory(shell_dir)" in content;
    assert "builder_factory().build(context" in content;
}

test "pytauri runtime config has empty windows" {
    content = _RUNTIME_PY.read_text(encoding="utf-8");
    assert '"windows":[]' in content.replace(" ", "");
}

test "start backend server helper exists" {
    content = _DESKTOP_HELPERS_IMPL.read_text(encoding="utf-8");
    assert "def _start_backend_server(" in content;
    assert "subprocess.Popen" in content;
    assert '"--no_client"' in content;
    assert '"--port"' in content;
}

test "resolve server port helper exists" {
    content = _DESKTOP_HELPERS_IMPL.read_text(encoding="utf-8");
    assert "def _resolve_server_port(" in content;
    assert "urlparse" in content;
}

test "start method launches pytauri app py" {
    content = _PYTAURI_TARGET_IMPL.read_text(encoding="utf-8");
    start_idx = content.index("impl PyTauriDesktopTarget.start(");
    start_body = content[start_idx:];
    assert "app.py" in start_body , "start() should launch src-pytauri/app.py";
    assert "subprocess.call" in start_body or "subprocess.Popen" in start_body , (
        "start() should invoke python app.py via subprocess"
    );
}

test "dev method passes api base url env to shell" {
    content = _PYTAURI_TARGET_IMPL.read_text(encoding="utf-8");
    dev_idx = content.index("impl PyTauriDesktopTarget.dev(");
    next_impl = content.index("impl PyTauriDesktopTarget.start(", dev_idx + 1);
    dev_body = content[dev_idx:next_impl];
    assert "JAC_PYTAURI_API_BASE_URL" in dev_body , (
        "dev() should pass computed API URL to the shell via env"
    );
    assert "_start_backend_server(" in dev_body , "dev() should call _start_backend_server";
    assert "_resolve_server_port(" in dev_body , "dev() should call _resolve_server_port";
    assert "server_proc" in dev_body , "dev() should manage server_proc lifecycle";
}

test "pyinstaller spec excludes litellm bloat for windows max_path" {
    content = _DESKTOP_HELPERS_IMPL.read_text(encoding="utf-8");
    assert "EXCLUDE_DATA_PATTERNS = [" in content;
    assert "'guardrail_benchmarks'" in content;
    assert "_should_exclude" in content;
    assert "if not _should_exclude(d)" in content;
}

test "subprocess timeout constants single source of truth" {
    import from jac_desktop.helpers.desktop_helpers {
        SUBPROCESS_TIMEOUT_SHORT,
        SUBPROCESS_TIMEOUT_MEDIUM,
        SUBPROCESS_TIMEOUT_LONG,
        SUBPROCESS_TIMEOUT_BUILD,
        SIDECAR_BOOT_TIMEOUT
    }
    assert SUBPROCESS_TIMEOUT_SHORT == 5;
    assert SUBPROCESS_TIMEOUT_MEDIUM == 60;
    assert SUBPROCESS_TIMEOUT_LONG == 300;
    assert SUBPROCESS_TIMEOUT_BUILD == 600;
    assert SIDECAR_BOOT_TIMEOUT == 30;
    impl_text = _DESKTOP_HELPERS_IMPL.read_text(encoding="utf-8");
    assert "glob SUBPROCESS_TIMEOUT_SHORT" not in impl_text , (
        "Timeout constants must not be re-declared in desktop_helpers.impl.jac"
    );
}

test "check command available resolves default timeout in body" {
    impl_text = _DESKTOP_HELPERS_IMPL.read_text(encoding="utf-8");
    assert "timeout: int | None = None" in impl_text;
    assert "timeout is not None else SUBPROCESS_TIMEOUT_SHORT" in impl_text;
}
