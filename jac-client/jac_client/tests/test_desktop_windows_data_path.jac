"""Tests for Windows data path + cc build-tool check skip.

Validates that the Tauri main.rs template computes a sensible writable
data path on Windows, and that _run_tauri_dev does not probe for `cc` on
Windows (where MSVC handles native compilation).
"""

import re;
import from pathlib { Path }

glob _plugin_src = Path(__file__).parent.parent / "plugin" / "src",
     _desktop_target_impl_path = _plugin_src / "targets" / "impl" / "desktop_target.impl.jac";


test "generated tauri main rs picks windows data path" {
    assert _desktop_target_impl_path.exists();

    content = _desktop_target_impl_path.read_text();

    # Windows branch must probe LOCALAPPDATA with a USERPROFILE fallback.
    assert 'std::env::var_os("LOCALAPPDATA")' in content , (
        "Windows data path should read LOCALAPPDATA"
    );
    assert 'std::env::var_os("USERPROFILE")' in content , (
        "Windows data path should fall back to USERPROFILE"
    );

    # The branches must be compile-time gated so the generated Rust only
    # pulls the appropriate code path per target.
    assert "#[cfg(windows)]" in content , (
        "Data path computation should use #[cfg(windows)] gate"
    );
    assert "#[cfg(not(windows))]" in content , (
        "Unix data path branch should use #[cfg(not(windows))] gate"
    );

    # Unix branch must still compute HOME/.local/share/jac-app.
    assert 'std::env::var_os("HOME")' in content , (
        "Unix data path should still read HOME"
    );
}


test "run tauri dev skips cc version check on windows" {
    content = _desktop_target_impl_path.read_text();

    run_dev_idx = content.index("def _run_tauri_dev");
    # Slice to the next function/impl to isolate this helper.
    next_decl_idx = content.find("\ndef ", run_dev_idx + 10);
    if next_decl_idx == -1 {
        next_decl_idx = len(content);
    }
    section = content[run_dev_idx:next_decl_idx];

    # The cc --version probe must be wrapped in a sys.platform guard.
    assert 'if sys.platform != "win32"' in section , (
        "_run_tauri_dev should guard the cc --version probe with "
        "'if sys.platform != \"win32\"' so Windows (MSVC) is not penalised"
    );

    # Sanity: the cc probe is still present (just conditional).
    assert '["cc", "--version"]' in section , (
        "cc --version probe should still be invoked on non-Windows platforms"
    );
}
