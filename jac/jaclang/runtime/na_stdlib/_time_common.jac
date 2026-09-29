import from c { def clock_gettime(clk: i32, ts: int) -> i32;  }
import from c { def clock_settime(clk: i32, ts: int) -> i32;  }
import from _errno_native { last_errno, raise_errno }

glob NS_PER_SEC: int = 1000000000;

def _clock_gettime(clk: int, ts: int) {
    if clock_gettime(i32(clk), ts) != 0 {
        raise_errno(last_errno());
    }
}

def:pub time_clock_ns(clk: int) -> int {
    ts: int = __alloca(16);
    _clock_gettime(clk, ts);
    return __mem_load_i64(ts) * NS_PER_SEC + __mem_load_i64(ts + 8);
}

def:pub time_clock_seconds(clk: int) -> float {
    ts: int = __alloca(16);
    _clock_gettime(clk, ts);
    return float(__mem_load_i64(ts)) + float(__mem_load_i64(ts + 8)) * 1e-9;
}

def:pub time_clock_set_ns(clk: int, ns: int) {
    sec: int = ns // NS_PER_SEC;
    nsec: int = ns - sec * NS_PER_SEC;
    ts: int = __alloca(16);
    __mem_store_i64(ts, sec);
    __mem_store_i64(ts + 8, nsec);
    if clock_settime(i32(clk), ts) != 0 {
        raise_errno(last_errno());
    }
}
