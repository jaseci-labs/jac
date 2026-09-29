"""Regression guard for jaseci-labs/jac#9487.

The deleted native time intercept emitted its timespec alloca at the call
site; inside a loop each iteration burned 16 bytes of stack, so ~524288 calls
overflowed the default 8MiB stack (SIGSEGV). `__alloca` positions the
allocation in the function entry block, so the bundled na_stdlib time module
and direct `__alloca` callers iterate arbitrarily. The fixture is built and
run as a subprocess so a regression crashes the child with a clean
non-zero-exit failure instead of taking down the test runner.
"""

import os;
import shutil;
import subprocess;
import tempfile;
import from pathlib { Path }
import from tests.support { jac_command }

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures");

test "entry-block alloca survives more loop iterations than 8MiB of stack" {
    with tempfile.TemporaryDirectory() as tmp {
        src = os.path.join(tmp, "alloca_hoist.jac");
        shutil.copyfile(os.path.join(FIXTURES, "alloca_hoist.jac"), src);
        out_bin = os.path.join(tmp, "alloca_hoist");
        comp = subprocess.run(
            jac_command("build", "--native", src, "-o", out_bin),
            capture_output=True,
            text=True,
            timeout=900
        );
        assert comp.returncode == 0 , (
            f"jac build --native failed: exit={comp.returncode}\n"
            f"stderr: {comp.stderr[-800:] if comp.stderr else '(empty)'}"
        );
        proc = subprocess.run([out_bin], capture_output=True, text=True, timeout=120);
        assert proc.returncode == 0 , (
            f"binary exited {proc.returncode} - a signal here means the alloca "
            "was emitted inside the loop again (#9487).\n"
            f"stderr: {proc.stderr[-800:] if proc.stderr else '(empty)'}"
        );
        assert "done" in proc.stdout , (
            f"fixture did not finish: stdout={proc.stdout[:200]}"
        );
    }
}
