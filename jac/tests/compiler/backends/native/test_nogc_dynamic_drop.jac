"""A headerless drop of an own reference runs the dynamic type's drop.

Under nogc an object is dropped by the static type of the reference that
owns it. A reference typed as a base that holds a subclass instance ran the
base's drop: the subclass's `drop` hook never ran and its extra owned fields
leaked, whether the reference was a replaced field, a local at the end of
its scope, or a list element. A class with a vtable now carries its exact
drop body in a vtable slot, and a drop through a reference to any class that
is not provably final dispatches through it.

`dyn_drop_main.jac` declares the subclass in a module the base never sees
and exercises field replacement, scope end and a list's element drops; its
output must match the reference-counted profiles and the Python backend,
and the headerless binary must leak nothing.
"""

import os;
import shutil;
import subprocess;
import tempfile;
import from pathlib { Path }
import from tests.support { assert_native_identity, native_build }

glob FIXTURE: str = str(
         Path(__file__).resolve().parent
             / "fixtures"
             / "nogc_identity"
             / "dyn_drop_main.jac"
     );

test "own references typed as a base drop the subclass they hold" {
    out = assert_native_identity(FIXTURE);
    assert out.splitlines()[:6]
        == [
            "drop resource empty",
            "slot size 3",
            "drop buffer b1 3",
            "drop payload p1",
            "replaced",
            "drop resource plain"
        ] , out;
    assert "drop buffer b3 2\ndrop payload p3" in out , out;
}

test "the headerless dynamic drop leaks nothing" {
    if not shutil.which("leaks") {
        testskip("the macOS leaks tool is not available");
    }
    out_bin = os.path.join(tempfile.mkdtemp(), "dyn_drop.nogc");
    native_build(FIXTURE, out_bin, memory="nogc");
    lk = subprocess.run(
        ["leaks", "--atExit", "--", out_bin],
        capture_output=True,
        text=True,
        timeout=300
    );
    assert "0 leaks for 0 total leaked bytes" in lk.stdout , lk.stdout[-2000:];
}
