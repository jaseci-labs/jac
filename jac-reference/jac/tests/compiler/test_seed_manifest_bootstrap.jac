"""The declared bootstrap seed set stays honest.

`scripts/check_seed_manifest.py` proves two invariants on plain CPython with
no jaclang importable: every manifest-covered module compiles under the jac0
seed transpiler, and no seed module imports a non-seed jaclang module at
module scope (a hoisted import deadlocks bootstrap). The checker itself must
stay a jaclang-free .py so the proof means something; this test is its suite
home (formerly a ci.yml step), spawning it under the bundled interpreter in
isolated mode so the parent process's jaclang never leaks in.
"""

import os;
import subprocess;
import sys;
import from tests.support { JAC_ROOT }


test "seed manifest compiles under jac0 with no jaclang installed" {
    script = os.path.join(
        os.path.dirname(JAC_ROOT), "scripts", "check_seed_manifest.py"
    );
    if not os.path.isfile(script) {
        testskip("repo checkout only: scripts/check_seed_manifest.py not present");
    }
    proc = subprocess.run(
        [sys.executable, "-I", script], capture_output=True, text=True, timeout=600,
    );
    assert proc.returncode == 0 , (
        f"check_seed_manifest.py failed (exit {proc.returncode}):\n"
        f"{proc.stdout}\n{proc.stderr}"
    );
}
