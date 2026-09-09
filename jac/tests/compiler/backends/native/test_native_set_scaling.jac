"""Native set inserts/lookups are O(1) amortized, not O(n^2) (#7871 C).

The pre-hash-core set was a linear-scan container: every add/contains did one
comparison per stored element, turning any set-in-a-loop into O(n^2). Set now
shares the dict's hash core, and this is the scaling guard mirroring the dict
one: it nacompiles a fixture that fills a set with N then 2N distinct string
elements, times each phase, and asserts the per-insert cost stays roughly
constant when N doubles. The assertion lives inside the fixture, so a
regression makes the host binary exit non-zero.
"""

import os;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures"),
     PROG = "set_hash_scaling.jac";


test "native set inserts stay O(1) when N doubles (hash-core scaling guard)" {
    src = os.path.join(FIXTURES, PROG);
    out_bin = os.path.join(tempfile.mkdtemp(), "set_hash_scaling.bin");
    comp = subprocess.run(
        [sys.executable, "-m", "jaclang", "build", "--native", src, "-o", out_bin],
        capture_output=True,
        text=True,
        timeout=300
    );
    combined = (comp.stdout or "") + (comp.stderr or "");
    assert comp.returncode == 0 , f"nacompile failed: {combined[-900:]}";

    proc = subprocess.run([out_bin], capture_output=True, text=True, timeout=120);
    assert proc.returncode == 0 , f"set scaling regressed: {(
        proc.stderr or proc.stdout or '(empty)'
    )[-500:]}";
    assert proc.stdout.strip() == "OK set_hash_scaling" , f"unexpected output: {proc.stdout.strip()!r}";
}
