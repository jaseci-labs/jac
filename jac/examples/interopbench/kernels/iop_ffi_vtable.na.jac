import sys;
import time;
import from "bin/libinteropbench.so" {
    obj ib_handler_vt {
        has size: int = 0,
            on_event: Callable[[i32, i32], i32] = 0;
    }  def ib_invoke_event(h: int, a: i32, b: i32) -> int;
}


def jac_callback(a: int, b: int) -> int {
    return a * 7 + b * 3 + 1;
}


def jac_callback_ref(a: int, b: int) -> int {
    return a * 7 + b * 3 + 1;
}


def ffi_path(n: int) -> int {
    acc = 0;
    h = ib_handler_vt(size=16, on_event=jac_callback);
    for i in range(1, n + 1) {
        result = ib_invoke_event(h, i, i + 1);
        acc = (acc + int(result)) % 2147483648;
    }
    return acc;
}


def ref_path(n: int) -> int {
    acc = 0;
    for i in range(1, n + 1) {
        acc = (acc + jac_callback_ref(i, i + 1)) % 2147483648;
    }
    return acc;
}


glob WARMUP_CALLS: int = 5,
     DEFAULT_WORK: int = 5000,
     DEFAULT_CALLS: int = 500;


with entry {
    variant = sys.argv[1] if len(sys.argv) > 1 else "ffi";
    n = int(sys.argv[2]) if len(sys.argv) > 2 else DEFAULT_WORK;
    calls = int(sys.argv[3]) if len(sys.argv) > 3 else DEFAULT_CALLS;
    if n < 1 or calls < 1 {
        print("n and calls must be positive");
        sys.exit(2);
    }
    if variant == "ffi" {
        h = ib_handler_vt(size=16, on_event=jac_callback);
        _ = ib_invoke_event(h, 0, 0);
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
    print(f"vtable:{checksum}");
    print(f"m:trampoline_call_ns={elapsed // (n * calls)}");
    print(f"ns={elapsed}");
}
