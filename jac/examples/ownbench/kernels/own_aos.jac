import sys;
import time;

obj Particle {
    has x: int = 0,
        y: int = 0;
}

obj Sim {
    has best: own Particle = Particle(),
        score: int = 0;
}

def build(n: int, seed: int) -> list[Particle] {
    ps: list[Particle] = [];
    s = seed;
    for i in range(n) {
        s = (s * 1103515245 + 12345) % 2147483648;
        ps.append(Particle(x=s % 1000, y=(s // 7) % 1000));
    }
    return ps;
}

def checksum(ps: &list[Particle]) -> int {
    t = 0;
    for i in range(len(ps)) {
        t = (t + ps[i].x * (i + 1) + ps[i].y) % 1000000007;
    }
    return t;
}

def run_aos(n: int, seed: int) -> int {
    qs: list[own Particle] = [];
    s = seed;
    for i in range(n) {
        s = (s * 1103515245 + 12345) % 2147483648;
        qs.append(Particle(x=s % 500, y=(s // 11) % 500));
    }
    t = 0;
    for i in range(len(qs)) {
        t = (t + qs[i].x * 7 + qs[i].y * (i + 1)) % 1000000007;
    }
    return t;
}

def run(n: int, reps: int) -> int {
    total = 0;
    for r in range(reps) {
        ps = build(n, r + 1);
        c = checksum(&ps);
        total = (total + c) % 1000000007;
        total = (total + run_aos(n, r + 3)) % 1000000007;
        sim: own Sim = Sim();
        for i in range(len(ps)) {
            if ps[i].x > sim.best.x {
                sim.best = Particle(x=ps[i].x, y=ps[i].y);
                sim.score = sim.score + 1;
            }
        }
        total = (total + sim.best.x + sim.best.y + sim.score) % 1000000007;
    }
    return total;
}

with entry {
    n = 1000;
    if len(sys.argv) > 1 {
        n = int(sys.argv[1]);
    }
    reps = 10;
    if len(sys.argv) > 2 {
        reps = int(sys.argv[2]);
    }
    t0 = time.perf_counter_ns();
    total = run(n, reps);
    t1 = time.perf_counter_ns();
    print("aos:" + str(total));
    print("ns=" + str(t1 - t0));
}
