"""`TypeGuard[T]` and `TypeIs[T]` are ambient, and the native lane lowers them.

Both guard PEPs say a predicate returns a bool and the guarded type is a claim
about the *argument*, so `FunctionType.type_guard` carries the claim and every
consumer downstream should go on seeing an ordinary bool. The native lane was
the consumer that did not: a `TypeGuard[...]` in return position reached
`_lower_class_type` as a special form with no lowering and failed `E5092`,
which is why `UniScopeNode.is_python_scoping` kept a hand-written `bool`
annotation rather than the accurate guard form.

The fixture imports nothing. Both names reach it through `typing_ambient.pyi`,
which is the other half: typeshed declares `TypeGuard` under
`if sys.version_info >= (3, 10)` and `TypeIs` under `>= (3, 13)`, and the
ambient installer used to read the typing module's own scope dict, which never
descends into a version guard's live branch, so both were dropped without a
word. The installer now resolves through `lookup_symtab`, which walks the live
branch against the CPython 3.14 the `jac` binary bundles.

The two forms differ in what they claim, and the fixture holds them apart:
`TypeIs` narrows both edges, `TypeGuard` only the positive one.

Running the one fixture through both pathways and demanding identical stdout is
the contract: CPython narrows, so the native binary must narrow the same way.
"""

import os;
import subprocess;
import sys;
import tempfile;
import from tests.support { TESTS_DIR }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     );

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

test "ambient type guards narrow identically on both pathways" {
    sv = [
        _l
        for _l in _sv_run("type_guard_probe.jac").split("\n")
        if _l.strip()
    ];
    na = [
        _l
        for _l in _na_run("type_guard_probe.jac").split("\n")
        if _l.strip()
    ];
    assert sv , "sv pathway produced no output";
    assert len(sv) == len(na) , f"line count: sv {len(sv)} vs na {len(na)}";
    for idx in range(len(sv)) {
        assert sv[idx] == na[idx] , f"line {idx}: sv {sv[idx]!r} vs na {na[idx]!r}";
    }
}
