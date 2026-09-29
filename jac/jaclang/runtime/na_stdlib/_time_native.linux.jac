import from c { def clock_gettime(clk: i32, ts: int) -> i32;  }
import from c { def clock_nanosleep(clk: i32, flags: i32, req: int, rem: int) -> i32;  }
import from _errno_native { EINTR, last_errno, raise_errno }
import from _time_common { NS_PER_SEC }

glob CLK_REALTIME: int = 0,
     CLK_MONOTONIC: int = 1,
     CLK_PROCESS_CPUTIME: int = 2,
     CLK_THREAD_CPUTIME: int = 3,
     CLK_MONOTONIC_RAW: int = 4,
     _TIMER_ABSTIME: int = 1;

def:pub time_sleep_ns(ns: int) {
    ts: int = __alloca(16);
    if clock_gettime(i32(CLK_MONOTONIC), ts) != 0 {
        raise_errno(last_errno());
    }
    add_sec: int = ns // NS_PER_SEC;
    nsec: int = __mem_load_i64(ts + 8) + ns - add_sec * NS_PER_SEC;
    sec: int = __mem_load_i64(ts) + add_sec;
    if nsec >= NS_PER_SEC {
        nsec -= NS_PER_SEC;
        sec += 1;
    }
    __mem_store_i64(ts, sec);
    __mem_store_i64(ts + 8, nsec);
    rem: int = __alloca(16);
    res: i32 = clock_nanosleep(i32(CLK_MONOTONIC), i32(_TIMER_ABSTIME), ts, rem);
    while res == EINTR {
        res = clock_nanosleep(i32(CLK_MONOTONIC), i32(_TIMER_ABSTIME), ts, rem);
    }
    if res != 0 {
        raise_errno(int(res));
    }
}
