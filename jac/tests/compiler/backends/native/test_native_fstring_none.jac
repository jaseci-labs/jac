"""An f-string segment must not hand a null pointer to printf.

A bare `None` interpolated into an f-string lowered to a null `i8*` and
went straight into the `%s` slot, so `f"{n}"` printed `(null)` — and, %s
with a null argument being undefined behavior, could crash. `print(None)`
and `str(None)` were guarded (#9349); the f-string path was not, so the
same value rendered differently through each door.
"""

import os;
import subprocess;
import tempfile;
import from tests.support { jac_command, NATIVE_FIXTURES }

glob NONE_FIXTURE = os.path.join(NATIVE_FIXTURES, "fstring_none.jac");


def _build_and_run(name: str) -> str {
    with tempfile.TemporaryDirectory() as tmp {
        out_bin = os.path.join(tmp, name);
        built = subprocess.run(
            jac_command("build", "--native", NONE_FIXTURE) + ["-o", out_bin],
            capture_output=True,
            text=True
        );
        assert built.returncode == 0 , f"{name}: build failed: {built.stderr}";
        assert "demoting run_cases" not in built.stdout + built.stderr , (
            f"{name}: the fixture must lower natively, not demote"
        );
        ran = subprocess.run([out_bin], capture_output=True, text=True);
        assert ran.returncode == 0 , (
            f"{name}: exited {ran.returncode} (139 is the null-pointer "
            f"segfault this guards): {ran.stderr}"
        );
        return ran.stdout;
    }
}


test "a None segment renders None, not (null)" {
    got = _build_and_run("fstring_none");
    assert got
        == (
            "start\n"
            "None\n"  # f"{n}"
            "xNoney\n"  # f"x{n}y"
            "None\n"  # f"{n!r}" — repr(None), not repr("None")
            "  None\n"  # f"{None!r:>6}" — the spec pads the repr, not the pointer
            "None\n"  # f"{None}"
            "  None\n"  # f"{None:>6}" — the spec path pads the string, not the pointer
            "None\n"  # f"{s}", str | None — unchanged by the fix
            "None\n"  # f"{n!s}" — str(None), the same door as the plain path
            "  None\n"  # f"{None!s:>6}"
            "u\n"  # f"{q and 'u'}", q truthy — the and result is not clobbered
            "None\n"  # f"{n and 'u'}" — a runtime-null str phi, not (null)
            "None\n"  # owned runtime-null string from an inner f-string
            "  None|\n"  # f"{(n and 'u'):>6}|" — the spec pads the None text
            "end\n"
        ) , got;
}
