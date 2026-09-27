import from _time_native {
    CLK_MONOTONIC,
    CLK_MONOTONIC_RAW,
    CLK_PROCESS_CPUTIME,
    CLK_REALTIME,
    CLK_THREAD_CPUTIME,
    time_sleep_ns
}
import from _time_common { time_clock_ns, time_clock_seconds, time_clock_set_ns }

glob CLOCK_REALTIME: int = CLK_REALTIME,
     CLOCK_MONOTONIC: int = CLK_MONOTONIC,
     CLOCK_MONOTONIC_RAW: int = CLK_MONOTONIC_RAW,
     CLOCK_PROCESS_CPUTIME_ID: int = CLK_PROCESS_CPUTIME,
     CLOCK_THREAD_CPUTIME_ID: int = CLK_THREAD_CPUTIME;


def:pub time -> float {
    return time_clock_seconds(CLOCK_REALTIME);
}


def:pub time_ns -> int {
    return time_clock_ns(CLOCK_REALTIME);
}


def:pub monotonic -> float {
    return time_clock_seconds(CLOCK_MONOTONIC);
}


def:pub monotonic_ns -> int {
    return time_clock_ns(CLOCK_MONOTONIC);
}


def:pub perf_counter -> float {
    return time_clock_seconds(CLOCK_MONOTONIC);
}


def:pub perf_counter_ns -> int {
    return time_clock_ns(CLOCK_MONOTONIC);
}


def:pub process_time -> float {
    return time_clock_seconds(CLOCK_PROCESS_CPUTIME_ID);
}


def:pub process_time_ns -> int {
    return time_clock_ns(CLOCK_PROCESS_CPUTIME_ID);
}


def:pub thread_time -> float {
    return time_clock_seconds(CLOCK_THREAD_CPUTIME_ID);
}


def:pub thread_time_ns -> int {
    return time_clock_ns(CLOCK_THREAD_CPUTIME_ID);
}


def:pub clock_gettime_ns(clk_id: int) -> int {
    return time_clock_ns(clk_id);
}


def:pub clock_settime_ns(clk_id: int, ns: int) {
    time_clock_set_ns(clk_id, ns);
}


def:pub sleep(secs: float) {
    if secs != secs {
        raise ValueError("Invalid value NaN (not a number)");
    }
    ns: float = secs * 1000000000.0;
    if ns <= -9223372036854775808.0 or ns >= 9223372036854775808.0 {
        raise OverflowError("timestamp out of range for platform time_t");
    }
    if secs < 0.0 {
        raise ValueError("sleep length must be non-negative");
    }
    time_sleep_ns(int(ns));
}
