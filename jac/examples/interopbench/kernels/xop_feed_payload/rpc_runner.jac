import sys;
import time;
sv import from feedbatch { feed_batch }


glob WARMUP_CALLS: int = 5,
     DEFAULT_N: int = 100,
     DEFAULT_CALLS: int = 20;


def run_payload(n: int, calls: int) -> int {
    checksum = 0;
    for call_no in range(calls) {
        batch = feed_batch(call_no + 1, n);
        for x in batch {
            checksum = (checksum + x) % 2147483648;
        }
    }
    return checksum;
}


with entry {
    n = int(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_N;
    calls = int(sys.argv[2]) if len(sys.argv) > 2 else DEFAULT_CALLS;
    if n < 1 or calls < 1 {
        print("n and calls must be positive");
        sys.exit(2);
    }
    for _ in range(WARMUP_CALLS) {
        _ = run_payload(n, 1);
    }
    started = time.perf_counter_ns();
    checksum = run_payload(n, calls);
    elapsed = time.perf_counter_ns() - started;
    print(f"payload:{checksum}");
    print(f"m:per_call_ns={elapsed // calls}");
    print(f"ns={elapsed}");
}
