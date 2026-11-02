glob CLOCK_REALTIME: int = CLK_REALTIME,
     CLOCK_MONOTONIC: int = CLK_MONOTONIC,
     CLOCK_MONOTONIC_RAW: int = CLK_MONOTONIC_RAW,
     CLOCK_PROCESS_CPUTIME_ID: int = CLK_PROCESS_CPUTIME,
     CLOCK_THREAD_CPUTIME_ID: int = CLK_THREAD_CPUTIME;


def:pub time -> float;


def:pub time_ns -> int;


def:pub monotonic -> float;


def:pub monotonic_ns -> int;


def:pub perf_counter -> float;


def:pub perf_counter_ns -> int;


def:pub process_time -> float;


def:pub process_time_ns -> int;


def:pub thread_time -> float;


def:pub thread_time_ns -> int;


def:pub clock_gettime_ns(clk_id: int) -> int;


def:pub clock_settime_ns(clk_id: int, ns: int);


def:pub sleep(secs: float);
