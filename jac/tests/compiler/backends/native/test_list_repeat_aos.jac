"""list *= n stays correct at the AoS growth boundary (#10394).

Under enforced headerless codegen `list[own Cell]` lowers to a by-value
buffer whose get() returns an interior pointer. A naive repeat loop feeds
that pointer straight into push(), which frees the buffer mid-iteration
once the initial capacity of eight is exceeded -- `[c] * 9` is the
smallest repro. The emitter reserves `len * n` slots before the first
copy, clears by releasing live elements before zeroing the length, and
short-circuits empty lists, mirroring CPython's list.__imul__.
"""

import os;
import shutil;
import subprocess;
import tempfile;
import from tests.support { jac_command, TESTS_DIR }

glob FIXTURE = os.path.join(
         TESTS_DIR,
         "compiler",
         "backends",
         "native",
         "fixtures",
         "nogc",
         "list_repeat_aos.jac"
     );

def _build_and_run(out_bin: str) -> list[str] {
    res = subprocess.run(
        jac_command("build", "--native", FIXTURE, "--memory", "nogc", "-o", out_bin),
        capture_output=True,
        text=True,
        timeout=300
    );
    combined = (res.stdout or "") + (res.stderr or "");
    assert res.returncode == 0 , f"build failed: {combined[-900:]}";
    proc = subprocess.run([out_bin], capture_output=True, text=True, timeout=60);
    assert proc.returncode == 0 , f"binary failed: {proc.stderr[-400:]
        if proc.stderr
        else '(empty)'}";
    return proc.stdout.strip().split("\n");
}

test "list[own Cell] *= n grows once, clears, and skips empty repeats" {
    out_bin = os.path.join(tempfile.mkdtemp(), "rep_aos.bin");
    out = _build_and_run(out_bin);
    # 9 cells of (a=7, b=11): each contributes 7*100 + 11 = 711.
    assert out == ["6399", "0", "506", "0", "end"] , f"aos repeat output mismatch: {out}";
}

test "list[own Cell] *= n binary is leak-free" {
    if shutil.which("leaks") {
        out_bin = os.path.join(tempfile.mkdtemp(), "rep_aos_leaks.bin");
        _build_and_run(out_bin);
        lk = subprocess.run(
            ["leaks", "--atExit", "--", out_bin], capture_output=True, text=True
        );
        assert "0 leaks for 0 total leaked bytes" in lk.stdout , lk.stdout[-2000:];
    }
}
