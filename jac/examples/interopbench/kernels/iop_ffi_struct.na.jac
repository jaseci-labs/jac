import sys;
import time;
import from "bin/libinteropbench.so" {
    obj ib_vec4 {
        has a: i32;
    }  obj ib_vec12 {
        has a: i32,
            b: i32,
            c: i32;
    }  obj ib_vec16 {
        has a: i32,
            b: i32,
            c: i32,
            d: i32;
    }  obj ib_vec24 {
        has a: i64,
            b: i64,
            c: i64;
    }  obj ib_vec44 {
        has v0: i32,
            v1: i32,
            v2: i32,
            v3: i32,
            v4: i32,
            v5: i32,
            v6: i32,
            v7: i32,
            v8: i32,
            v9: i32,
            v10: i32;
    }  def ib_vec4_make(a: i32) -> ib_vec4;  def ib_vec4_sum(v: ib_vec4) -> i32;  def ib_vec12_make(
        a: i32, b: i32, c: i32
    ) -> ib_vec12;  def ib_vec12_sum(v: ib_vec12) -> i32;  def ib_vec16_make(
        a: i32, b: i32, c: i32, d: i32
    ) -> ib_vec16;  def ib_vec16_sum(v: ib_vec16) -> i32;  def ib_vec24_make(
        a: i64, b: i64, c: i64
    ) -> ib_vec24;  def ib_vec24_sum(v: ib_vec24) -> i64;  def ib_vec44_make(
        seed: i32
    ) -> ib_vec44;  def ib_vec44_sum(v: ib_vec44) -> i32;
}


def ffi_path(n: int) -> int {
    acc = 0;
    for i in range(1, n + 1) {
        v4 = ib_vec4_make(i);
        v12 = ib_vec12_make(i, i + 1, i + 2);
        v16 = ib_vec16_make(i, i + 1, i + 2, i + 3);
        v24 = ib_vec24_make(i, i + 1, i + 2);
        v44 = ib_vec44_make(i);
        acc = (
            acc + int(ib_vec4_sum(v4)) + int(ib_vec12_sum(v12)) + int(
                ib_vec16_sum(v16)
            ) + int(ib_vec24_sum(v24)) + int(ib_vec44_sum(v44))
        ) % 2147483648;
    }
    return acc;
}


def ref_path(n: int) -> int {
    acc = 0;
    for i in range(1, n + 1) {
        v44_total = 0;
        for k in range(1, 12) {
            v44_total = (v44_total + (i * k) % 1009) % 2147483648;
        }
        acc = (
            acc + i + (i + (i + 1) + (i + 2)) + (i + (i + 1) + (i + 2) + (i + 3)) + (
                i + (i + 1) + (i + 2)
            ) + v44_total
        ) % 2147483648;
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
    print(f"struct:{checksum}");
    print(f"m:per_ffi_call_ns={elapsed // (10 * n * calls)}");
    print(f"ns={elapsed}");
}
