"""Tests for Windows PyInstaller sidecar support (PyTauri desktop)."""

import re;
import from _helpers { _DESKTOP_HELPERS_IMPL, _PYTAURI_TARGET_IMPL, _RUNTIME_PY }

test "sidecar entry script calls multiprocessing freeze_support on windows" {
    assert _DESKTOP_HELPERS_IMPL.exists();

    content = _DESKTOP_HELPERS_IMPL.read_text(encoding="utf-8");
    assert 'os.environ["PYTHONUTF8"] = "1"' in content , (
        "Generated sidecar entry script should set PYTHONUTF8=1"
    );
    assert "multiprocessing.freeze_support()" in content , (
        "Generated sidecar entry script should call multiprocessing.freeze_support()"
    );
    assert 'if sys.platform == "win32":' in content , (
        "freeze_support() should be guarded by sys.platform == 'win32'"
    );
}

test "pyinstaller spec uses onedir mode with utf8 runtime hook" {
    content = _DESKTOP_HELPERS_IMPL.read_text(encoding="utf-8");

    assert "rthook_utf8.py" in content , (
        "rthook_utf8.py must be written alongside the PyInstaller spec"
    );
    assert re.search(
        r"runtime_hooks\s*=\s*\[str\(Path\(r'\{entry_script\}'\)\.parent / 'rthook_utf8\.py'\)\]",
        content
    ) is not None , "Analysis(runtime_hooks=...) should reference rthook_utf8.py";

    assert "exclude_binaries=True" in content , (
        "EXE block should use exclude_binaries=True for onedir mode"
    );
    assert "COLLECT(" in content , "Spec template should contain a COLLECT(...) step for onedir output";
    assert "name='jac-sidecar'" in content , "COLLECT should name the onedir output 'jac-sidecar'";

    assert "'multiprocessing.popen_spawn_win32'" in content , (
        "hiddenimports must include multiprocessing.popen_spawn_win32 for "
        "Windows spawn start method"
    );
    assert "'multiprocessing.spawn'" in content , (
        "hiddenimports must include multiprocessing.spawn"
    );
}

test "runtime sidecar lookup tries onedir path first" {
    assert _RUNTIME_PY.exists();

    content = _RUNTIME_PY.read_text(encoding="utf-8");
    assert '"binaries/jac-sidecar/jac-sidecar.exe"' in content , (
        "Windows sidecar lookup should include the onedir exe path"
    );
    assert '"binaries/jac-sidecar/jac-sidecar"' in content , (
        "Unix sidecar lookup should include the onedir binary path"
    );
}

test "pytauri setup scaffolds binaries directory for sidecar staging" {
    content = _PYTAURI_TARGET_IMPL.read_text(encoding="utf-8");
    setup_start = content.index("impl PyTauriDesktopTarget.setup(");
    setup_end = content.index("impl PyTauriDesktopTarget.build(", setup_start);
    setup_body = content[setup_start:setup_end];

    assert '"binaries"' in setup_body , (
        "setup should create src-pytauri/binaries for sidecar staging"
    );
}
