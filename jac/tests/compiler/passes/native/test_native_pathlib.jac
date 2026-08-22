"""The bundled `pathlib` shim must answer exactly what CPython's does.

`import from pathlib { Path }` binds CPython's `pathlib` on the sv pathway and
`na_stdlib/pathlib.jac` on the na pathway, so running one fixture through both
and demanding identical stdout *is* the congruence contract -- CPython is the
oracle, not a hand-copied expectation table.

`pathlib_probe.jac` exercises the whole provided surface: the constructor over
a `str` and over a `Path`, `str()`, f-string interpolation, truthiness,
`.name`, `.stem`, `.parent`, `/`, `.resolve()`, `.exists()` and `.is_dir()`,
including an `obj` carrying a `Path`-typed `has` field with a `Path("")`
default -- the shape `compiler/type_system/types.jac` declares.
"""

import os;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures");

def _sv_run(fixture: str) -> str {
    src = os.path.join(FIXTURES, fixture);
    proc = subprocess.run(
        [sys.executable, "-m", "jaclang", "run", src],
        capture_output=True,
        text=True,
        timeout=900
    );
    assert proc.returncode == 0 , f"sv run failed: {proc.stderr[-800:]
        if proc.stderr
        else '(empty)'}";
    return proc.stdout;
}

def _na_run(fixture: str) -> str {
    src = os.path.join(FIXTURES, fixture);
    out_bin = os.path.join(tempfile.mkdtemp(), "probe.bin");
    comp = subprocess.run(
        [sys.executable, "-m", "jaclang", "nacompile", src, "-o", out_bin],
        capture_output=True,
        text=True,
        timeout=900
    );
    assert comp.returncode == 0 , f"nacompile failed: {comp.stderr[-800:]
        if comp.stderr
        else '(empty)'}";
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

test "a Path member outside the provided surface fails the native compile" {
    src = os.path.join(FIXTURES, "pathlib_unsupported.jac");
    out_bin = os.path.join(tempfile.mkdtemp(), "nope.bin");
    comp = subprocess.run(
        [sys.executable, "-m", "jaclang", "nacompile", src, "-o", out_bin],
        capture_output=True,
        text=True,
        timeout=900
    );
    combined = (comp.stdout or "") + (comp.stderr or "");
    assert comp.returncode != 0 , f"unsupported Path member compiled silently: {combined[-600:]}";
    assert "suffix" in combined , f"diagnostic does not name the member: {combined[-600:]}";
}
