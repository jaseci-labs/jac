import sys;
import time;
import from "/usr/lib/libm.so.6" { def sqrt(x: f64) -> f64;  }


glob WARMUP_CALLS: int = 5,
     DEFAULT_WORK: int = 5000,
     DEFAULT_CALLS: int = 500;


def ffi_path(n: int) -> int {
    acc = 0;
    for i in range(1, n + 1) {
        acc = (acc + int(sqrt(float(i * i)))) % 2147483648;
    }
    return acc;
}


def ref_path(n: int) -> int {
    acc = 0;
    for i in range(1, n + 1) {
        acc = (acc + i) % 2147483648;
    }
    return acc;
}


with entry {
    variant = sys.argv[1] if len(sys.argv) > 1 else "ffi";
    n = int(sys.argv[2]) if len(sys.argv) > 2 else DEFAULT_WORK;
    calls = int(sys.argv[3]) if len(sys.argv) > 3 else DEFAULT_CALLS;
    if n < 1 or calls < 1 {
        print("n and calls must be positive");
        sys.exit(2);
    }
    if variant == "ffi" {
        for _ in range(WARMUP_CALLS) {
            _ = ffi_path(n);
        }
        started = time.perf_counter_ns();
        checksum = 0;
        for _ in range(calls) {
            checksum = (checksum + ffi_path(n)) % 2147483648;
        }
    } elif variant == "ref" {
        for _ in range(WARMUP_CALLS) {
            _ = ref_path(n);
        }
        started = time.perf_counter_ns();
        checksum = 0;
        for _ in range(calls) {
            checksum = (checksum + ref_path(n)) % 2147483648;
        }
    } else {
        print(f"unknown variant: {variant}");
        sys.exit(2);
    }
    elapsed = time.perf_counter_ns() - started;
    print(f"sqrt:{checksum}");
    print(f"m:per_ffi_call_ns={elapsed // (n * calls)}");
    print(f"ns={elapsed}");
}
