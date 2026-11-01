"""`sort(key=)` and `sorted(key=)` compute each key once and merge-sort the positions.

The key sort was a bubble sort that called the key twice per comparison. Now
each element's key is computed once, a stable merge sort orders the positions
by those keys (ties keep their order, `reverse=True` included), and the
elements are rearranged by the sorted positions. The fixture prints what the
Python backend prints under rc and managed, and the sort releases the keys it
was handed.
"""

import os;
import subprocess;
import tempfile;
import from tests.support { assert_native_identity, jac_command, NATIVE_FIXTURES }

glob SORT_FIXTURE: str = os.path.join(NATIVE_FIXTURES, "sort_key.jac");

test "the program prints what the Python backend prints under rc and managed" {
    out = assert_native_identity(SORT_FIXTURE, profiles=["rc", "managed"]);
    lines = out.splitlines();
    assert "sorted calls [5, 3, 9, 1, 7, 2] -> [3, 9, 1, 7, 5, 2]" in lines , (
        "sorted(key=) must call the key once per element, in element order: " + out
    );
    assert "sort calls [5, 3, 9, 1, 7, 2] -> [5, 2, 1, 7, 3, 9]" in lines , (
        "list.sort(key=) must call the key once per element, in element order: " + out
    );
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
            proc = subprocess.run(
                [binary], capture_output=True, text=True, timeout=120
            );
            assert proc.returncode == 0 , proc.stderr[-800:];
        }
        assert proc.stdout.splitlines()[0] == "10" , proc.stdout[:400];
        assert "RC LIVE OBJECTS at exit" in proc.stdout , proc.stdout[-400:];
        leaks = [
            line
            for line in proc.stdout.splitlines()
            if "<- LEAK" in line
        ];
        assert not leaks , f"{memory}: {leaks[:5]}";
    }
}
