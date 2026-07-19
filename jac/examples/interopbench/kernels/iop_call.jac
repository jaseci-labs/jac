import sys;
import time;


def sv_checksum(seed: int, work: int) -> int {
    value = seed;
    for i in range(work) {
        value = (value * 1103515245 + 12345 + i) % 2147483648;
    }
    return value;
}


na {
    def native_checksum(seed: int, work: int) -> int {
        value = seed;
        for i in range(work) {
            value = (value * 1103515245 + 12345 + i) % 2147483648;
        }
        return value;
    }
}


def run_free(work: int, calls: int) -> int {
    checksum = 0;
    for call_no in range(calls) {
        checksum = (checksum + sv_checksum(call_no + 1, work)) % 2147483648;
    }
    return checksum;
}


def run_bridge(work: int, calls: int) -> int {
    checksum = 0;
    for call_no in range(calls) {
        checksum = (checksum + native_checksum(call_no + 1, work)) % 2147483648;
    }
    return checksum;
}


with entry {
    variant = sys.argv[1] if len(sys.argv) > 1 else "free";
    work = int(sys.argv[2]) if len(sys.argv) > 2 else 1000;
    calls = int(sys.argv[3]) if len(sys.argv) > 3 else 100;
    if work < 1 or calls < 1 {
        print("work and calls must be positive");
        sys.exit(2);
    }
    if variant == "free" {
        _ = run_free(work, 1);
        started = time.perf_counter_ns();
        checksum = run_free(work, calls);
    } elif variant == "bridge" {
        _ = run_bridge(work, 1);
        started = time.perf_counter_ns();
        checksum = run_bridge(work, calls);
    } else {
        print(f"unknown variant: {variant}");
        sys.exit(2);
    }
    elapsed = time.perf_counter_ns() - started;
    print(f"call:{checksum}");
    print(f"m:per_call_ns={elapsed // calls}");
    print(f"ns={elapsed}");
}
