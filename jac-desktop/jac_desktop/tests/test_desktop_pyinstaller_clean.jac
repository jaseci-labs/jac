"""Tests for PyInstaller invocation in desktop sidecar builds."""

import re;
import from _helpers { _DESKTOP_HELPERS_IMPL }

test "pyinstaller command does not include --clean" {
    assert _DESKTOP_HELPERS_IMPL.exists();

    content = _DESKTOP_HELPERS_IMPL.read_text(encoding="utf-8");
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
    assert '"--noconfirm"' in args_block , (
        "PyInstaller invocation should still include --noconfirm"
    );
}
