"""Tests for desktop build configuration constants.

Validates build-related constants and messages embedded in the desktop target
implementation (timeout values, error messages) without needing to invoke
PyInstaller or subprocess calls.
"""

import from pathlib { Path }

glob _plugin_src = Path(__file__).parent.parent / "plugin" / "src",
     _desktop_target_impl_path = _plugin_src / "targets" / "impl" / "desktop_target.impl.jac";


test "pyinstaller build timeout is at least two hours" {
    assert _desktop_target_impl_path.exists();

    content = _desktop_target_impl_path.read_text();

    # The SUBPROCESS_TIMEOUT_BUILD constant must be >= 7200 seconds so that
    # slow first-run PyInstaller builds on Windows (where ~20 modules compile
    # on first `jaclang --version`) do not hit the timeout.
    assert "SUBPROCESS_TIMEOUT_BUILD: int = 7200" in content , (
        "SUBPROCESS_TIMEOUT_BUILD should be 7200s (2 hours) to cover slow Windows builds"
    );

    # Message must match the raised timeout so users are not misled.
    assert "PyInstaller timed out after 2 hours" in content , (
        "PyInstaller timeout message should say '2 hours' to match SUBPROCESS_TIMEOUT_BUILD"
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
