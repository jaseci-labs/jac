"""Functions that arm setjmp frames are optimized, and stay correct.

A `try`, `finally`, `with` or generator frame arms a setjmp; the raise that
lands in it returns through that setjmp a second time. Those functions used to
be compiled optnone, which kept every local in memory. They are now optimized
like any other, and exactly the locals written after an arming are volatile,
which is what C requires for a value read after the longjmp. The fixture
writes scalars, strings, objects, lists and a closure's cell inside protected
bodies, raises, and reads them in handlers, finally clauses, re-armed loop
iterations and a resumed generator: an optimizer that kept a copy from the
arming prints stale values.
"""

import os;
import subprocess;
import tempfile;
import from pathlib { Path }
import from tests.support { assert_native_identity, jac_command }

glob FIXTURES: Path = Path(__file__).resolve().parent / "fixtures",
     EXPECTED: str = "110 48.0 False 01234|at 4 4 5 5\nfinally saw 3\n-1 calling:caught\n9590\n7 enter,count=5,exit\n[0, 10, 20, 30, 104]\n42\n";

test "optimized setjmp functions read the locals written before the raise" {
    out = assert_native_identity(
        str(FIXTURES / "setjmp_locals.jac"), profiles=["rc", "managed"]
    );
    assert out == EXPECTED , out;
}

test "debug builds agree and leak nothing" {
    for memory in ["rc", "managed"] {
        with tempfile.TemporaryDirectory() as scratch {
            binary = os.path.join(scratch, "probe");
            comp = subprocess.run(
                jac_command(
                    "build",
                    "--native",
                    str(FIXTURES / "setjmp_locals.jac"),
                    "--memory",
                    memory,
                    "--debug",
                    "-o",
                    binary
                ),
                capture_output=True,
                text=True,
                timeout=900
            );
            assert comp.returncode == 0 , comp.stderr[-1500:];
            proc = subprocess.run(
                [binary], capture_output=True, text=True, timeout=120
            );
            assert proc.returncode == 0 , proc.stderr[-800:];
        }
        assert proc.stdout.startswith(EXPECTED) , proc.stdout[-600:];
        leaks = [
            line
            for line in proc.stdout.splitlines()
            if "<- LEAK" in line
        ];
        assert not leaks , f"{memory}: {len(leaks)} leaked, e.g. {leaks[:3]}";
    }
}
