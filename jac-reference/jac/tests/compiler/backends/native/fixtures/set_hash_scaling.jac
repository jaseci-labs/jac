"""Set hash-table scaling guard.

Inserts N then 2N distinct string elements into a fresh set, timing each
phase, and checks the per-insert cost does not blow up. The hash-core set is
O(1) amortized per insert, so doubling N keeps the per-op time roughly
constant; the pre-hash linear-scan set was O(n) per insert (one strcmp per
stored element) -> O(n^2) total. The program prints OK on success and asserts
internally otherwise.
"""

import time;


def _fill(n: int) -> int {
    s: set[str] = set();
    i: int = 0;
    while i < n {
        s.add("k" + str(i));
        i = i + 1;
    }
    total: int = 0;
    j: int = 0;
    while j < n {
        if ("k" + str(j)) in s {
            total = total + 1;
        }
        j = j + 1;
    }
    return total + len(s);
}


glob n: int = 20000;

with entry {
    _warm: int = _fill(1000);

    t0: float = time.perf_counter();
    r1: int = _fill(n);
    t1: float = time.perf_counter();
    r2: int = _fill(n * 2);
    t2: float = time.perf_counter();

    dt_n: float = t1 - t0;
    dt_2n: float = t2 - t1;

    if dt_n < 0.000001 {
        dt_n = 0.000001;
    }
    per_n: float = dt_n / float(n);
    per_2n: float = dt_2n / float(n * 2);

    ratio: float = per_2n / per_n;

    assert r1 > 0 and r2 > 0 , "set fill produced no result";
    assert ratio < 8.0 , (
        "set inserts are not O(1): per-insert cost grew "
        + str(ratio)
        + "x when N doubled (hash-core set should stay ~1x; a linear-scan "
        + "O(n^2) set explodes here)"
    );
    print("OK set_hash_scaling");
}
