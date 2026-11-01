"""Fast paths for strings, numbers as text and counting in a dict.

- A comparison against a one-character literal reads the other string's first
  byte instead of a full string compare.
- `str(int)`, an int's repr and f-strings of plain `{str}`/`{int}` pieces
  format digits directly instead of through `vsnprintf`.
- A float's shortest repr takes a direct path for values with up to six
  decimals below 1e15, and otherwise tries 15, 16 and 17 digits instead of
  every precision from one up (subnormals keep the full search).
- `d[k] = d.get(k, c) op e` hashes `k` once and probes once.

The fixture exercises every shape and prints what the Python backend prints
under rc and managed.
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
