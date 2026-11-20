import from c { def clock_gettime(clk: i32, ts: int) -> i32;  }
import from c { def clock_settime(clk: i32, ts: int) -> i32;  }

glob NS_PER_SEC: int = 1000000000;

def _clock_gettime(clk: int, ts: int);

def:pub time_clock_ns(clk: int) -> int;

def:pub time_clock_seconds(clk: int) -> float;

def:pub time_clock_set_ns(clk: int, ns: int);
