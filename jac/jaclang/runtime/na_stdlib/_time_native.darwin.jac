"""macOS clock ids and sleep for the bundled time module. CLK_PY_MONOTONIC
is the clock CPython's monotonic() and perf_counter() read here:
mach_absolute_time(), which CLOCK_UPTIME_RAW (8) reports in nanoseconds and
which, unlike CLOCK_MONOTONIC, stops while the system sleeps."""

import from c { def nanosleep(req: int, rem: int) -> i32;  }
import from _errno_native { EINTR, last_errno, raise_errno }
import from _time_common { NS_PER_SEC }

glob CLK_REALTIME: int = 0,
     CLK_MONOTONIC: int = 6,
     CLK_MONOTONIC_RAW: int = 4,
     CLK_PROCESS_CPUTIME: int = 12,
     CLK_THREAD_CPUTIME: int = 16,
     CLK_PY_MONOTONIC: int = 8;

def:pub time_sleep_ns(ns: int) {
    sec: int = ns // NS_PER_SEC;
    nsec: int = ns % NS_PER_SEC;
    req: int = __alloca(16);
    __mem_store_i64(req, sec);
    __mem_store_i64(req + 8, nsec);
    rem: int = __alloca(16);
    while nanosleep(req, rem) != 0 {
        code: int = last_errno();
        if code == EINTR {
            __mem_store_i64(req, __mem_load_i64(rem));
            __mem_store_i64(req + 8, __mem_load_i64(rem + 8));
            continue;
        }
        raise_errno(code);
    }
}
