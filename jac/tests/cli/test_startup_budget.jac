"""CI guard for Jac CLI startup import budgets.

Delegates to scripts/startup_benchmark.jac --check, which warms the Jac cache,
measures import counts via the canonical python -m jaclang probe, and enforces
the embedded lazy-dispatch contract (global paths 0/0/0; command-help ≤4 delta).
"""

import os;
import subprocess;
import sys;
import from pathlib { Path }
import from tests.support { JAC_ROOT }

glob REPO: str = str(Path(JAC_ROOT).parent),
     HARNESS: str = str(Path(JAC_ROOT).parent / "scripts" / "startup_benchmark.jac");


test "startup import budgets" {
    env = dict(os.environ);
    env["PYTHONPATH"] = JAC_ROOT + os.pathsep + env.get("PYTHONPATH", "");
    proc = subprocess.run(
        [
            sys.executable,
            "-m",
            "jaclang",
            "run",
            HARNESS,
            "--check",
            "--mode",
            "dev",
            "--iterations",
            "1"
        ],
        cwd=REPO,
        env=env,
        capture_output=True,
        text=True
    );
    assert proc.returncode == 0 , (
        f"startup import budget check failed:\n{proc.stdout[-2000:]}\n{proc.stderr[-1000:]}"
    );
}
