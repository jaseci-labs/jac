import sys;
import time;
import from feed_provider { feed_checksum }


glob WARMUP_CALLS: int = 5,
     DEFAULT_WORK: int = 5000,
     DEFAULT_CALLS: int = 500;


def run_direct(work: int, calls: int) -> int {
    checksum = 0;
    for call_no in range(calls) {
        checksum = (checksum + feed_checksum(call_no + 1, work)) % 2147483648;
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
        _ = run_direct(work, 1);
    }
    started = time.perf_counter_ns();
    checksum = run_direct(work, calls);
    elapsed = time.perf_counter_ns() - started;
    print(f"feed:{checksum}");
    print(f"m:per_call_ns={elapsed // calls}");
    print(f"ns={elapsed}");
}
