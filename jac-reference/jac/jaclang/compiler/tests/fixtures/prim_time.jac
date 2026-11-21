"""time module cross-backend equivalence fixture (issue #6404, v1).

Wall-clock values are non-deterministic, so each backend computes the SAME
self-contained invariants (positivity, monotonicity, sleep-elapsed) which are
deterministically true on both sv (Python) and na (LLVM). ES/JS opts out.
"""

import time;
import from time { perf_counter_ns }


def time_py -> dict[any, any] {
    time.sleep(0);
    t0: float = time.monotonic();
    time.sleep(0.02);
    t1: float = time.monotonic();
    p0: int = time.process_time_ns();
    p1: int = time.process_time_ns();
    neg: str = "no-raise";
    try {
        time.sleep(-1.0);
    } except ValueError as e {
        neg = "ValueError: " + str(e);
    } except Exception as e {
        neg = "WRONG-TYPE: " + str(e);
    }
    nan_e: str = "no-raise";
    try {
        time.sleep(float("nan"));
    } except ValueError as e {
        nan_e = "ValueError: " + str(e);
    } except Exception as e {
        nan_e = "WRONG-TYPE: " + str(e);
    }
    inf_e: str = "no-raise";
    try {
        time.sleep(float("inf"));
    } except OverflowError {
        # str(e) is CPython-build-dependent ("platform time_t" vs "C PyTime_t");
        # the except arm itself proves the type, so pin that only.
        inf_e = "OverflowError";
    } except Exception as e {
        inf_e = "WRONG-TYPE: " + str(e);
    }
    cgt_e: str = "no-raise";
    try {
        time.clock_gettime_ns(99999);
    } except OSError as e {
        cgt_e = "OSError: " + str(e);
    } except Exception as e {
        cgt_e = "WRONG-TYPE: " + str(e);
    }
    return {
        "time_positive": time.time() > 1700000000.0,
        "time_ns_big": time.time_ns() > 1700000000000000000,
        "mono_ns_pos": time.monotonic_ns() > 0,
        "perf_pos": time.perf_counter() > 0.0,
        "perf_from_ns": perf_counter_ns() > 0,
        "mono_nondecreasing": t1 >= t0,
        "sleep_elapsed": (t1 - t0) >= 0.015,
        "ns_float_agree": abs(time.time_ns() / 1000000000.0 - time.time()) < 5.0,
        "proc_ns_nonneg": p0 >= 0,
        "proc_nondecreasing": p1 >= p0,
        "thread_ns_nonneg": time.thread_time_ns() >= 0,
        "thread_pos": time.thread_time() >= 0.0,
        "cgt_ns_big": time.clock_gettime_ns(time.CLOCK_REALTIME) > 1700000000000000000,
        "cgt_mono_agree": abs(
            time.clock_gettime_ns(time.CLOCK_MONOTONIC) - time.monotonic_ns()
        )
            < 5000000000,
        "clk_ids_nonneg": time.CLOCK_REALTIME >= 0
            and time.CLOCK_MONOTONIC >= 0
            and time.CLOCK_PROCESS_CPUTIME_ID >= 0
            and time.CLOCK_THREAD_CPUTIME_ID >= 0,
        "sleep_neg": neg,
        "sleep_nan": nan_e,
        "sleep_inf": inf_e,
        "cgt_bad": cgt_e,

    };
}

def time_cl -> dict[any, any] {
    return {};
}


def time_na -> dict[str, any] {
    time.sleep(0);
    t0: float = time.monotonic();
    time.sleep(0.02);
    t1: float = time.monotonic();
    p0: int = time.process_time_ns();
    p1: int = time.process_time_ns();
    neg: str = "no-raise";
    try {
        time.sleep(-1.0);
    } except ValueError as e {
        neg = "ValueError: " + str(e);
    } except Exception as e {
        neg = "WRONG-TYPE: " + str(e);
    }
    nan_e: str = "no-raise";
    try {
        time.sleep(float("nan"));
    } except ValueError as e {
        nan_e = "ValueError: " + str(e);
    } except Exception as e {
        nan_e = "WRONG-TYPE: " + str(e);
    }
    inf_e: str = "no-raise";
    try {
        time.sleep(float("inf"));
    } except OverflowError {
        # str(e) is CPython-build-dependent ("platform time_t" vs "C PyTime_t");
        # the except arm itself proves the type, so pin that only.
        inf_e = "OverflowError";
    } except Exception as e {
        inf_e = "WRONG-TYPE: " + str(e);
    }
    cgt_e: str = "no-raise";
    try {
        time.clock_gettime_ns(99999);
    } except OSError as e {
        cgt_e = "OSError: " + str(e);
    } except Exception as e {
        cgt_e = "WRONG-TYPE: " + str(e);
    }
    cgt_diff: int = time.clock_gettime_ns(time.CLOCK_MONOTONIC) - time.monotonic_ns();
    return {
        "time_positive": 1 if time.time() > 1700000000.0 else 0,
        "time_ns_big": 1 if time.time_ns() > 1700000000000000000 else 0,
        "mono_ns_pos": 1 if time.monotonic_ns() > 0 else 0,
        "perf_pos": 1 if time.perf_counter() > 0.0 else 0,
        "perf_from_ns": 1 if perf_counter_ns() > 0 else 0,
        "mono_nondecreasing": 1 if t1 >= t0 else 0,
        "sleep_elapsed": 1 if (t1 - t0) >= 0.015 else 0,
        "ns_float_agree": 1
            if abs(time.time_ns() / 1000000000.0 - time.time()) < 5.0
            else 0,
        "proc_ns_nonneg": 1 if p0 >= 0 else 0,
        "proc_nondecreasing": 1 if p1 >= p0 else 0,
        "thread_ns_nonneg": 1 if time.thread_time_ns() >= 0 else 0,
        "thread_pos": 1 if time.thread_time() >= 0.0 else 0,
        "cgt_ns_big": 1
            if time.clock_gettime_ns(time.CLOCK_REALTIME) > 1700000000000000000
            else 0,
        "cgt_mono_agree": 1
            if (cgt_diff < 5000000000) and (cgt_diff > -5000000000)
            else 0,
        "clk_ids_nonneg": 1
            if time.CLOCK_REALTIME >= 0
                and time.CLOCK_MONOTONIC >= 0
                and time.CLOCK_PROCESS_CPUTIME_ID >= 0
                and time.CLOCK_THREAD_CPUTIME_ID >= 0
            else 0,
        "sleep_neg": neg,
        "sleep_nan": nan_e,
        "sleep_inf": inf_e,
        "cgt_bad": cgt_e,

    };
}
