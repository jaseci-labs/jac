"""A value-tuple local owns one reference per managed field it holds.

A local bound to a tuple is a by-value struct slot, and its reference fields
(strings, lists, objects, the heap box of a nested tuple) had no owner: the
assignment neither retained what it borrowed nor recorded what it took over,
and nothing released the fields when the local was overwritten, when a loop
iteration ended or when the function returned. `t = (1, "two", (3, 4))`
stranded the nested tuple's box on every call, and `t = (1, str(i), 3)` the
string.

A tuple local whose every binding is a plain single-name assignment now owns
its fields the way a pointer local owns its referent: the assignment retains
each field it borrowed (keeping the ones the tuple literal already owns),
releases the fields the slot held before, and the scope or loop-iteration
exit releases what the slot holds last. Locals bound any other way -- a loop
target, an unpacking, a closure cell, a generator frame -- keep the old
borrowed treatment, so no binding path releases a reference it never took.

`tuple_slot_shapes.jac` diffs the shapes against the Python backend;
`tuple_slot_leaks.jac` repeats them and dumps the live objects of an RC debug
build, which must hold no leak.
"""

import from tests.support { assert_native_identity, jac_command }

import os;
import subprocess;
import tempfile;
import from pathlib { Path }

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures"),
     PROFILES: list[str] = ["managed", "rc"];

test "tuple locals holding references answer like CPython" {
    assert_native_identity(
        os.path.join(FIXTURES, "tuple_slot_shapes.jac"), profiles=PROFILES
    );
}

test "tuple locals release every field they hold" {
    out_bin = os.path.join(tempfile.mkdtemp(), "probe.bin");
    comp = subprocess.run(
        jac_command(
            "build",
            "--native",
            os.path.join(FIXTURES, "tuple_slot_leaks.jac"),
            "-o",
            out_bin,
            "--debug"
        ),
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
    assert "RC LIVE OBJECTS at exit" in proc.stdout , proc.stdout[-400:];
    leaks = [
        line
        for line in proc.stdout.split("\n")
        if "<- LEAK" in line
    ];
    assert not leaks , f"tuple fields leaked: {len(leaks)} e.g. {leaks[:3]}";
}
