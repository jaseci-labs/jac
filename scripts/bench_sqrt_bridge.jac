import from time { monotonic_ns }
import math as m;


def bridge_sqrt(x: float) -> float {
    r: str = repr(x);
    return m.sqrt(x) + (len(r) - len(r));
}


def lane_bare(n: int) -> tuple[(float, int)] {
    acc: float = 0.0;
    i: int = 0;
    t0: int = monotonic_ns();
    while i < n {
        acc += 1.0;
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


def lane_bridge(n: int) -> tuple[(float, int)] {
    acc: float = 0.0;
    i: int = 0;
    t0: int = monotonic_ns();
    while i < n {
        acc += bridge_sqrt(float(i % 1000));
        i += 1;
    }
    return (acc, monotonic_ns() - t0);
}


glob n: int = 1000000,
     reps: int = 3;

with entry {
    bb: int = -1;
    bt2: int = -1;
    ba2: float = 0.0;
    bt3: int = -1;
    ba3: float = 0.0;
    k: int = 0;
    while k <= reps {
        r0: tuple[(float, int)] = lane_bare(n);
        r2: tuple[(float, int)] = lane_bundled(n);
        r3: tuple[(float, int)] = lane_bridge(n);
        if k > 0 {
            if bb < 0 or r0[1] < bb {
                bb = r0[1];
            }
            if bt2 < 0 or r2[1] < bt2 {
                bt2 = r2[1];
                ba2 = r2[0];
            }
            if bt3 < 0 or r3[1] < bt3 {
                bt3 = r3[1];
                ba3 = r3[0];
            }
        }
        k += 1;
    }
    print("bare", bb / n);
    print("bundled", bt2 / n, str(ba2));
    print("bridge", bt3 / n, str(ba3));
}
