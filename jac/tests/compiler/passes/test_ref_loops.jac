"""Reference-yielding loops over containers (#7857 Phase C).

`for x in &xs` iterates shared per-element borrows and `for m in &mut xs`
iterates exclusive ones -- lowered as index loops with no reified iterator
object, so the loop is the borrow's extent. Element mutation through the
`&mut` form must be visible after the loop, byte-identically under every
gc mode including enforced headerless builds.

The fixture-plus-expected-codes cases for this rule live in the shared
`test_ownership_codes.jac` table; what stays here asserts something that
table cannot express.
"""

import os;
import subprocess;
import sys;
import tempfile;
import from tests.support { TESTS_DIR }

glob FIXTURE = os.path.join(
         TESTS_DIR, "compiler", "passes", "fixtures", "nogc_ownfield", "ref_loop.jac"
     ),
     MODE_FLAGS = {
         "none": ["--memory", "nogc"],
         "rc": ["--memory", "rc"],
         "cycles": ["--memory", "managed"]
     };

test "ref-loop mutation is visible and mode-identical" {
    with tempfile.TemporaryDirectory() as tmp {
        outs: dict[str, str] = {};
        for mode in ("none", "rc", "cycles") {
            out_bin = os.path.join(tmp, f"rl_{mode}");
            res = subprocess.run(
                [sys.executable, "-m", "jaclang", "build", "--native", FIXTURE]
                    + MODE_FLAGS[mode]
                    + ["-o", out_bin],
                capture_output=True,
                text=True
            );
            assert res.returncode == 0 , f"{mode}: {res.stderr}";
            ran = subprocess.run([out_bin], capture_output=True, text=True);
            assert ran.returncode == 0 , f"{mode}: {ran.stderr}";
            outs[mode] = ran.stdout;
        }
        assert outs["rc"] == "3\n4\nend\n" , outs["rc"];
        assert outs["none"] == outs["rc"] , f"none diverged:\n{outs['none']}";
        assert outs["cycles"] == outs["rc"] , f"cycles diverged:\n{outs['cycles']}";
    }
}
