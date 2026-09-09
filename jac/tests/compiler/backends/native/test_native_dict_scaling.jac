"""Native dict inserts/lookups are O(1) amortized, not O(n^2).

PR #5174 silently replaced the open-addressing hash-table dict with an O(n)
linear scan, turning any dict-in-a-loop into O(n^2). It passed every existing
test because those check correctness, not scaling. This is the missing
scaling guard: it nacompiles a fixture that fills a dict with N then 2N distinct
string keys (str keys are the case that regressed -- a linear scan does one
strcmp per stored key), times each phase, and asserts the per-insert cost stays
roughly constant when N doubles. A hash table sits near 1x; a linear-scan
O(n^2) dict explodes far past the fixture's generous bound. The assertion lives
inside the fixture, so a regression makes the host binary exit non-zero.
"""

import os;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures"),
     PROG = "dict_hash_scaling.jac";


test "native dict inserts stay O(1) when N doubles (hash-table scaling guard)" {
    src = os.path.join(FIXTURES, PROG);
    out_bin = os.path.join(tempfile.mkdtemp(), "dict_hash_scaling.bin");
    comp = subprocess.run(
        [sys.executable, "-m", "jaclang", "build", "--native", src, "-o", out_bin],
        capture_output=True,
        text=True,
        timeout=300
    );
    combined = (comp.stdout or "") + (comp.stderr or "");
    assert comp.returncode == 0 , f"nacompile failed: {combined[-900:]}";

    proc = subprocess.run([out_bin], capture_output=True, text=True, timeout=120);
    # A non-zero exit is the fixture's internal scaling assertion firing -- i.e.
    # per-insert cost blew up when N doubled (the O(n^2) regression).
    assert proc.returncode == 0 , f"dict scaling regressed: {(
        proc.stderr or proc.stdout or '(empty)'
    )[-500:]}";
    assert proc.stdout.strip() == "OK dict_hash_scaling" , f"unexpected output: {proc.stdout.strip()!r}";
}
