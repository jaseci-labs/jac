"""A copy at a local's last use moves its reference instead of counting it.

`a = b` between locals could move only when every use of `b` was such a
copy. It now moves whenever liveness shows no path reads `b` after the copy,
as long as neither `b` nor the copy sits in a `try` (the statement graph has
no edge from a `try` body to its handlers), a lambda, a comprehension, a
`flow` or a parallel loop, and `b` is never borrowed (`&b`). The
copy then takes `b`'s reference and leaves `b` empty, whether `b`'s slot holds
an object or an optional one; `CompileOptions(na_move_flow=False)` turns the
wider rule off. No copy moves in a function with a `break` the statement graph
leaves without an edge (its loop ends an `if` or loop body).

The program prints what the Python backend prints, and a debug build's
live-object dump holds nothing at exit.
"""

import os;
import subprocess;
import tempfile;
import from tests.support { assert_native_identity, jac_command, NATIVE_FIXTURES }

glob FIXTURE: str = os.path.join(NATIVE_FIXTURES, "move_last_use.jac");

test "the program prints what the Python backend prints under rc and managed" {
    out = assert_native_identity(FIXTURE, profiles=["rc", "managed"]);
    assert out.strip().splitlines() == ["6634", "144"] , out;
}

test "a copy before a break with no edge keeps its source" {
    fixture = os.path.join(NATIVE_FIXTURES, "move_last_use_breaks.jac");
    out = assert_native_identity(fixture, profiles=["rc", "managed"]);
    assert out.strip().splitlines() == ["7 7 8 9", "10 10"] , out;
}

test "moved references are released once" {
    leak_fixture = os.path.join(NATIVE_FIXTURES, "move_last_use_leaks.jac");
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
        assert proc.stdout.splitlines()[0] == "6634" , proc.stdout[:400];
        assert "RC LIVE OBJECTS at exit" in proc.stdout , proc.stdout[-400:];
        leaks = [
            line
            for line in proc.stdout.splitlines()
            if "<- LEAK" in line
        ];
        assert not leaks , f"{memory}: {leaks[:5]}";
    }
}
