"""flow for runtime semantics (#7857 Phase C/D surface).

Per-element body over lent collections with the join at the closing
brace: element writes through `&mut` are visible after the join, and the
join is a real barrier -- every line one region prints lands before the
next region starts.

The body is *not* sequential any more. `_try_flow_for_parallel` outlines
it and fans element ranges over pthreads for `--memory rc` (and for `--gc
none` under nogc enforcement), so the order of prints *within* one
region is unspecified by design -- see the `flow for` contract in
docs/reference/language/ownership-borrowing.md, which promises
deterministic post-join state, not an ordering of side effects raised
from the body. What every gc mode must agree on is the region
structure: the same lines, in the same regions, in region order. The
fixture's two printing regions emit disjoint value sets, so a line that
escaped its region would show up as a region mismatch.
"""

import os;
import subprocess;
import sys;
import tempfile;
import from tests.support { TESTS_DIR }

glob FIXTURE = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures", "flow_for_run.jac"
     ),
     REGIONS: list[list[str]] = [["10", "20", "30"], ["12", "15"], ["end"]],
     REPEATS = 25,
     MODE_FLAGS = {
         "none": ["--memory", "nogc"],
         "rc": ["--memory", "rc"],
         "cycles": ["--memory", "managed"]
     };

def _regions(out: str) -> list[list[str]] {
    lines = out.split("\n");
    if not lines or lines[-1] != "" {
        return [];
    }
    lines = lines[:-1];
    got: list[list[str]] = [];
    at = 0;
    for want in REGIONS {
        got.append(sorted(lines[at:at + len(want)]));
        at += len(want);
    }
    if at != len(lines) {
        return [];
    }
    return got;
}

test "flow for output agrees region by region across gc modes" {
    with tempfile.TemporaryDirectory() as tmp {
        expected = [sorted(region) for region in REGIONS];
        for mode in ("none", "rc", "cycles") {
            out_bin = os.path.join(tmp, f"ff_{mode}");
            res = subprocess.run(
                [sys.executable, "-m", "jaclang", "build", "--native", FIXTURE]
                    + MODE_FLAGS[mode]
                    + ["-o", out_bin],
                capture_output=True,
                text=True
            );
            assert res.returncode == 0 , f"{mode}: {res.stderr}";
            for _ in range(REPEATS) {
                ran = subprocess.run([out_bin], capture_output=True, text=True);
                assert ran.returncode == 0 , f"{mode}: {ran.stderr}";
                assert _regions(ran.stdout) == expected , f"{mode}: {ran.stdout}";
            }
        }
    }
}
