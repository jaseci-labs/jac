"""time module cross-backend equivalence fixture (issue #6404, v1).

Wall-clock values are non-deterministic, so each backend computes the SAME
self-contained invariants (positivity, monotonicity, sleep-elapsed) which are
deterministically true on both sv (Python) and na (LLVM). ES/JS opts out.
"""

import time;

def time_py() -> dict {
    t0: float = time.monotonic();
    time.sleep(0.02);
    t1: float = time.monotonic();
    return {
        "time_positive": time.time() > 1700000000.0,
        "time_ns_big": time.time_ns() > 1700000000000000000,
        "mono_ns_pos": time.monotonic_ns() > 0,
        "perf_pos": time.perf_counter() > 0.0,
        "mono_nondecreasing": t1 >= t0,
        "sleep_elapsed": (t1 - t0) >= 0.015,
        "ns_float_agree": abs(time.time_ns() / 1000000000.0 - time.time()) < 5.0,
    };
}

cl def time_cl() -> dict {
    return {};
}

na {
    def time_na() -> dict[str, any] {
        t0: float = time.monotonic();
        time.sleep(0.02);
        t1: float = time.monotonic();
        time_positive: int = time.time() > 1700000000.0;
        time_ns_big: int = time.time_ns() > 1700000000000000000;
        mono_ns_pos: int = time.monotonic_ns() > 0;
        perf_pos: int = time.perf_counter() > 0.0;
        mono_nondecreasing: int = t1 >= t0;
        sleep_elapsed: int = (t1 - t0) >= 0.015;
        diff: float = time.time_ns() / 1000000000.0 - time.time();
        ns_float_agree: int = (diff < 5.0) and (diff > -5.0);
        return {
            "time_positive": time_positive,
            "time_ns_big": time_ns_big,
            "mono_ns_pos": mono_ns_pos,
            "perf_pos": perf_pos,
            "mono_nondecreasing": mono_nondecreasing,
            "sleep_elapsed": sleep_elapsed,
            "ns_float_agree": ns_float_agree,
        };
    }
}
