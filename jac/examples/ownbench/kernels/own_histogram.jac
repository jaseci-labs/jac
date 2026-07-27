import sys;
import time;

def fill_round(n: int, buckets: int, seed: int) -> int {
    h: dict[int, int] = {};
    seen = {0};
    x = seed;
    for i in range(n) {
        x = (x * 1103515245 + 12345) % 2147483648;
        b = x % buckets;
        if b in h {
            h[b] = h[b] + 1;
        } else {
            h[b] = 1;
        }
        seen.add(x % (buckets * 4));
    }
    digest = len(seen);
    for k in range(buckets) {
        if k in h {
            digest = (digest * 31 + k * h[k]) % 1000000007;
        }
    }
    return digest;
}

def run(n: int, reps: int) -> int {
    total = 0;
    for r in range(reps) {
        total = (total + fill_round(n, 512, r + 1)) % 1000000007;
    }
    return total;
}

with entry {
    n = 100000;
    if len(sys.argv) > 1 {
        n = int(sys.argv[1]);
    }
    reps = 20;
    if len(sys.argv) > 2 {
        reps = int(sys.argv[2]);
    }
    t0 = time.perf_counter_ns();
    total = run(n, reps);
    t1 = time.perf_counter_ns();
    print("hist:" + str(total));
    print("ns=" + str(t1 - t0));
}
