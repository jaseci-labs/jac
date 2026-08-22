"""Native os.path members must report real file-system state on the host."""

import os;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures");

def _nacompile_run(fixture: str) -> str {
    src = os.path.join(FIXTURES, fixture);
    out_bin = os.path.join(tempfile.mkdtemp(), "probe.bin");
    comp = subprocess.run(
        [sys.executable, "-m", "jaclang", "nacompile", src, "-o", out_bin],
        capture_output=True,
        text=True,
        timeout=300
    );
    assert comp.returncode == 0 , f"nacompile failed: {comp.stderr[-800:]
        if comp.stderr
        else '(empty)'}";
    proc = subprocess.run([out_bin], capture_output=True, text=True, timeout=60);
    assert proc.returncode == 0 , f"binary failed: {proc.stderr[-400:]
        if proc.stderr
        else '(empty)'}";
    return proc.stdout;
}

test "os path isfile and isdir report real file kinds natively" {
    out = _nacompile_run("os_path_probe.jac").strip().split("\n");
    assert out == ["True", "False", "True", "False", "True", "False", "5", "-1"] , f"os.path probe mismatch: {out}";
}

test "unsupported os path members fail the native compile loudly" {
    src = os.path.join(FIXTURES, "os_path_unsupported.jac");
    out_bin = os.path.join(tempfile.mkdtemp(), "nope.bin");
    comp = subprocess.run(
        [sys.executable, "-m", "jaclang", "nacompile", src, "-o", out_bin],
        capture_output=True,
        text=True,
        timeout=300
    );
    combined = (comp.stdout or "") + (comp.stderr or "");
    assert comp.returncode != 0 , f"unsupported os.path member compiled silently: {combined[-400:]}";
    assert "islink" in combined , f"diagnostic does not name the member: {combined[-400:]}";
}
