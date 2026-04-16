"""Tests for Windows PyInstaller sidecar support.

Validates the onedir/UTF-8/multiprocessing bits that desktop Windows builds
need in the generated PyInstaller spec, entry script, and Tauri config wiring.
"""

import re;
import from pathlib { Path }

glob _plugin_src = Path(__file__).parent.parent / "plugin" / "src",
     _desktop_target_impl_path = _plugin_src / "targets" / "impl" / "desktop_target.impl.jac";


test "sidecar entry script calls multiprocessing freeze_support on windows" {
    assert _desktop_target_impl_path.exists();

    content = _desktop_target_impl_path.read_text();

    # The sidecar_entry.py generator must set PYTHONUTF8 and call
    # multiprocessing.freeze_support() on win32, guarding against re-entering
    # main() when the spawn start method re-executes the frozen binary.
    assert 'os.environ["PYTHONUTF8"] = "1"' in content , (
        "Generated sidecar entry script should set PYTHONUTF8=1"
    );
    assert 'multiprocessing.freeze_support()' in content , (
        "Generated sidecar entry script should call multiprocessing.freeze_support()"
    );
    assert 'if sys.platform == "win32":' in content , (
        "freeze_support() should be guarded by sys.platform == 'win32'"
    );
}


test "pyinstaller spec uses onedir mode with utf8 runtime hook" {
    content = _desktop_target_impl_path.read_text();

    # Runtime hook for UTF-8 must be generated on disk and wired into the spec.
    assert 'rthook_utf8.py' in content , (
        "rthook_utf8.py must be written alongside the PyInstaller spec"
    );
    assert re.search(
        r"runtime_hooks\s*=\s*\[str\(Path\(r'\{entry_script\}'\)\.parent / 'rthook_utf8\.py'\)\]",
        content
    ) is not None , ("Analysis(runtime_hooks=...) should reference rthook_utf8.py");

    # Spec must use onedir mode: EXE(..., exclude_binaries=True, ...) + COLLECT(...)
    assert 'exclude_binaries=True' in content , (
        "EXE block should use exclude_binaries=True for onedir mode"
    );
    assert "COLLECT(" in content , (
        "Spec template should contain a COLLECT(...) step for onedir output"
    );
    assert "name='jac-sidecar'" in content , (
        "COLLECT should name the onedir output 'jac-sidecar'"
    );

    # Windows multiprocessing hiddenimports
    assert "'multiprocessing.popen_spawn_win32'" in content , (
        "hiddenimports must include multiprocessing.popen_spawn_win32 for "
        "Windows spawn start method"
    );
    assert "'multiprocessing.spawn'" in content , (
        "hiddenimports must include multiprocessing.spawn"
    );
}


test "tauri config adds onedir sidecar folder as bundle resource" {
    content = _desktop_target_impl_path.read_text();

    # _add_sidecar_to_config must notice onedir output and add the glob so
    # Tauri ships every file in the onedir folder.
    section_start = content.index("def _add_sidecar_to_config");
    next_impl = content.index("\n\"\"\"", section_start + 10);
    section = content[section_start:next_impl];

    assert 'binaries/jac-sidecar/**/*' in section , (
        "_add_sidecar_to_config should add 'binaries/jac-sidecar/**/*' to "
        "bundle.resources when the onedir folder is present"
    );
    assert 'onedir_folder = binaries_dir / "jac-sidecar"' in section , (
        "_add_sidecar_to_config should probe for the onedir folder"
    );
}


test "rust sidecar lookup tries onedir path first" {
    content = _desktop_target_impl_path.read_text();

    # The generated Rust sidecar-startup code must try the onedir path
    # before the onefile/wrapper fallbacks so a bundled onedir output is
    # preferred.
    assert '"binaries/jac-sidecar/jac-sidecar.exe"' in content , (
        "Windows sidecar lookup should include the onedir exe path"
    );
    assert '"binaries/jac-sidecar/jac-sidecar"' in content , (
        "Unix sidecar lookup should include the onedir binary path"
    );
}
