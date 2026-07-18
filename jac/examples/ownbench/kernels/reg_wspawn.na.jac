import sys;
import time;

glob wdrops: int = 0,
     rdrops: int = 0;

node Spot {
    has v: int = 0,
        stamp: int = 0;
}

obj Res {
    has fd: int = 0;

    def drop {
        rdrops += 1;
    }
}

walker Serve {
    has res: Res | None = None,
        cur: int = 0,
        total: int = 0;

    can s with Spot entry {
        if here.stamp != self.cur {
            here.stamp = self.cur;
            self.total += here.v;
            visit [-->];
        }
    }

    def drop {
        wdrops += 1;
    }
}

def build_graph(n: int) -> Spot {
    a = Spot(v=1);
    prev = a;
    for i in range(2, n + 1) {
        b = Spot(v=i);
        prev ++> b;
        prev = b;
    }
    return a;
}

with entry {
    n = 50;
    if len(sys.argv) > 1 {
        n = int(sys.argv[1]);
    }
    reps = 10000;
    if len(sys.argv) > 2 {
        reps = int(sys.argv[2]);
    }
    entry_spot = build_graph(n);
    total = 0;
    t0 = time.perf_counter_ns();
    for req in range(reps) {
        w = entry_spot spawn Serve(res=Res(fd=req), cur=req + 1);
        total += w.total;
    }
    t1 = time.perf_counter_ns();
    print("wspawn:" + str(total));
    print("m:wdrops=" + str(wdrops));
    print("m:rdrops=" + str(rdrops));
    print("ns=" + str(t1 - t0));
}
