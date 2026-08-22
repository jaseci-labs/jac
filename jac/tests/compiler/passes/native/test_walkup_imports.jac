"""A native AOT build resolves a dotted walk-up import whose target then
imports a sibling relatively (`import from .leaf`). Pins the boundary-fact
rule that a dependency compiled under the native default codespace carries
native intent for its own imports, so sibling resolution runs even before the
module's codespace is decided."""

import os;
import subprocess;
import sys;
import tempfile;

glob FIXTURE: str = os.path.abspath(
         os.path.join(
             os.path.dirname(os.path.abspath(__file__)),
             "..",
             "..",
             "..",
             "..",
             "jaclang",
             "compiler",
             "tests",
             "fixtures",
             "prim_walkup_transitive.jac"
         )
     );

test "dotted walk-up import then a relative sibling import lowers natively" {
    with tempfile.TemporaryDirectory() as tmp {
        out_bin = os.path.join(tmp, "walkup");
        res = subprocess.run(
            [sys.executable, "-m", "jaclang", "nacompile", FIXTURE, "-o", out_bin],
            capture_output=True,
            text=True
        );
        assert res.returncode == 0 , res.stderr;
        assert "demoting" not in res.stderr , res.stderr;
        ran = subprocess.run([out_bin], capture_output=True, text=True);
        assert ran.returncode == 0 , ran.stderr;
        assert ran.stdout == "mid(leaf:7)\n" , ran.stdout;
    }
}
