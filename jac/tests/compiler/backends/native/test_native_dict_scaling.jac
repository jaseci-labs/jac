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
import ctypes;
import time;
import from tests.support { compile_native, get_func }

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

test "native dict deletion scales linearly in both insertion orders" {
    (eng, _) = compile_native("dict_delete_scaling.jac");
    erase = get_func(eng, "erase_keys", ctypes.c_int64, ctypes.c_int64, ctypes.c_bool);
    for reverse in [False, True] {
        assert erase(1000, reverse) == 499500;
        timings: list[float] = [];
        for n in [32000, 128000] {
            samples: list[float] = [];
            for trial in range(3) {
                started = time.process_time();
                result = erase(n, reverse);
                samples.append(time.process_time() - started);
                assert result == n * (n - 1) // 2;
            }
            timings.append(sorted(samples)[1]);
        }
        assert timings[1] < timings[0] * 8.0 + 0.02 , (
            f"native dict deletion is quadratic (reverse={reverse}): "
            f"32k={timings[0]:.3f}s, 128k={timings[1]:.3f}s"
        );
    }
}
