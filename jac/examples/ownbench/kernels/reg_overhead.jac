import sys;
import time;

obj Scratch {
    has v: int = 0;
}

node Spot {
    has v: int = 0;
}

walker Bump {
    has k: int = 0,
        sink: int = 0,
        keep: list = [];

    can a with Spot entry {
        for i in range(self.k) {
            s = Scratch(v=i);
            self.keep.append(s);
            self.sink += s.v;
        }
    }
}

def run_managed(k: int) -> tuple[int, int] {
    ms = Spot(v=0);
    s0 = time.perf_counter_ns();
    w = ms spawn Bump(k=k);
    s1 = time.perf_counter_ns();
    return (w.sink, (s1 - s0) // k);
}

def run_region(k: int) -> tuple[int, int] {
    sink = 0;
    per = 0;
    r: own Region = Region();
    in r {
        rs = Spot(v=0);
        s0 = time.perf_counter_ns();
        w = rs spawn Bump(k=k);
        s1 = time.perf_counter_ns();
        sink = w.sink;
        per = (s1 - s0) // k;
    }
    return (sink, per);
}

with entry {
    k = 1000000;
    if len(sys.argv) > 1 {
        k = int(sys.argv[1]);
    }
    t0 = time.perf_counter_ns();
    m = run_managed(k);
    g = run_region(k);
    t1 = time.perf_counter_ns();
    print("roverhead:" + str(m[0]) + ":" + str(g[0]));
    print("m:managed_alloc_ns=" + str(m[1]));
    print("m:region_alloc_ns=" + str(g[1]));
    print("ns=" + str(t1 - t0));
}
