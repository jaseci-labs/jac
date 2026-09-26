import from time { monotonic_ns }
import from _sqrt_bench_native { sb_sqrt }
import math as m;


def lane_ffi(n: int) -> tuple[(float, int)] {
    acc: float = 0.0;
    i: int = 0;
    t0: int = monotonic_ns();
    while i < n {
        acc += sb_sqrt(float(i % 1000));
        i += 1;
    }
    return (acc, monotonic_ns() - t0);
}


def lane_bundled(n: int) -> tuple[(float, int)] {
    acc: float = 0.0;
    i: int = 0;
    t0: int = monotonic_ns();
    while i < n {
        acc += m.sqrt(float(i % 1000));
        i += 1;
    }
    return (acc, monotonic_ns() - t0);
}


glob n: int = 1000000,
     reps: int = 4;

with entry {
    bt1: int = -1;
    ba1: float = 0.0;
    bt2: int = -1;
    ba2: float = 0.0;
    k: int = 0;
    while k <= reps {
        r1: tuple[(float, int)] = lane_ffi(n);
        r2: tuple[(float, int)] = lane_bundled(n);
        if k > 0 {
            if bt1 < 0 or r1[1] < bt1 {
                bt1 = r1[1];
                ba1 = r1[0];
            }
            if bt2 < 0 or r2[1] < bt2 {
                bt2 = r2[1];
                ba2 = r2[0];
            }
        }
        k += 1;
    }
    print("ffi", bt1 / n, str(ba1));
    print("bundled", bt2 / n, str(ba2));
}
# CPython oracle lane (not committed - new .py files are blocked):
# python3 loop `acc += math.sqrt(float(i % 1000))` over the same N/reps;
# baseline 665ns/call with checksum 21065833.110874526 on the reference box.
