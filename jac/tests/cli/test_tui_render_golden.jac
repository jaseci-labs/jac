"""Golden-render regression test for the native ai_tui_na screen_render.

Builds (if stale) and runs the dev-only selftest binary via golden_render.py,
which diffs every rendered frame against a byte-exact golden baseline under
tests/golden/tui_render/. This is the safety net for Plan 01 Phase 1
(component extraction): after the refactor, Screen.render must produce
byte-identical output to the pre-refactor screen_render captured here.

Requires the native toolchain (jac nacompile + the libjacpyembed shim staged
by `zig build`); skipped when the shim is absent so this never fails on
Python-only CI.
"""

import os;
import subprocess;
import sys;
import pytest;
import jaclang.cli.ai_tui.tui_shared as tui_shared;
import from pathlib { Path }


test "native screen_render golden frames match the baseline" {
    cli_dir = Path(tui_shared.__file__).resolve().parent.parent;
    na_dir = cli_dir / "ai_tui_na";
    runner = na_dir / "golden_render.py";
    assert runner.is_file() , f"golden_render.py not found at {runner}";

    # Skip on Python-only CI: the build needs jac nacompile + the libjacpyembed
    # shim staged by `zig build`. Its absence means the native toolchain isn't
    # built, so this regression net can't run here.
    repo_root = cli_dir.parent.parent.parent;
    shim_dir = (
        repo_root / "jac" / "jaclang" / "runtimelib" / "client" / "targets" / "desktop" / "native"
    );
    shim_name = "libjacpyembed.dylib"
        if sys.platform == "darwin"
        else "libjacpyembed.so";
    if not (shim_dir / shim_name).is_file() {
        pytest.skip(f"native toolchain shim not built ({shim_name}); run `zig build`");
    }

    # golden_render.py builds the selftest binary if stale, runs it, and diffs
    # every frame against the golden baseline. Exit 0 == all frames match.
    proc = subprocess.run(
        [sys.executable, str(runner)], capture_output=True, text=True
    );
    assert proc.returncode == 0 , (
        f"golden_render.py failed (exit {proc.returncode}):\n"
        f"--- stdout ---\n{proc.stdout}\n"
        f"--- stderr ---\n{proc.stderr}"
    );
}
