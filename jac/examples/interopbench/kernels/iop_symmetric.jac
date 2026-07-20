"""Symmetric sv↔na scalar call pair with work on the callee side.

Variants:
  sv_local  - sv loop, sv executes the LCG (no crossing)
  sv_to_na  - sv loop, na executes the LCG (one sv→na crossing per call)
  na_local  - na loop, na executes the LCG (no crossing)
  na_to_sv  - na loop, sv executes the LCG (one na→sv crossing per call)
"""

import sys;
import time;


glob WARMUP_CALLS: int = 5,
     MODULUS: int = 2147483648,
     DEFAULT_WORK: int = 5000,
     DEFAULT_CALLS: int = 500;


def sv_lcg(seed: int, work: int) -> int {
    value = seed;
    for i in range(work) {
        value = (value * 1103515245 + 12345 + i) % MODULUS;
    }
    return value;
}


na {
    def native_lcg(seed: int, work: int) -> int {
        value = seed;
        for i in range(work) {
            value = (value * 1103515245 + 12345 + i) % 2147483648;
        }
        return value;
    }

    def run_na_local(work: int, calls: int) -> int {
        checksum = 0;
        for call_no in range(calls) {
            checksum = (checksum + native_lcg(call_no + 1, work)) % 2147483648;
        }
        return checksum;
    }

    def run_na_to_sv(work: int, calls: int) -> int {
        checksum = 0;
        for call_no in range(calls) {
            checksum = (checksum + sv_lcg(call_no + 1, work)) % 2147483648;
        }
        return checksum;
    }
}


def run_sv_local(work: int, calls: int) -> int {
    checksum = 0;
    for call_no in range(calls) {
        checksum = (checksum + sv_lcg(call_no + 1, work)) % MODULUS;
    }
    return checksum;
}


def run_sv_to_na(work: int, calls: int) -> int {
    checksum = 0;
    for call_no in range(calls) {
        checksum = (checksum + native_lcg(call_no + 1, work)) % MODULUS;
    }
    return checksum;
}


with entry {
    variant = sys.argv[1] if len(sys.argv) > 1 else "sv_local";
    work = int(sys.argv[2]) if len(sys.argv) > 2 else DEFAULT_WORK;
    calls = int(sys.argv[3]) if len(sys.argv) > 3 else DEFAULT_CALLS;
    if work < 1 or calls < 1 {
        print("work and calls must be positive");
        sys.exit(2);
    }
    if variant == "sv_local" {
        for _ in range(WARMUP_CALLS) {
            _ = run_sv_local(work, 1);
        }
        started = time.perf_counter_ns();
        checksum = run_sv_local(work, calls);
    } elif variant == "sv_to_na" {
        for _ in range(WARMUP_CALLS) {
            _ = run_sv_to_na(work, 1);
        }
        started = time.perf_counter_ns();
        checksum = run_sv_to_na(work, calls);
    } elif variant == "na_local" {
        for _ in range(WARMUP_CALLS) {
            _ = run_na_local(work, 1);
        }
        started = time.perf_counter_ns();
        checksum = run_na_local(work, calls);
    } elif variant == "na_to_sv" {
        for _ in range(WARMUP_CALLS) {
            _ = run_na_to_sv(work, 1);
        }
        started = time.perf_counter_ns();
        checksum = run_na_to_sv(work, calls);
    } else {
        print(f"unknown variant: {variant}");
        sys.exit(2);
    }
    elapsed = time.perf_counter_ns() - started;
    print(f"symmetric:{checksum}");
    print(f"m:per_call_ns={elapsed // calls}");
    print(f"ns={elapsed}");
}
