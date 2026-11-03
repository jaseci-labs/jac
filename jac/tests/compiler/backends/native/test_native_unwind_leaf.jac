"""A raise crossing frames that own rc locals releases them exactly once.

The fixture agrees with the Python backend, and a debug build's live-object
dump holds nothing at exit but the global table.
"""

import os;
import subprocess;
import tempfile;
import from tests.support { assert_native_identity, jac_command, NATIVE_FIXTURES }

glob FIXTURE: str = os.path.join(NATIVE_FIXTURES, "unwind_leaf.jac"),
     DROP_RAISE: str = os.path.join(NATIVE_FIXTURES, "unwind_drop_raise.jac");

test "the program prints what the Python backend prints under rc and managed" {
    out = assert_native_identity(FIXTURE, profiles=["rc", "managed"]);
    assert out.splitlines()[0] == "24080 280" , out;
}

test "an exception a drop raises is ignored, as Python ignores it" {
    # releases are calls that cannot raise, so a frame keeps no record across
    # them; the drop's exception must not cross the frame that released it
    out = assert_native_identity(DROP_RAISE, profiles=["rc", "managed"]);
    assert out == "18 ['kept 0', 'kept 1', 'kept 2']\n" , out;
}

test "raises from frames without a record leak nothing" {
    leak_fixture = os.path.join(NATIVE_FIXTURES, "unwind_leaf_leaks.jac");
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
        assert proc.stdout.splitlines()[0] == "24080280" , proc.stdout[:400];
        assert "RC LIVE OBJECTS at exit" in proc.stdout , proc.stdout[-400:];
        leaks = [
            line
            for line in proc.stdout.splitlines()
            if "<- LEAK" in line
        ];
        assert leaks == [] , f"{memory}: {leaks[:5]}";
    }
}
