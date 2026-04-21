"""Tests for PyInstaller invocation in desktop sidecar builds.

Validates that the PyInstaller command does not pass --clean, so incremental
rebuilds can reuse the cache.
"""

import re;
import from pathlib { Path }

glob _plugin_src = Path(__file__).parent.parent / "plugin" / "src",
     _desktop_target_impl_path = _plugin_src / "targets" / "impl" / "desktop_target.impl.jac";


test "pyinstaller command does not include --clean" {
    assert _desktop_target_impl_path.exists();

    content = _desktop_target_impl_path.read_text();

    # Find the PyInstaller subprocess invocation (the arg list that begins with
    # sys.executable, "-m", "PyInstaller").
    m = re.search(
        r'sys\.executable\s*,\s*"-m"\s*,\s*"PyInstaller"\s*,(.*?)str\(spec_path\)',
        content,
        re.DOTALL
    );
    assert m is not None , "Could not locate PyInstaller invocation arg list";

    args_block = m.group(1);
    assert '"--clean"' not in args_block , (
        "PyInstaller invocation should not include --clean; it forces a full "
        "rebuild on every run, slowing incremental sidecar builds."
    );
    # Sanity check: we still pass --noconfirm so the build is non-interactive.
    assert '"--noconfirm"' in args_block , (
        "PyInstaller invocation should still include --noconfirm"
    );
}
