"""`sort(key=)` and `sorted(key=)` compute each key once and merge-sort the positions.

The key sort was a bubble sort that called the key twice per comparison. Now
each element's key is computed once, a stable merge sort orders the positions
by those keys (ties keep their order, `reverse=True` included), and the
elements are rearranged by the sorted positions. The fixture prints what the
Python backend prints under rc and managed, and the sort releases the keys it
was handed.
"""

import os;
import re;
import subprocess;
import tempfile;
import from tests.support { assert_native_identity, jac_command, NATIVE_FIXTURES }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob SORT_FIXTURE: str = os.path.join(NATIVE_FIXTURES, "sort_key.jac");

"""The unoptimized IR of `fixture`."""
def fixture_ir(fixture: str) -> str {
    prog = JacProgram();
    mod = prog.compile(
        file_path=fixture, options=CompileOptions(aot_mode=True, na_gc_mode="rc")
    );
    assert not prog.errors_had , [e.pretty_print() for e in prog.errors_had];
    return str(mod.gen.llvm_ir);
}

"""The body of the function whose name ends in `name`."""
def body_of(text: str, name: str) -> str {
    found = re.search(r'define [^\n]*' + re.escape(name) + r'"?\(.*?\n}\n', text, re.S);
    assert found is not None , f"{name} not found in the IR";
    return found.group(0);
}

test "a key sort computes each key once and merge-sorts positions" {
    run = body_of(fixture_ir(SORT_FIXTURE), ".run");
    assert "ksort.merge.compare" in run;
    assert "sort.inner.body" not in run , "the bubble sort is back";
}

test "the program prints what the Python backend prints under rc and managed" {
    assert_native_identity(SORT_FIXTURE, profiles=["rc", "managed"]);
}

test "a key sort releases the keys it was handed" {
    leak_fixture = os.path.join(NATIVE_FIXTURES, "sort_key_leaks.jac");
    for memory in ["rc", "managed"] {
        with tempfile.TemporaryDirectory() as scratch {
            binary = os.path.join(scratch, "probe");
            comp = subprocess.run(
                jac_command(
                    "build",
                    "--native",
                    leak_fixture,
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
            proc = subprocess.run([binary], capture_output=True, text=True, timeout=120);
            assert proc.returncode == 0 , proc.stderr[-800:];
        }
        assert proc.stdout.splitlines()[0] == "10" , proc.stdout[:400];
        assert "RC LIVE OBJECTS at exit" in proc.stdout , proc.stdout[-400:];
        leaks = [line for line in proc.stdout.splitlines() if "<- LEAK" in line];
        assert not leaks , f"{memory}: {leaks[:5]}";
    }
}
