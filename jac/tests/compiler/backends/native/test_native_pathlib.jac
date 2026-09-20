"""Compare Python and native Path behavior, including fields, iteration, and filesystem errors."""

import ctypes;
import from tests.support { jac_command, compile_native, get_func }

import os;
import subprocess;
import tempfile;
import from pathlib { Path }

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures");

def _sv_run(fixture: str) -> str {
    src = os.path.join(FIXTURES, fixture);
    proc = subprocess.run(
        jac_command("run", "--backend", "python", src),
        capture_output=True,
        text=True,
        timeout=900
    );
    assert proc.returncode == 0 , "sv run failed: "
        + (proc.stdout + proc.stderr)[-3000:];
    return proc.stdout;
}

def _na_run(fixture: str) -> str {
    src = os.path.join(FIXTURES, fixture);
    out_bin = os.path.join(tempfile.mkdtemp(), "probe.bin");
    comp = subprocess.run(
        jac_command("build", "--native", src, "-o", out_bin),
        capture_output=True,
        text=True,
        timeout=900
    );
    assert comp.returncode == 0 , "nacompile failed: "
        + (comp.stdout + comp.stderr)[-3000:];
    proc = subprocess.run([out_bin], capture_output=True, text=True, timeout=120);
    assert proc.returncode == 0 , f"binary failed: {proc.stderr[-400:]
        if proc.stderr
        else '(empty)'}";
    return proc.stdout;
}

test "the native Path answers what CPython's Path answers" {
    sv = [
        _l
        for _l in _sv_run("pathlib_probe.jac").split("\n")
        if _l.strip()
    ];
    na = [
        _l
        for _l in _na_run("pathlib_probe.jac").split("\n")
        if _l.strip()
    ];
    assert sv , "sv pathway produced no output";
    assert len(sv) == len(na) , f"line count: sv {len(sv)} vs na {len(na)}";
    for idx in range(len(sv)) {
        assert sv[idx] == na[idx] , f"line {idx}: sv {sv[idx]!r} vs na {na[idx]!r}";
    }
}

test "Python Path members use the complete CPython implementation" {
    (engine, _) = compile_native("pathlib_suffix.jac", required=True);
    assert get_func(engine, "suffix_matches", ctypes.c_bool)();
}
