import from c { def __jac_clock_id(jac_clock: i32) -> int;  }
import from c { def __jac_sleep_ns(ns: int) -> i32;  }

glob CLK_REALTIME: int = __jac_clock_id(i32(0)),
     CLK_MONOTONIC: int = __jac_clock_id(i32(1)),
     CLK_PROCESS_CPUTIME: int = __jac_clock_id(i32(2)),
     CLK_THREAD_CPUTIME: int = __jac_clock_id(i32(3)),
     CLK_MONOTONIC_RAW: int = __jac_clock_id(i32(4)),
     CLK_PY_MONOTONIC: int = __jac_clock_id(i32(5));

def:pub time_sleep_ns(ns: int);

impl time_sleep_ns(ns: int) {
    code: int = int(__jac_sleep_ns(ns));
    if code != 0 {
        raise_errno(code);
    }
}
