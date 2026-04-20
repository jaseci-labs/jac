"""Tests for desktop build configuration constants.

Validates build-related constants, config plumbing, and messages embedded in
the desktop target implementation (timeout values, error messages) without
needing to invoke PyInstaller or subprocess calls.
"""

import from pathlib { Path }

glob _plugin_src = Path(__file__).parent.parent / "plugin" / "src",
     _desktop_target_impl_path = _plugin_src / "targets" / "impl" / "desktop_target.impl.jac",
     _desktop_config_path = _plugin_src / "desktop_config.jac",
     _desktop_config_impl_path = _plugin_src / "impl" / "desktop_config.impl.jac";


test "pyinstaller build timeout default is 40 minutes" {
    assert _desktop_target_impl_path.exists();

    content = _desktop_target_impl_path.read_text();

    # The SUBPROCESS_TIMEOUT_BUILD default is 2400s (40 min). Long enough to
    # cover a cold-cache Windows + PyInstaller first run; short enough to fail
    # fast when a build is genuinely stuck rather than burning two hours.
    assert "SUBPROCESS_TIMEOUT_BUILD: int = 2400" in content , (
        "SUBPROCESS_TIMEOUT_BUILD should default to 2400s (40 min)"
    );

    # The timeout error must surface the seconds/minutes dynamically (since the
    # value is now configurable) and point users to the jac.toml key.
    assert (
        "PyInstaller timed out after {pyinstaller_timeout // 60} minutes" in content
    ) , (
        "PyInstaller timeout warning must render the actual configured value"
    );
    assert "[desktop.bundle] pyinstaller_timeout" in content , (
        "Timeout warning must tell users which jac.toml key raises the limit"
    );
}


test "pyinstaller_timeout is configurable via [desktop.bundle]" {
    # Public API: DesktopConfig exposes get_pyinstaller_timeout().
    config_def = _desktop_config_path.read_text();
    assert "def get_pyinstaller_timeout" in config_def , (
        "DesktopConfig must declare get_pyinstaller_timeout() in its class body"
    );

    # Impl reads from the 'bundle' section, not 'plugins' or a top-level key.
    config_impl = _desktop_config_impl_path.read_text();
    assert "impl DesktopConfig.get_pyinstaller_timeout" in config_impl , (
        "DesktopConfig.get_pyinstaller_timeout must be implemented"
    );
    assert "bundle.get('pyinstaller_timeout'" in config_impl , (
        "get_pyinstaller_timeout must read from [desktop.bundle] pyinstaller_timeout"
    );

    # Default config must expose a [bundle] section so deep_merge preserves user overrides.
    assert "'bundle':" in config_impl , (
        "Default config must include a 'bundle' section with pyinstaller_timeout"
    );
    assert "'pyinstaller_timeout': 2400" in config_impl , (
        "Default pyinstaller_timeout must be 2400 seconds (40 min)"
    );
}


test "bundle sidecar plumbs timeout from config" {
    content = _desktop_target_impl_path.read_text();

    # _bundle_sidecar_pyinstaller must accept a pyinstaller_timeout parameter
    # so the caller can override the default without monkey-patching the constant.
    assert "pyinstaller_timeout: int = SUBPROCESS_TIMEOUT_BUILD" in content , (
        "_bundle_sidecar / _bundle_sidecar_pyinstaller must accept a "
        "pyinstaller_timeout parameter defaulting to SUBPROCESS_TIMEOUT_BUILD"
    );

    # The subprocess call must use the parameter, not the bare constant --
    # otherwise the config is silently ignored.
    assert "timeout=pyinstaller_timeout" in content , (
        "The PyInstaller subprocess.run must pass the plumbed timeout parameter"
    );

    # And the call site must actually read the config.
    assert "desktop_config.get_pyinstaller_timeout()" in content , (
        "The caller must read desktop_config.get_pyinstaller_timeout() and "
        "pass it into _bundle_sidecar"
    );
}


test "jaclang version probe uses medium timeout" {
    content = _desktop_target_impl_path.read_text();

    # The first `python -m jaclang --version` probe can take tens of seconds
    # on Windows because it compiles ~20 modules on first run. Using the
    # 5-second SHORT timeout caused spurious failures; it must use MEDIUM (60s).
    probe_idx = content.find('[python_cmd, "-m", "jaclang", "--version"]');
    assert probe_idx != -1 , "Could not locate jaclang --version probe";

    # Inspect the lines immediately after the command list for the timeout kwarg.
    probe_block = content[probe_idx:probe_idx + 400];
    assert "timeout=SUBPROCESS_TIMEOUT_MEDIUM" in probe_block , (
        "jaclang --version probe should use SUBPROCESS_TIMEOUT_MEDIUM, not SHORT"
    );
}
