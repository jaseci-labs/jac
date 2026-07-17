"""CI guard for Jac CLI startup import budgets.

Delegates to scripts/startup_benchmark.py --check, which warms the Jac cache,
measures import counts via the canonical python -m jaclang probe, and enforces
the embedded lazy-dispatch contract (global paths 0/0/0; command-help ≤4 delta).
"""

import os;
import runpy;
import sys;
import from pathlib { Path }
import from tests.support { JAC_ROOT }

glob REPO: str = str(Path(JAC_ROOT).parent),
     HARNESS: str = str(Path(REPO) / "scripts" / "startup_benchmark.py");


test "startup import budgets" {
    old_argv = list(sys.argv);
    old_cwd = os.getcwd();
    sys.argv = [HARNESS, "--check", "--mode", "dev", "--iterations", "1"];
    os.chdir(REPO);
    try {
        ns = runpy.run_path(HARNESS, run_name="__not_main__");
        rc = ns["main"]();
    } finally {
        sys.argv = old_argv;
        os.chdir(old_cwd);
    }
    assert rc == 0 , "startup import budget check failed";
}
