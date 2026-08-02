import sys;
import time;
import from "bin/libinteropbench.so" { def ib_fnv1a(buf: bytes, length: i32) -> int;  }


glob DEFAULT_WORK: int = 5000,
     DEFAULT_CALLS: int = 500,
     BUF_LEN: int = 16;


"""FFI path: 64-bit FNV-1a over a 16-byte buffer, computed by libinteropbench.
The buffer is built ONCE by the caller and reused, so the timed loop measures
only the FFI crossing (pointer+length marshalling of an already-allocated
buffer), not na heap allocation -- mirroring the `isolated` methodology on the
CPython comparand side, which reuses a fixed buffer per call."""
def ffi_path(n: int, buf: bytes) -> int {
    acc = 0;
    for i in range(1, n + 1) {
        h = ib_fnv1a(buf, BUF_LEN);
        # Fold the signed-i64 hash into low 31 bits with a bitmask (not `%`,
        # whose C-style sign-of-dividend would make the digest negative).
        acc = (acc + (h & 2147483647)) & 2147483647;
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
        buf = bytes([7 for _ in range(BUF_LEN)]);
        # Single full warm pass (one ffi_path over n iters) instead of a warmup
        # `for` loop: a range-loop callsite of this bytes-arg function currently
        # hangs the native monomorphizer, and one n-iteration pass warms the JIT.
        _ = ffi_path(n, buf);
        started = time.perf_counter_ns();
        checksum = 0;
        for _ in range(calls) {
            checksum = (checksum + ffi_path(n, buf)) % 2147483648;
        }
    } elif variant == "ref" {
        # No pure-Jac reference: the 64-bit FNV-1a needs uint64 two's-complement
        # wrap, but native Jac `int` is a checked i64 that traps on the first
        # multiply overflow. The differential reference for this kernel therefore
        # lives on the Python/C side of the cross-tool oracle (scripts/xtool_ffi.py
        # bytes_ref), which recomputes the identical FNV-1a. This is an FFI-only
        # anchor kernel, not a family-1 differential cell.
        print("ref: unsupported (native i64 cannot host uint64 FNV wrap)");
        print("ref: differential reference is scripts/xtool_ffi.py bytes_ref");
        sys.exit(0);
    } else {
        print(f"unknown variant: {variant}");
        sys.exit(2);
    }
    elapsed = time.perf_counter_ns() - started;
    print(f"bytes:{checksum}");
    print(f"m:per_ffi_call_ns={elapsed // (n * calls)}");
    print(f"ns={elapsed}");
}
