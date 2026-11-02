"""A method call on a literal receiver evaluates the receiver once.

Method dispatch probed an unknown receiver for a dict type by lowering it, and
lowered it again for the method it found. An f-string or other literal
receiver (`f"x{n}".upper()`) was built twice, running its interpolations
twice and leaking the first copy. Only a variable is probed now.
"""

import os;
import subprocess;
import tempfile;
import from pathlib { Path }
import from tests.support { assert_native_identity, jac_command }

glob FIXTURES: Path = Path(__file__).resolve().parent / "fixtures";

test "a literal receiver runs its interpolations once" {
    out = assert_native_identity(
        str(FIXTURES / "receiver_once.jac"), profiles=["rc", "managed"]
    );
    assert out.strip() == "430050" , out;
}

test "a literal receiver leaves nothing live at exit" {
    for memory in ["rc", "managed"] {
        with tempfile.TemporaryDirectory() as scratch {
            binary = os.path.join(scratch, "probe");
            comp = subprocess.run(
                jac_command(
                    "build",
                    "--native",
                    str(FIXTURES / "receiver_once_leaks.jac"),
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
        assert proc.stdout.splitlines()[0] == "430050" , proc.stdout[:200];
        assert "RC LIVE OBJECTS at exit" in proc.stdout , proc.stdout[-400:];
        leaks = [
            line
            for line in proc.stdout.splitlines()
            if "<- LEAK" in line
        ];
        assert not leaks , f"{memory}: {len(leaks)} leaked, e.g. {leaks[:3]}";
    }
}
