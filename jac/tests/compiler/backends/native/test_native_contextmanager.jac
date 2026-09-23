"""`@contextlib.contextmanager` lowers natively, answering what CPython answers.

The decorated function is compiled as the generator it is, and the `with`
that calls it drives `contextlib`'s protocol: advance to the first `yield`
on entry, advance once more on a normal exit, and on an exception throw it
into the generator at its `yield` -- the frame's pending-exception record,
raised when the generator resumes -- so its `finally` runs and its `except`
can swallow it. Each fixture prints what it observed and the native binary's
output is diffed line-for-line against the Python backend, which runs the
real `contextlib`.

`contextmanager_probe.jac` covers functions and a method whose declaration
carries the decorator in the decl file with the body in an impl annex;
`contextmanager_scopes.jac` is the compiler's own scope shapes over
`ContextVar`. A call to such a function outside a `with` item has no native
manager object, and the last test pins that it is refused naming it.
"""

import from tests.support { jac_command, python_run }

import os;
import subprocess;
import tempfile;
import from pathlib { Path }

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures");

def _native_build(fixture: str) -> tuple[subprocess.CompletedProcess, str] {
    src = os.path.join(FIXTURES, fixture);
    out_bin = os.path.join(tempfile.mkdtemp(), "probe.bin");
    comp = subprocess.run(
        jac_command("build", "--native", src, "-o", out_bin),
        capture_output=True,
        text=True,
        timeout=900
    );
    return (comp, out_bin);
}

def _na_run(fixture: str) -> str {
    (comp, out_bin) = _native_build(fixture);
    assert comp.returncode == 0 , f"nacompile failed: {comp.stderr[-800:]
        if comp.stderr
        else '(empty)'}";
    proc = subprocess.run([out_bin], capture_output=True, text=True, timeout=120);
    assert proc.returncode == 0 , f"binary failed: {proc.stderr[-400:]
        if proc.stderr
        else '(empty)'}";
    return proc.stdout;
}

def _same_lines(py_text: str, na_text: str, what: str) {
    py = [
        _l
        for _l in py_text.split("\n")
        if _l.strip()
    ];
    na = [
        _l
        for _l in na_text.split("\n")
        if _l.strip()
    ];
    assert py , f"{what}: python backend produced no output";
    assert len(py) == len(na) , f"{what} line count: py {len(py)} vs na {len(na)}\npy: {py}\nna: {na}";
    for idx in range(len(py)) {
        assert py[idx] == na[idx] , f"{what} line {idx}: py {py[idx]!r} vs na {na[
            idx
        ]!r}";
    }
}

test "native @contextmanager on functions and an annex method answers like contextlib" {
    py_out = python_run(os.path.join(FIXTURES, "contextmanager_probe.jac"));
    _same_lines(py_out, _na_run("contextmanager_probe.jac"), "contextmanager");
}

test "native ContextVar-backed @contextmanager scopes answer like CPython" {
    py_out = python_run(os.path.join(FIXTURES, "contextmanager_scopes.jac"));
    _same_lines(py_out, _na_run("contextmanager_scopes.jac"), "scopes");
}

test "a @contextmanager call outside a with item is refused, not lowered" {
    (comp, _out_bin) = _native_build("contextmanager_bare_call.jac");
    combined = (comp.stdout or "") + (comp.stderr or "");
    assert comp.returncode != 0 , f"a bare context-manager call compiled silently: {combined[-600:]}";
    assert "@contextmanager scope" in combined , f"diagnostic does not name the function: {combined[-600:]}";
}
