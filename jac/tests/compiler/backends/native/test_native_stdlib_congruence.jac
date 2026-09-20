"""Stdlib output congruence between Python and native object calls.

The fixtures cover path operations, fnmatch patterns, logging, and contextvars.
Both pathways use the bundled interpreter standard library.
"""

import ctypes;
import from tests.support { jac_command, compile_native, get_func }

import os;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures");

def _sv_run(fixture: str) -> tuple[(str, str)] {
    src = os.path.join(FIXTURES, fixture);
    proc = subprocess.run(
        jac_command("run", src), capture_output=True, text=True, timeout=900
    );
    assert proc.returncode == 0 , f"sv run failed: {proc.stderr[-800:]
        if proc.stderr
        else '(empty)'}";
    return (proc.stdout, proc.stderr);
}

def _na_run(fixture: str) -> tuple[(str, str)] {
    src = os.path.join(FIXTURES, fixture);
    out_bin = os.path.join(tempfile.mkdtemp(), "probe.bin");
    comp = subprocess.run(
        jac_command("build", "--native", src, "-o", out_bin),
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
    return (proc.stdout, proc.stderr);
}

def _same_lines(sv_text: str, na_text: str, what: str) {
    sv = [
        _l
        for _l in sv_text.split("\n")
        if _l.strip()
    ];
    na = [
        _l
        for _l in na_text.split("\n")
        if _l.strip()
    ];
    assert sv , f"{what}: sv pathway produced no output";
    assert len(sv) == len(na) , f"{what} line count: sv {len(sv)} vs na {len(na)}";
    for idx in range(len(sv)) {
        assert sv[idx] == na[idx] , f"{what} line {idx}: sv {sv[idx]!r} vs na {na[
            idx
        ]!r}";
    }
}

test "native os path gaps answer what CPython's os.path answers" {
    (sv_out, _sv_err) = _sv_run("os_gaps_probe.jac");
    (na_out, _na_err) = _na_run("os_gaps_probe.jac");
    _same_lines(sv_out, na_out, "os gaps");
}

test "native fnmatch answers what CPython's fnmatch answers" {
    (sv_out, _sv_err) = _sv_run("fnmatch_probe.jac");
    (na_out, _na_err) = _na_run("fnmatch_probe.jac");
    _same_lines(sv_out, na_out, "fnmatch");
}

"""Keep only the application log records, so a compiler note on stderr cannot
turn a congruence failure into a passing (or spuriously failing) diff."""
def _log_lines(text: str) -> str {
    kept = [
        _l
        for _l in text.split("\n")
        if _l.split(":")[0] in ("DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL")
            or _l.split(" - ")[0] in ("DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL")
    ];
    return "\n".join(kept);
}

test "native logging writes what CPython's logging writes" {
    (_sv_out, sv_err) = _sv_run("logging_probe.jac");
    (_na_out, na_err) = _na_run("logging_probe.jac");
    _same_lines(_log_lines(sv_err), _log_lines(na_err), "logging");
}

test "native contextvars answers what CPython's contextvars answers" {
    (sv_out, _sv_err) = _sv_run("contextvars_probe.jac");
    (na_out, _na_err) = _na_run("contextvars_probe.jac");
    _same_lines(sv_out, na_out, "contextvars");
}

test "a Python ContextVar preserves scalar type arguments and defaults" {
    (engine, _) = compile_native("contextvars_scalar.jac", required=True);
    assert get_func(engine, "scalar_value", ctypes.c_int64)() == 7;
}
