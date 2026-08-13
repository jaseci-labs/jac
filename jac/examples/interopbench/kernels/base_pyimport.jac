import sys;
import time;
import numpy as np;


glob WARMUP_CALLS: int = 5,
     DEFAULT_WORK: int = 5000,
     DEFAULT_CALLS: int = 500;


def py_leaf(seed: int, work: int) -> int {
    arr = np.arange(work, dtype=np.int64);
    return (int(np.sum(arr)) + seed) % 2147483648;
}


def run_pyimport(work: int, calls: int) -> int {
    checksum = 0;
    for call_no in range(calls) {
        checksum = (checksum + py_leaf(call_no + 1, work)) % 2147483648;
    }
    return checksum;
}


with entry {
    work = int(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_WORK;
    calls = int(sys.argv[2]) if len(sys.argv) > 2 else DEFAULT_CALLS;
    if work < 1 or calls < 1 {
        print("work and calls must be positive");
        sys.exit(2);
    }
    for _ in range(WARMUP_CALLS) {
        _ = run_pyimport(work, 1);
    }
    started = time.perf_counter_ns();
    checksum = run_pyimport(work, calls);
    elapsed = time.perf_counter_ns() - started;
    print(f"pyimport:{checksum}");
    print(f"m:per_call_ns={elapsed // calls}");
    print(f"ns={elapsed}");
}
