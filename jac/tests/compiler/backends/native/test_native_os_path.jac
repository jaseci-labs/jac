"""Native os.path members must report real file-system state on the host."""

import from tests.support { jac_command, native_build_fails }

import os;
import subprocess;
import tempfile;
import from pathlib { Path }

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures");

def _nacompile_run(fixture: str) -> str {
    src = os.path.join(FIXTURES, fixture);
    out_bin = os.path.join(tempfile.mkdtemp(), "probe.bin");
    comp = subprocess.run(
        jac_command("build", "--native", src, "-o", out_bin),
        capture_output=True,
        text=True,
        timeout=300
    );
    assert comp.returncode == 0 , f"nacompile failed: {comp.stderr[-800:]
        if comp.stderr
        else '(empty)'}";
    env = os.environ.copy();
    env["JAC_NATIVE_OS_PATH_TEST"] = "environment text";
    proc = subprocess.run(
        [out_bin], capture_output=True, text=True, timeout=60, env=env
    );
    assert proc.returncode == 0 , f"binary failed: {proc.stderr[-400:]
        if proc.stderr
        else '(empty)'}";
    return proc.stdout;
}

test "os path isfile and isdir report real file kinds natively" {
    out = _nacompile_run("os_path_probe.jac").strip().split("\n");
    assert out
        == [
            "True",
            "False",
            "True",
            "False",
            "True",
            "False",
            "5",
            "-1",
            "True",
            "jac_ospath_probe.txt",
            "environment text"
        ] , f"os.path probe mismatch: {out}";
}

test "unsupported os path members fail the native compile loudly" {
    combined = native_build_fails(os.path.join(FIXTURES, "os_path_unsupported.jac"));
    assert "islink" in combined , f"diagnostic does not name the member: {combined[-400:]}";
}
