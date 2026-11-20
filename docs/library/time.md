---
description: The native time module, as CPython's time - its clocks, sleep, struct_time, the conversions between seconds and calendar time, strftime and strptime, and the local time zone.
keywords: time, time.time, time.time_ns, time.monotonic, time.monotonic_ns, time.perf_counter, time.perf_counter_ns, time.process_time, time.process_time_ns, time.thread_time, time.thread_time_ns, time.clock_gettime, time.clock_gettime_ns, time.clock_settime, time.clock_settime_ns, time.clock_getres, time.get_clock_info, time.sleep, time.gmtime, time.localtime, time.mktime, time.asctime, time.ctime, time.strftime, time.strptime, time.struct_time, time.timezone, time.altzone, time.daylight, time.tzname, time.tzset, time.CLOCK_REALTIME, time.CLOCK_MONOTONIC
---
# time

`time` is CPython's `time`: the clocks and `sleep`, each read from the operating system's own
clock, and the calendar half, `struct_time`, `gmtime`, `localtime`, `mktime`, `strftime`,
`strptime` and the local time zone, with CPython's results, exceptions and messages. It is native
(see [The library](index.md), `jac docs library`). For dates as objects, see
[`datetime`](datetime.md).

```jac
import time;

with entry {
    t = time.gmtime(0);
    print(t);
    print(t.tm_year, t[0], time.strftime("%Y-%m-%d %H:%M:%S", t), time.asctime(t));
    p = time.strptime("2026-11-13 08:30", "%Y-%m-%d %H:%M");
    print(p.tm_yday, p.tm_wday, time.mktime(time.localtime(1000000)) == 1000000.0);
    print(time.get_clock_info("monotonic").monotonic);
    start = time.monotonic();
    time.sleep(0.01);
    print(time.monotonic() - start >= 0.01, type(time.time_ns()).__name__);
    try {
        time.sleep(-1.0);
    } except ValueError as e {
        print("ValueError:", e);
    }
}
```

```output
time.struct_time(tm_year=1970, tm_mon=1, tm_mday=1, tm_hour=0, tm_min=0, tm_sec=0, tm_wday=3, tm_yday=1, tm_isdst=0)
1970 1970 1970-01-01 00:00:00 Thu Jan  1 00:00:00 1970
317 4 True
True
True int
ValueError: sleep length must be non-negative
```

## What is there

| Name | What it gives |
|---|---|
| `time()`, `time_ns()` | Seconds (a float) or nanoseconds (an int) since the epoch, from the wall clock |
| `monotonic()`, `monotonic_ns()` | A clock that never goes back, for measuring intervals |
| `perf_counter()`, `perf_counter_ns()` | The clock with the highest resolution, for timing code |
| `process_time()`, `process_time_ns()` | The CPU time of the process |
| `thread_time()`, `thread_time_ns()` | The CPU time of the calling thread |
| `clock_gettime(clock)`, `clock_gettime_ns`, `clock_settime`, `clock_settime_ns`, `clock_getres` | A clock by its id; `CLOCK_REALTIME`, `CLOCK_MONOTONIC` and the rest have the target's values |
| `get_clock_info(name)` | The implementation, resolution and whether it is monotonic and adjustable, of `"time"`, `"monotonic"`, `"perf_counter"`, `"process_time"` or `"thread_time"` |
| `sleep(secs)` | Suspends the calling thread; `secs` may be a float or an int, and a negative one raises `ValueError` |
| `struct_time` | Calendar time as nine fields (`tm_year` to `tm_isdst`) and `tm_zone`, `tm_gmtoff`; indexed and unpacked as a tuple |
| `gmtime(secs=None)`, `localtime(secs=None)` | Seconds since the epoch as a `struct_time`, in UTC or in the local zone |
| `mktime(t)` | The inverse of `localtime` |
| `asctime(t=None)`, `ctime(secs=None)` | The 24-character form, `Thu Jan  1 00:00:00 1970` |
| `strftime(format, t=None)`, `strptime(string, format="%a %b %d %H:%M:%S %Y")` | Formatting and parsing by the C library's directives; `strptime` is CPython's `_strptime`, in the C locale |
| `timezone`, `altzone`, `daylight`, `tzname`, `tzset()` | The local time zone, read from `TZ` and the system's zone database; `tzset` reads them again |

As in CPython: `strptime` of text that does not match raises
`ValueError: time data '2026-13-01' does not match format '%Y-%m-%d'`; `gmtime(1e20)` raises
`OverflowError: timestamp out of range for platform time_t`; `gmtime(86400).tm_zone` is `GMT`.

## Platforms

`tzname`, `timezone` and `localtime` come from the operating system's local zone: `TZ` and
`/etc/localtime` on Linux and macOS, the system's settings on Windows. WASI has no zone database:
local time is UTC there (`tzname` is `('UTC', 'UTC')`, `timezone` 0), and `tzset` changes nothing.
`pthread_getcpuclockid` and `CLOCK_BOOTTIME` (Linux) exist where CPython has them on that platform,
and a program that names one where it is absent does not compile.
