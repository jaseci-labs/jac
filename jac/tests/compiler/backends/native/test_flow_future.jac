"""General parallel flow calls (#7870 item 4d): the outlining
machinery generalizes from flow for to arbitrary direct calls, with a
heap future record joining at `wait`. Parallel in enforced zero-RC and
atomic-rc builds; cycles, wasm, rc-debug, and any handle whose uses
are not exactly `wait` keep the sequential erasure. The test pins the
program's output across gc modes."""

import os;
import subprocess;
import tempfile;
import from tests.support { jac_command, TESTS_DIR }

glob FIXTURE = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures", "flow_future.jac"
     ),
     EXPECTED = "940251\n6.0\nend\n",
     MODE_FLAGS = {
         "none": ["--memory", "nogc"],
         "rc": ["--memory", "rc"],
         "cycles": ["--memory", "managed"]
     };

test "future output is byte-identical across gc modes" {
    with tempfile.TemporaryDirectory() as tmp {
        for mode in ("none", "rc", "cycles") {
            out_bin = os.path.join(tmp, f"fut_{mode}");
            res = subprocess.run(
                jac_command("build", "--native", FIXTURE)
                    + MODE_FLAGS[mode]
                    + ["-o", out_bin],
                capture_output=True,
                text=True
            );
            assert res.returncode == 0 , f"{mode}: {res.stderr}";
            ran = subprocess.run([out_bin], capture_output=True, text=True);
            assert ran.returncode == 0 , f"{mode}: {ran.stderr}";
            assert ran.stdout == EXPECTED , f"{mode}: {ran.stdout}";
        }
    }
}
