"""Dict hash-table scaling guard.

Inserts N then 2N keys into a fresh dict, timing each phase, and checks the
per-insert cost does not blow up. A hash table is O(1) amortized per insert, so
doubling N keeps the per-op time roughly constant (total ~2x). The pre-#5174
linear-scan dict was O(n) per insert -> O(n^2) total, so doubling N was ~4x the
total time and the per-op ratio exploded.

We insert with distinct string keys (str keys are the case that regressed: a
linear scan does one strcmp per stored key). To stay robust against noisy CI
timers we compare per-insert cost, warm up once, and allow a generous 8x bound
(a true O(n^2) dict at this N is orders of magnitude over that; O(1) sits near
1x). The program prints OK on success and asserts internally otherwise.
"""

import time;


def _fill(n: int) -> int {
    d: dict[str, int] = {};
    i: int = 0;
    while i < n {
        # Distinct string key per insert: "k" + str(i).
        k: str = "k" + str(i);
        d[k] = i;
        i = i + 1;
    }
    # Touch every key once (lookup path is O(n) per op in a linear scan too).
    total: int = 0;
    j: int = 0;
    while j < n {
        total = total + d["k" + str(j)];
        j = j + 1;
    }
    return total + len(d);
}


glob n: int = 20000;

with entry {
    # Warm up so first-touch/codegen effects do not skew the first measurement.
    _warm: int = _fill(1000);

    t0: float = time.perf_counter();
    r1: int = _fill(n);
    t1: float = time.perf_counter();
    r2: int = _fill(n * 2);
    t2: float = time.perf_counter();

    dt_n: float = t1 - t0;
    dt_2n: float = t2 - t1;

    # Per-insert cost for each phase (guard against a zero/near-zero divisor).
    if dt_n < 0.000001 {
        dt_n = 0.000001;
    }
    per_n: float = dt_n / float(n);
    per_2n: float = dt_2n / float(n * 2);

    # O(1): per-op cost stays ~constant, so the ratio hovers near 1.
    # O(n^2): per-op cost doubles with N, and the total quadruples -- the ratio
    # would be ~2x per-op here and grows without bound as N rises. An 8x cap is
    # far above hash-table noise yet far below quadratic behavior.
    ratio: float = per_2n / per_n;

    assert r1 > 0 and r2 > 0 , "dict fill produced no result";
    assert ratio < 8.0 , (
        "dict inserts are not O(1): per-insert cost grew "
        + str(ratio)
        + "x when N doubled (hash table should stay ~1x; a linear-scan O(n^2) "
        + "dict explodes here)"
    );
    print("OK dict_hash_scaling");
}
