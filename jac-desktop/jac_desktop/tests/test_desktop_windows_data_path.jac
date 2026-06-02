"""Tests for Windows data path in jac_desktop.runtime."""

import from _helpers { _RUNTIME_PY }

test "runtime picks windows data path" {
    assert _RUNTIME_PY.exists();

    content = _RUNTIME_PY.read_text(encoding="utf-8");

    assert 'os.environ.get("LOCALAPPDATA")' in content , (
        "Windows data path should read LOCALAPPDATA"
    );
    assert 'os.environ.get("USERPROFILE")' in content or '"USERPROFILE"' in content , (
        "Windows data path should fall back to USERPROFILE"
    );
    assert 'os.environ.get("HOME", ".")' in content , (
        "Unix data path should still read HOME"
    );
    assert "def _data_path()" in content , ("Runtime should define _data_path()");
}

test "runtime passes data path to sidecar" {
    content = _RUNTIME_PY.read_text(encoding="utf-8");
    assert '"--data-path"' in content , (
        "Sidecar spawn should pass --data-path for writable app storage"
    );
    assert "str(_data_path())" in content , (
        "Sidecar should receive computed _data_path() value"
    );
}
