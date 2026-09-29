"""A negated integer literal is a constant, so it narrows like any literal.

`-1` was lowered as a `neg` instruction on an i64 constant, and a C-layout
record field typed i32 with a `-1` default failed native lowering with
"silent narrowing 'i64 into i32'" (the posix fd pair record). The negation
of a literal now folds to a constant of the literal's type. The check runs
the native binary alone: the Python backend's C records take no field
defaults.
"""

import os;
import subprocess;
import tempfile;
import from pathlib { Path }
import from tests.support { jac_command }

glob FIXTURES: Path = Path(__file__).resolve().parent / "fixtures";

test "a sized record field defaults to a negative literal" {
    with tempfile.TemporaryDirectory() as scratch {
        binary = os.path.join(scratch, "probe");
        comp = subprocess.run(
            jac_command(
                "build",
                "--native",
                str(FIXTURES / "clib_negative_field_default.jac"),
                "-o",
                binary
            ),
            capture_output=True,
            text=True,
            timeout=900
        );
        assert comp.returncode == 0 , comp.stderr[-1500:];
        proc = subprocess.run([binary], capture_output=True, text=True, timeout=120);
    }
    assert proc.returncode == 0 , proc.stderr[-800:];
    assert proc.stdout.split("\n")[:3]
        == ["pair -1 -1", "narrow -128 -2 -9223372036854775807", "set 3 -3"] , proc.stdout;
}
