"""The bundled `fnmatch` / `logging` shims and the `os` gaps must answer what
CPython answers.

`import from fnmatch {...}` binds CPython's module on the sv pathway and
`na_stdlib/fnmatch.jac` on the na pathway, so running one fixture through both
and demanding identical output *is* the congruence contract -- CPython is the
oracle, not a hand-copied expectation table. Same for `logging`.

`fnmatch_probe.jac` walks a 29-pattern by 14-name grid through both
`fnmatchcase` and `fnmatch`, covering the metacharacters (`*`, `?`), character
classes with negation and ranges, and every awkward bracket case CPython's
`translate` special-cases: a `]` first in the class, an unterminated `[` that
falls back to a literal, `[!]`, and a `-` at either end of a class.

`os_gaps_probe.jac` covers the members the audit found missing: `os.sep` and
its sibling module attributes, which had no dispatch at all (only `sys.*` and
`math.*` resolved as module attributes); the `relpath` / `normcase` added to
the bundled `os/path.jac`; the `abspath` / `splitext` / `normpath` that were
already written there; and the `getmtime` / `normcase` intrinsics now
reachable through the flat `import os`. The mtime is pinned with `touch -t`
-- POSIX, so it behaves the same under GNU and BSD touch -- which makes both
runs read one stamp; the absolute value is irrelevant, only that the two
pathways agree on it.

`logging_probe.jac` writes on stderr, where CPython's default handler writes,
and pins the parts of the surface that are congruent: the default WARNING
threshold suppressing `.debug`/`.info`, `basicConfig` lowering it, the
`%(levelname)s`/`%(name)s`/`%(message)s` format fields, and `getLogger()`
answering to the name `root`.

`contextvars_probe.jac` runs one `ContextVar[Req]` through the whole
precedence ladder `get` implements -- a set value, then the call's own
default, then the constructor default, then `LookupError` -- so the sv run
answers out of CPython's own `contextvars` and the na run out of the bundled
shim. The type argument is an archetype because a generic archetype is
type-erased natively: `ContextVar[int]` is refused rather than lowered
(#8229), and the last test pins that refusal, since it is the shim's scope
line rather than a defect.
"""

import os;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures");

def _sv_run(fixture: str) -> tuple[(str, str)] {
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
    return (proc.stdout, proc.stderr);
}

def _na_run(fixture: str) -> tuple[(str, str)] {
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

"""Keep only the shim's own records, so a compiler note on stderr cannot
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

test "a ContextVar at a scalar type argument is refused, not lowered" {
    src = os.path.join(FIXTURES, "contextvars_unsupported.jac");
    out_bin = os.path.join(tempfile.mkdtemp(), "nope.bin");
    comp = subprocess.run(
        [sys.executable, "-m", "jaclang", "nacompile", src, "-o", out_bin],
        capture_output=True,
        text=True,
        timeout=900
    );
    combined = (comp.stdout or "") + (comp.stderr or "");
    assert comp.returncode != 0 , f"an erased scalar slot compiled silently: {combined[-600:]}";
    assert "ContextVar[int]" in combined , f"diagnostic does not name the instantiation: {combined[-600:]}";
}
