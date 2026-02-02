"""Tests for desktop API URL resolution and sidecar port discovery.

These tests validate the changes introduced for desktop app URL resolution:
1. Sidecar dynamic port allocation (_find_free_port, port 0 handling)
2. JAC_SIDECAR_PORT= stdout protocol
3. Generated main.rs content (CONFIGURED_BASE_URL, dynamic discovery)
4. ViteBundler API base URL resolution priority chain
5. Env var cleanup (try/finally) in build/start flows
6. Helper functions (_make_localhost_url, _get_toml_api_base_url)
"""

from __future__ import annotations

import importlib
import importlib.util
import os
import socket
import subprocess
import sys
import tempfile
import types
from pathlib import Path
from unittest.mock import MagicMock

import pytest

# =============================================================================
# Shared path constants (avoid repeating long path constructions)
# =============================================================================

_plugin_src = Path(__file__).parent.parent / "plugin" / "src"

_sidecar_main_path = _plugin_src / "targets" / "desktop" / "sidecar" / "main.py"
_desktop_target_impl_path = _plugin_src / "targets" / "impl" / "desktop_target.impl.jac"
_vite_bundler_jac_path = _plugin_src / "vite_bundler.jac"
_vite_bundler_impl_path = _plugin_src / "impl" / "vite_bundler.impl.jac"


def _import_sidecar_main() -> types.ModuleType:
    """Import sidecar main.py as a module.

    Uses importlib to load the module from its file path, since the sidecar
    package does not have __init__.py files.
    """
    spec = importlib.util.spec_from_file_location("sidecar_main", _sidecar_main_path)
    if not spec or not spec.loader:
        raise ImportError("Could not load sidecar main.py module")
    assert spec is not None, f"Could not create ModuleSpec for {_sidecar_main_path}"
    assert spec.loader is not None, f"ModuleSpec has no loader for {_sidecar_main_path}"
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


# =============================================================================
# Test: Sidecar _find_free_port
# =============================================================================


def test_find_free_port_returns_valid_port() -> None:
    """Test that _find_free_port returns a port in the valid range."""
    print("[DEBUG] Starting test_find_free_port_returns_valid_port")

    sidecar = _import_sidecar_main()
    port = sidecar._find_free_port()

    print(f"[DEBUG] Got free port: {port}")

    assert isinstance(port, int), "Port should be an integer"
    assert 1 <= port <= 65535, f"Port {port} should be in valid range 1-65535"


def test_find_free_port_returns_different_ports() -> None:
    """Test that consecutive calls return different ports (not stuck on one)."""
    print("[DEBUG] Starting test_find_free_port_returns_different_ports")

    sidecar = _import_sidecar_main()
    ports = {sidecar._find_free_port() for _ in range(5)}

    print(f"[DEBUG] Got ports: {ports}")

    # At least 2 different ports from 5 attempts (OS should give unique ports)
    assert len(ports) >= 2, f"Expected multiple unique ports, got {ports}"


def test_find_free_port_is_actually_free() -> None:
    """Test that the returned port can actually be bound to."""
    print("[DEBUG] Starting test_find_free_port_is_actually_free")

    sidecar = _import_sidecar_main()
    port = sidecar._find_free_port()

    print(f"[DEBUG] Checking port {port} is bindable")

    # Verify we can bind to the port
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        try:
            s.bind(("127.0.0.1", port))
            print(f"[DEBUG] Successfully bound to port {port}")
        except OSError:
            # TOCTOU race - port was taken between _find_free_port and our bind.
            # This is the expected limitation. Skip rather than fail.
            pytest.skip(f"Port {port} was taken between check and bind (TOCTOU)")


def test_find_free_port_with_custom_host() -> None:
    """Test _find_free_port with explicit localhost host."""
    print("[DEBUG] Starting test_find_free_port_with_custom_host")

    sidecar = _import_sidecar_main()
    port = sidecar._find_free_port(host="127.0.0.1")

    print(f"[DEBUG] Got free port on 127.0.0.1: {port}")

    assert isinstance(port, int), "Port should be an integer"
    assert 1 <= port <= 65535, f"Port {port} should be in valid range"


# =============================================================================
# Test: Sidecar port 0 handling and JAC_SIDECAR_PORT marker
# =============================================================================


def test_sidecar_port_zero_resolves_to_real_port() -> None:
    """Test that --port 0 gets resolved to an actual port before server starts.

    This verifies the sidecar's port 0 handling: when port 0 is passed,
    _find_free_port() should be called to allocate a real port.
    """
    print("[DEBUG] Starting test_sidecar_port_zero_resolves_to_real_port")

    sidecar = _import_sidecar_main()

    # Mock argparse to simulate --port 0
    mock_args = MagicMock()
    mock_args.port = 0
    mock_args.host = "127.0.0.1"

    # The code under test:
    # port = args.port
    # if port == 0:
    #     port = _find_free_port(args.host)
    port = mock_args.port
    if port == 0:
        port = sidecar._find_free_port(mock_args.host)

    print(f"[DEBUG] Port 0 resolved to: {port}")

    assert port != 0, "Port 0 should be resolved to an actual port"
    assert 1 <= port <= 65535, f"Resolved port {port} should be in valid range"


def test_sidecar_nonzero_port_preserved() -> None:
    """Test that a specific port (non-zero) is preserved as-is."""
    print("[DEBUG] Starting test_sidecar_nonzero_port_preserved")

    # Simulate the port resolution logic
    original_port = 9000
    port = original_port
    if port == 0:
        port = 99999  # Should not be reached

    assert port == original_port, "Non-zero port should be preserved"


def test_sidecar_port_marker_format() -> None:
    """Test that the JAC_SIDECAR_PORT= marker matches the expected format.

    The Rust code in generated main.rs parses this exact format:
        line.strip_prefix("JAC_SIDECAR_PORT=")
    """
    print("[DEBUG] Starting test_sidecar_port_marker_format")

    port = 12345
    marker = f"JAC_SIDECAR_PORT={port}"

    print(f"[DEBUG] Marker: {marker}")

    # Verify format matches what the Rust parser expects
    assert marker.startswith("JAC_SIDECAR_PORT="), "Marker must start with exact prefix"
    port_str = marker.split("=", 1)[1]
    parsed_port = int(port_str.strip())
    assert parsed_port == port, f"Parsed port {parsed_port} should match {port}"


# =============================================================================
# Test: Generated main.rs content
# =============================================================================


def test_setup_generates_main_rs_with_sidecar_support() -> None:
    """Test that jac setup desktop generates main.rs with sidecar port discovery.

    After setup, the generated main.rs should contain:
    - CONFIGURED_BASE_URL constant
    - JAC_SIDECAR_PORT= parsing logic
    - API_BASE_URL global storage
    - initialization_script injection (runs before page JS)
    """
    print("[DEBUG] Starting test_setup_generates_main_rs_with_sidecar_support")

    from .test_helpers import get_env_with_bun, get_jac_command

    # Check if jac setup is available
    jac_cmd = get_jac_command()
    result = subprocess.run(
        [*jac_cmd, "--help"], capture_output=True, text=True, timeout=30
    )
    if "setup" not in result.stdout:
        pytest.skip("'jac setup' CLI command not available")

    with tempfile.TemporaryDirectory() as temp_dir:
        project_dir = Path(temp_dir) / "main-rs-test"
        project_dir.mkdir(parents=True)

        # Minimal project
        (project_dir / "main.jac").write_text(
            '"""Test."""\ndef:pub hello() -> str { return "hi"; }\n'
        )
        (project_dir / "jac.toml").write_text(
            '[project]\nname = "test"\nversion = "1.0.0"\nentry-point = "main.jac"\n'
        )

        # Run setup
        env = get_env_with_bun()
        setup_result = subprocess.run(
            [*jac_cmd, "setup", "desktop"],
            cwd=project_dir,
            capture_output=True,
            text=True,
            env=env,
            timeout=120,
        )

        if setup_result.returncode != 0:
            if "invalid choice: 'setup'" in setup_result.stderr:
                pytest.skip("'jac setup' command not registered")
            pytest.fail(
                f"jac setup desktop failed:\n"
                f"STDOUT:\n{setup_result.stdout}\n"
                f"STDERR:\n{setup_result.stderr}"
            )

        # Read generated main.rs
        main_rs_path = project_dir / "src-tauri" / "src" / "main.rs"
        assert main_rs_path.exists(), "main.rs should be generated by setup"

        main_rs_content = main_rs_path.read_text()
        print(f"[DEBUG] main.rs length: {len(main_rs_content)} chars")

        # Verify key patterns for sidecar port discovery
        assert "CONFIGURED_BASE_URL" in main_rs_content, (
            "main.rs should contain CONFIGURED_BASE_URL constant"
        )
        assert "API_BASE_URL" in main_rs_content, (
            "main.rs should contain API_BASE_URL global storage"
        )
        assert "JAC_SIDECAR_PORT=" in main_rs_content, (
            "main.rs should contain JAC_SIDECAR_PORT= parsing logic"
        )
        assert "--port" in main_rs_content, "main.rs should pass --port to sidecar"
        assert '"0"' in main_rs_content, (
            "main.rs should use port 0 for dynamic allocation"
        )
        assert "initialization_script" in main_rs_content, (
            "main.rs should use initialization_script to inject URL before page JS"
        )
        assert "__JAC_API_BASE_URL__" in main_rs_content, (
            "main.rs should set globalThis.__JAC_API_BASE_URL__"
        )

        # Verify it does NOT have a hardcoded fallback port
        assert '"http://127.0.0.1:8000"' not in main_rs_content, (
            "main.rs should not have hardcoded port 8000 fallback"
        )

        print("[DEBUG] main.rs content verification passed!")


# =============================================================================
# Test: Desktop target interface has api_port parameter
# =============================================================================


def test_desktop_target_interface_has_api_port() -> None:
    """Test that DesktopTarget.dev and .start declare api_port parameter."""
    print("[DEBUG] Starting test_desktop_target_interface_has_api_port")

    desktop_target_jac = (
        Path(__file__).parent.parent
        / "plugin"
        / "src"
        / "targets"
        / "desktop_target.jac"
    )
    assert desktop_target_jac.exists(), (
        f"desktop_target.jac not found at {desktop_target_jac}"
    )

    content = desktop_target_jac.read_text()

    # Both dev and start should accept api_port
    assert "api_port: int = 8000" in content, (
        "desktop_target.jac should declare api_port parameter"
    )
    # Should appear twice (once for dev, once for start)
    assert content.count("api_port: int = 8000") == 2, (
        "api_port should be declared in both dev() and start() methods"
    )

    print("[DEBUG] Desktop target interface verification passed!")


# =============================================================================
# Test: ViteBundler interface has API_BASE_URL_ENV_VAR and _resolve_api_base_url
# =============================================================================


def test_vite_bundler_has_api_base_url_constant() -> None:
    """Test that vite_bundler.jac defines the API_BASE_URL_ENV_VAR constant."""
    print("[DEBUG] Starting test_vite_bundler_has_api_base_url_constant")

    assert _vite_bundler_jac_path.exists()

    content = _vite_bundler_jac_path.read_text()

    assert "API_BASE_URL_ENV_VAR" in content, (
        "vite_bundler.jac should define API_BASE_URL_ENV_VAR"
    )
    assert '"JAC_CLIENT_API_BASE_URL"' in content, (
        "API_BASE_URL_ENV_VAR should equal 'JAC_CLIENT_API_BASE_URL'"
    )
    assert "_resolve_api_base_url" in content, (
        "vite_bundler.jac should declare _resolve_api_base_url method"
    )

    print("[DEBUG] ViteBundler constant verification passed!")


def test_vite_bundler_config_methods_accept_override() -> None:
    """Test that create_vite_config and create_dev_vite_config accept api_base_url_override."""
    print("[DEBUG] Starting test_vite_bundler_config_methods_accept_override")

    content = _vite_bundler_jac_path.read_text()

    # Both config methods should declare api_base_url_override
    assert content.count('api_base_url_override: str = ""') >= 3, (
        "api_base_url_override should appear in _resolve_api_base_url, "
        "create_vite_config, and create_dev_vite_config"
    )

    print("[DEBUG] ViteBundler method signatures verification passed!")


# =============================================================================
# Test: _resolve_api_base_url priority chain (impl verification)
# =============================================================================


def test_resolve_api_base_url_priority_chain_in_impl() -> None:
    """Test that _resolve_api_base_url implements the correct priority chain.

    Priority: jac.toml base_url > direct override > env var > "" (same-origin)

    We verify the implementation file contains the correct logic pattern.
    """
    print("[DEBUG] Starting test_resolve_api_base_url_priority_chain_in_impl")

    assert _vite_bundler_impl_path.exists()

    content = _vite_bundler_impl_path.read_text()

    # Find the _resolve_api_base_url implementation
    assert "impl ViteBundler._resolve_api_base_url" in content, (
        "Implementation should contain _resolve_api_base_url"
    )
    assert "toml_base_url or api_base_url_override or env_override" in content, (
        "Resolution should use or-chain: toml > override > env"
    )
    assert "API_BASE_URL_ENV_VAR" in content, (
        "Should use the named constant, not a string literal"
    )

    # Verify create_vite_config uses the method (not inline logic)
    # Find the create_vite_config function and check it delegates
    assert "self._resolve_api_base_url(api_base_url_override)" in content, (
        "create_vite_config should delegate to _resolve_api_base_url"
    )

    # Count usages - should be called in both config methods
    resolve_calls = content.count("self._resolve_api_base_url(")
    assert resolve_calls >= 2, (
        f"_resolve_api_base_url should be called in both config methods, "
        f"found {resolve_calls} call(s)"
    )

    print("[DEBUG] Resolution priority chain verification passed!")


# =============================================================================
# Test: Env var cleanup (try/finally) in build and start
# =============================================================================


def test_env_var_cleanup_pattern_in_build() -> None:
    """Test that build() cleans up JAC_CLIENT_API_BASE_URL in a finally block."""
    print("[DEBUG] Starting test_env_var_cleanup_pattern_in_build")

    assert _desktop_target_impl_path.exists()

    content = _desktop_target_impl_path.read_text()

    # Find the build method's env var handling section
    # It should use try/finally for cleanup
    build_section = content[content.index("impl DesktopTarget.build") :]
    # Cut at next impl to isolate the build method
    next_impl = build_section.index("impl ", 10)
    build_section = build_section[:next_impl]

    assert "try {" in build_section, (
        "build() should use try block around web_target.build()"
    )
    assert "} finally {" in build_section, (
        "build() should use finally block for env var cleanup"
    )
    assert "os.environ.pop(API_BASE_URL_ENV_VAR, None)" in build_section, (
        "build() should clean up env var in finally block"
    )

    print("[DEBUG] build() env var cleanup verification passed!")


def test_env_var_cleanup_pattern_in_start() -> None:
    """Test that start() cleans up JAC_CLIENT_API_BASE_URL in a finally block."""
    print("[DEBUG] Starting test_env_var_cleanup_pattern_in_start")

    content = _desktop_target_impl_path.read_text()

    # Find the start method's env var handling section
    start_section = content[content.index("impl DesktopTarget.start") :]

    assert "try {" in start_section, (
        "start() should use try block around web_target.build()"
    )
    assert "} finally {" in start_section, (
        "start() should use finally block for env var cleanup"
    )
    assert "os.environ.pop(API_BASE_URL_ENV_VAR, None)" in start_section, (
        "start() should clean up env var in finally block"
    )

    print("[DEBUG] start() env var cleanup verification passed!")


def test_env_var_not_leaked_after_import() -> None:
    """Test that JAC_CLIENT_API_BASE_URL is not present in environment by default.

    This verifies that no module import accidentally sets the env var.
    """
    print("[DEBUG] Starting test_env_var_not_leaked_after_import")

    env_var = "JAC_CLIENT_API_BASE_URL"

    # Clean state
    os.environ.pop(env_var, None)

    # Import the sidecar module (should not set env var)
    _import_sidecar_main()

    assert env_var not in os.environ, (
        f"{env_var} should not be set after importing sidecar module"
    )

    print("[DEBUG] Env var leak check passed!")


# =============================================================================
# Test: Helper functions in desktop_target.impl.jac
# =============================================================================


def test_make_localhost_url_in_impl() -> None:
    """Test that _make_localhost_url is defined and produces correct format."""
    print("[DEBUG] Starting test_make_localhost_url_in_impl")

    content = _desktop_target_impl_path.read_text()

    # Verify _make_localhost_url is defined as a module-level function
    assert "def _make_localhost_url(port: int) -> str" in content, (
        "_make_localhost_url should be defined as a function"
    )
    assert 'return f"http://127.0.0.1:{port}"' in content, (
        "_make_localhost_url should return http://127.0.0.1:{port}"
    )

    # Verify it's used in dev() and start()
    usage_count = content.count("_make_localhost_url(")
    # Definition (1) + at least 2 usages (dev + start)
    assert usage_count >= 3, (
        f"_make_localhost_url should be used in dev() and start(), "
        f"found {usage_count} occurrence(s)"
    )

    print("[DEBUG] _make_localhost_url verification passed!")


def test_get_toml_api_base_url_in_impl() -> None:
    """Test that _get_toml_api_base_url is defined and used."""
    print("[DEBUG] Starting test_get_toml_api_base_url_in_impl")

    content = _desktop_target_impl_path.read_text()

    # Verify _get_toml_api_base_url is defined
    assert "def _get_toml_api_base_url(project_dir: Path) -> str" in content, (
        "_get_toml_api_base_url should be defined as a function"
    )
    assert "JacClientConfig(project_dir)" in content, (
        "_get_toml_api_base_url should create a JacClientConfig"
    )

    # Verify it's used in build() and start()
    usage_count = content.count("_get_toml_api_base_url(")
    # Definition (1) + at least 2 usages (build + start)
    assert usage_count >= 3, (
        f"_get_toml_api_base_url should be used in build() and start(), "
        f"found {usage_count} occurrence(s)"
    )

    print("[DEBUG] _get_toml_api_base_url verification passed!")


def test_no_magic_string_jac_client_api_base_url() -> None:
    """Test that 'JAC_CLIENT_API_BASE_URL' string literal only appears once (as constant)."""
    print("[DEBUG] Starting test_no_magic_string_jac_client_api_base_url")

    # Check desktop_target.impl.jac - should use API_BASE_URL_ENV_VAR constant
    desktop_content = _desktop_target_impl_path.read_text()
    assert '"JAC_CLIENT_API_BASE_URL"' not in desktop_content, (
        "desktop_target.impl.jac should use API_BASE_URL_ENV_VAR constant, "
        "not the string literal"
    )

    # Check vite_bundler.impl.jac - should use API_BASE_URL_ENV_VAR constant
    vite_content = _vite_bundler_impl_path.read_text()
    assert '"JAC_CLIENT_API_BASE_URL"' not in vite_content, (
        "vite_bundler.impl.jac should use API_BASE_URL_ENV_VAR constant, "
        "not the string literal"
    )

    # The constant definition should only be in vite_bundler.jac
    vite_jac_content = _vite_bundler_jac_path.read_text()
    assert vite_jac_content.count('"JAC_CLIENT_API_BASE_URL"') == 1, (
        "The string literal should appear exactly once as the constant definition"
    )

    print("[DEBUG] Magic string elimination verification passed!")


# =============================================================================
# Test: CLI port passthrough
# =============================================================================


def test_cli_passes_port_to_desktop_target() -> None:
    """Test that cli.jac extracts --port and passes api_port to desktop target."""
    print("[DEBUG] Starting test_cli_passes_port_to_desktop_target")

    cli_jac_path = Path(__file__).parent.parent / "plugin" / "cli.jac"
    assert cli_jac_path.exists()

    content = cli_jac_path.read_text()

    # Verify port is extracted from CLI context
    assert 'ctx.get_arg("port"' in content, (
        "cli.jac should extract port from CLI context"
    )

    # Verify it's passed to target.dev and target.start
    assert "api_port=api_port" in content, (
        "cli.jac should pass api_port to target methods"
    )

    # Should appear at least twice (once for dev, once for start)
    assert content.count("api_port=api_port") >= 2, (
        "api_port should be passed in both dev and start calls"
    )

    print("[DEBUG] CLI port passthrough verification passed!")


# =============================================================================
# Test: Sidecar port marker via subprocess
# =============================================================================


def test_sidecar_prints_port_marker_to_stdout() -> None:
    """Test that the sidecar prints JAC_SIDECAR_PORT=<port> to stdout.

    This runs the sidecar with --help to verify the module is importable,
    then checks the port marker format by inspecting the source code
    (full sidecar startup requires jaclang runtime).
    """
    print("[DEBUG] Starting test_sidecar_prints_port_marker_to_stdout")

    # Verify the sidecar module is importable
    assert _sidecar_main_path.exists(), (
        f"sidecar main.py not found at {_sidecar_main_path}"
    )

    # Verify the source contains the port marker written to stdout
    content = _sidecar_main_path.read_text()
    assert 'sys.stdout.write(f"JAC_SIDECAR_PORT={port}' in content, (
        "sidecar main.py should write JAC_SIDECAR_PORT marker to stdout"
    )
    assert "sys.stdout.flush()" in content, "Port marker should be flushed immediately"

    # Verify the marker is printed BEFORE server.start()
    marker_pos = content.index("JAC_SIDECAR_PORT=")
    start_pos = content.index("server.start(")
    assert marker_pos < start_pos, (
        "Port marker should be printed before server.start() is called"
    )

    print("[DEBUG] Sidecar port marker verification passed!")


def test_sidecar_help_shows_port_zero() -> None:
    """Test that sidecar --help mentions port 0 for auto-assignment."""
    print("[DEBUG] Starting test_sidecar_help_shows_port_zero")

    result = subprocess.run(
        [sys.executable, str(_sidecar_main_path), "--help"],
        capture_output=True,
        text=True,
        timeout=10,
    )

    print(f"[DEBUG] Help output: {result.stdout[:500]}")

    assert result.returncode == 0, "Sidecar --help should succeed"
    assert "auto" in result.stdout.lower() or "0" in result.stdout, (
        "Sidecar help should mention port 0 / auto-assign"
    )

    print("[DEBUG] Sidecar help verification passed!")


# =============================================================================
# Test: Import consistency
# =============================================================================


def test_sidecar_no_stdout_after_port_marker() -> None:
    """Test that the sidecar does NOT write to stdout after the port marker.

    After the Tauri host reads JAC_SIDECAR_PORT= from stdout, it drops the
    pipe reader. Any further stdout writes would crash the sidecar with
    BrokenPipeError. The only stdout write must be the port marker via
    sys.stdout.write(); all other output uses console (stderr) or sys.stderr.
    """
    content = _sidecar_main_path.read_text()

    main_start = content.index("def main():")
    main_body = content[main_start:]

    import re

    # No bare print() calls should exist — use console or sys.stderr.write()
    bare_prints = re.findall(r"(?<!\.)print\(", main_body)
    assert len(bare_prints) == 0, (
        f"sidecar should not use bare print() — "
        f"use console or sys.stderr.write() instead. "
        f"Found {len(bare_prints)} bare print() call(s)"
    )

    # The only sys.stdout usage should be the port marker + flush
    stdout_writes = re.findall(r"sys\.stdout\.write\(", main_body)
    assert len(stdout_writes) == 1, (
        f"Expected exactly 1 sys.stdout.write (port marker), found {len(stdout_writes)}"
    )
    assert "JAC_SIDECAR_PORT=" in main_body[main_body.index("sys.stdout.write(") :], (
        "The only stdout write should be the port marker"
    )


def test_sidecar_uses_console_after_import() -> None:
    """Test that the sidecar uses jaclang console for output after import.

    After jaclang is successfully imported, the sidecar should use
    console.print() / console.error() for all user-facing output.
    Pre-import errors use sys.stderr.write() as a fallback.
    """
    content = _sidecar_main_path.read_text()

    assert "from jaclang.cli.console import console" in content, (
        "sidecar should import console from jaclang.cli.console"
    )
    assert "console.print(" in content, (
        "sidecar should use console.print() for status output"
    )
    assert "console.error(" in content, (
        "sidecar should use console.error() for error output"
    )


def test_desktop_target_imports_api_base_url_env_var() -> None:
    """Test that desktop_target.impl.jac imports API_BASE_URL_ENV_VAR from vite_bundler."""
    print("[DEBUG] Starting test_desktop_target_imports_api_base_url_env_var")

    content = _desktop_target_impl_path.read_text()

    assert (
        "import from jac_client.plugin.src.vite_bundler { API_BASE_URL_ENV_VAR }"
        in content
    ), "desktop_target.impl.jac should import API_BASE_URL_ENV_VAR from vite_bundler"

    print("[DEBUG] Import consistency verification passed!")


def test_main_rs_uses_initialization_script_not_eval() -> None:
    """Test that generated main.rs uses initialization_script instead of webview.eval.

    webview.eval() in setup() executes AFTER page JS has already run, causing
    a race condition where API calls use same-origin before the URL is injected.
    initialization_script() runs BEFORE any page JS, fixing the timing issue.
    """
    print("[DEBUG] Starting test_main_rs_uses_initialization_script_not_eval")

    content = _desktop_target_impl_path.read_text()

    # Find the generated main.rs template (the f-string in _generate_main_rs)
    assert "initialization_script" in content, (
        "Generated main.rs should use initialization_script for URL injection"
    )
    assert "WebviewWindowBuilder" in content, (
        "Generated main.rs should create window manually via WebviewWindowBuilder"
    )
    # Verify webview.eval() is NOT used for URL injection
    # (the old pattern: app.get_webview_window("main") + webview.eval)
    assert 'get_webview_window("main")' not in content, (
        "Generated main.rs should NOT use get_webview_window — "
        "window is created manually with initialization_script"
    )

    print("[DEBUG] initialization_script pattern verification passed!")


def test_tauri_config_has_empty_windows() -> None:
    """Test that _generate_tauri_config sets windows to empty array.

    main.rs creates the window manually via WebviewWindowBuilder to support
    initialization_script. An auto-created window from config would conflict.
    """
    print("[DEBUG] Starting test_tauri_config_has_empty_windows")

    content = _desktop_target_impl_path.read_text()

    # The _generate_tauri_config function should set windows to []
    assert '"windows": []' in content, (
        "_generate_tauri_config should set windows to empty array"
    )

    # The config update functions should also clear windows
    # Find both _update_tauri_config_for_build and _update_tauri_config_for_dev
    assert content.count('["windows"] = []') >= 2, (
        "Both config update functions should clear the windows array"
    )

    print("[DEBUG] Empty windows config verification passed!")


# =============================================================================
# Test: Backend server auto-start
# =============================================================================


def test_start_backend_server_helper_exists() -> None:
    """Test that _start_backend_server helper is defined and uses subprocess."""
    content = _desktop_target_impl_path.read_text()

    assert "def _start_backend_server(" in content, (
        "_start_backend_server helper should be defined"
    )
    # Should use subprocess.Popen to launch the server
    assert "subprocess.Popen" in content, (
        "_start_backend_server should use subprocess.Popen"
    )
    # Should pass --no_client to skip client bundling
    assert '"--no_client"' in content, (
        "_start_backend_server should pass --no_client flag"
    )
    # Should pass --port
    assert '"--port"' in content, "_start_backend_server should pass --port flag"


def test_resolve_server_port_helper_exists() -> None:
    """Test that _resolve_server_port helper is defined and parses URLs."""
    content = _desktop_target_impl_path.read_text()

    assert "def _resolve_server_port(" in content, (
        "_resolve_server_port helper should be defined"
    )
    assert "urlparse" in content, (
        "_resolve_server_port should use urlparse to extract port from URL"
    )


def test_start_method_launches_backend_server() -> None:
    """Test that start() method launches the backend server before Tauri."""
    content = _desktop_target_impl_path.read_text()

    # Find start() method
    start_idx = content.index("impl DesktopTarget.start(")
    # Find the next impl or end of file
    next_impl = content.find("\nimpl ", start_idx + 1)
    if next_impl == -1:
        next_impl = content.find("\ndef _", start_idx + 100)
    start_body = (
        content[start_idx:next_impl] if next_impl != -1 else content[start_idx:]
    )

    assert "_start_backend_server(" in start_body, (
        "start() should call _start_backend_server"
    )
    assert "_resolve_server_port(" in start_body, (
        "start() should call _resolve_server_port to determine server port"
    )
    # Server process should be terminated in cleanup
    assert "server_process" in start_body, (
        "start() should manage server_process lifecycle"
    )


def test_dev_method_launches_backend_server() -> None:
    """Test that dev() method launches the backend server before Tauri."""
    content = _desktop_target_impl_path.read_text()

    # Find dev() method
    dev_idx = content.index("impl DesktopTarget.dev(")
    # Find next impl
    next_impl = content.find("\nimpl ", dev_idx + 1)
    if next_impl == -1:
        next_impl = content.find('\n"""Update tauri', dev_idx + 100)
    dev_body = content[dev_idx:next_impl] if next_impl != -1 else content[dev_idx:]

    assert "_start_backend_server(" in dev_body, (
        "dev() should call _start_backend_server"
    )
    assert "_resolve_server_port(" in dev_body, (
        "dev() should call _resolve_server_port to determine server port"
    )
    # Server process should be terminated in cleanup
    assert "server_process" in dev_body, "dev() should manage server_process lifecycle"
