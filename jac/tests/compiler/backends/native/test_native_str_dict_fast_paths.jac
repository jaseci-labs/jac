"""Strings, numbers as text and counting in a dict, through their fast paths.

One-character string comparisons, `str(int)`, an int's repr, f-strings of
plain `{str}`/`{int}` pieces, a float's shortest repr and the
`d[k] = d.get(k, c) op e` counter update all have fast paths. The fixture
prints what the Python backend prints under rc and managed, and an unsigned
counter update adds unsigned.
"""

import os;
import subprocess;
import tempfile;
import from tests.support { assert_native_identity, jac_command, NATIVE_FIXTURES }

glob STR_FIXTURE: str = os.path.join(NATIVE_FIXTURES, "str_dict_fast_paths.jac");

test "the program prints what the Python backend prints under rc and managed" {
    assert_native_identity(STR_FIXTURE, profiles=["rc", "managed"]);
}


test "a single-probe dict update on unsigned values adds unsigned" {
    fixture = os.path.join(NATIVE_FIXTURES, "dict_counter_unsigned.jac");
    with tempfile.TemporaryDirectory() as scratch {
        binary = os.path.join(scratch, "probe");
        comp = subprocess.run(
            jac_command("build", "--native", fixture, "-o", binary),
            capture_output=True,
            text=True,
            timeout=900
        );
        assert comp.returncode == 0 , comp.stderr[-1500:];
        proc = subprocess.run([binary], capture_output=True, text=True, timeout=120);
    }
    assert proc.stdout.splitlines()
        == ["9223372036854775808", "raised OverflowError"] , (
        proc.stdout + proc.stderr[-800:]
    );
}
