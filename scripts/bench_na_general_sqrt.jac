"""Three-lane sqrt bench: direct C FFI vs the bundled native `math` module vs a
CPython-bridge crossing, with a bare float loop as the floor.

Run with the native runtime (this file deliberately contains a DEMOTED function
so `jac build --native` would reject it -- demotions are fatal there):

    jac run -b native scripts/bench_na_general_sqrt.jac

CPython oracle (new .py files are blocked repo-wide, so it lives here; pipe it
into python3 -):

    import math, time

    def loop(n):
        acc = 0.0
        for i in range(n):
            acc += math.sqrt(float(i))
        return acc

    best = None
    for _ in range(3):
        t0 = time.perf_counter_ns()
        acc = loop(1000000)
        el = (time.perf_counter_ns() - t0) / 1000000
        best = el if best is None else min(best, el)
    print("cpython math.sqrt      %8.1f ns/call  acc=%.4f" % (best, acc))
"""

import sys;
import time;
import math;
import from m { def sqrt(x: f64) -> f64;  }


def _row(name: str, ns: float, acc: float) {
    sys.stdout.write(
        name + " " + format(ns, ".1f") + " ns/call  acc=" + format(acc, ".4f") + "\n"
    );
}


def sv_sqrt(x: float) -> float {
    tag: str = repr(x);
    if tag == "" {
        return 0.0;
    }
    return x ** 0.5;
}


def bench_bare(n: int) {
    best: float = -1.0;
    acc: float = 0.0;
    rep: int = 0;
    while rep < 3 {
        acc = 0.0;
        t0: int = time.perf_counter_ns();
        i: int = 0;
        while i < n {
            acc += float(i) * 0.5;
            i += 1;
        }
        el: float = float(time.perf_counter_ns() - t0) / float(n);
        if best < 0.0 or el < best {
            best = el;
        }
        rep += 1;
    }
    _row("bare float loop       ", best, acc);
}


def bench_ffi(n: int) {
    best: float = -1.0;
    acc: float = 0.0;
    rep: int = 0;
    while rep < 3 {
        acc = 0.0;
        t0: int = time.perf_counter_ns();
        i: int = 0;
        while i < n {
            acc += float(sqrt(f64(float(i))));
            i += 1;
        }
        el: float = float(time.perf_counter_ns() - t0) / float(n);
        if best < 0.0 or el < best {
            best = el;
        }
        rep += 1;
    }
    _row("na direct C sqrt      ", best, acc);
}


def bench_bundled(n: int) {
    best: float = -1.0;
    acc: float = 0.0;
    rep: int = 0;
    while rep < 3 {
        acc = 0.0;
        t0: int = time.perf_counter_ns();
        i: int = 0;
        while i < n {
            acc += math.sqrt(float(i));
            i += 1;
        }
        el: float = float(time.perf_counter_ns() - t0) / float(n);
        if best < 0.0 or el < best {
            best = el;
        }
        rep += 1;
    }
    _row("na bundled math.sqrt  ", best, acc);
}


def bench_bridge(n: int) {
    best: float = -1.0;
    acc: float = 0.0;
    rep: int = 0;
    while rep < 3 {
        acc = 0.0;
        t0: int = time.perf_counter_ns();
        i: int = 0;
        while i < n {
            acc += sv_sqrt(float(i));
            i += 1;
        }
        el: float = float(time.perf_counter_ns() - t0) / float(n);
        if best < 0.0 or el < best {
            best = el;
        }
        rep += 1;
    }
    _row("na -> CPython bridge  ", best, acc);
}


with entry {
    bench_bare(1000000);
    bench_ffi(1000000);
    bench_bundled(1000000);
    bench_bridge(50000);
}
