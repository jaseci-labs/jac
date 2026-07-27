import sys;
import time;

def build_vec(n: int, seed: int) -> list[float] {
    v = [];
    x = seed;
    for i in range(n) {
        x = (x * 1103515245 + 12345) % 2147483648;
        v.append((x % 10000) / 10000.0);
    }
    return v;
}

def dot(a: &list[float], b: &list[float]) -> float {
    s = 0.0;
    for i in range(len(a)) {
        s += a[i] * b[i];
    }
    return s;
}

def run(n: int, reps: int) -> float {
    total = 0.0;
    for r in range(reps) {
        a = build_vec(n, r + 1);
        b = build_vec(n, r + 7);
        total += dot(&a, &b);
    }
    return total;
}

with entry {
    n = 10000;
    if len(sys.argv) > 1 {
        n = int(sys.argv[1]);
    }
    reps = 100;
    if len(sys.argv) > 2 {
        reps = int(sys.argv[2]);
    }
    t0 = time.perf_counter_ns();
    total = run(n, reps);
    t1 = time.perf_counter_ns();
    print("dot:" + str(total));
    print("ns=" + str(t1 - t0));
}
