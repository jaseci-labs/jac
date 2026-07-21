import sys;
import time;

glob drops: int = 0;

node Spot {
    has v: int = 0,
        seen: bool = False;

    def drop {
        drops += 1;
    }
}

walker Sum {
    has total: int = 0;

    can s with Spot entry {
        if not here.seen {
            here.seen = True;
            self.total += here.v;
            visit [-->];
        }
    }
}

def request(n: int, back: int) -> int {
    total = 0;
    r: own Region = Region();
    in r {
        a = Spot(v=1);
        prev = a;
        ring: list = [];
        ring.append(a);
        for i in range(2, n + 1) {
            b = Spot(v=i);
            prev ++> b;
            ring.append(b);
            if back > 0 and i % back == 0 {
                b ++> ring[i - back];
            }
            prev = b;
        }
        w = a spawn Sum();
        total = w.total;
    }
    return total;
}

with entry {
    n = 200;
    if len(sys.argv) > 1 {
        n = int(sys.argv[1]);
    }
    reps = 500;
    if len(sys.argv) > 2 {
        reps = int(sys.argv[2]);
    }
    back = 0;
    if len(sys.argv) > 3 {
        back = int(sys.argv[3]);
    }
}

glob lat: list[int] = [];

with entry {
    total = 0;
    t0 = time.perf_counter_ns();
    for req in range(reps) {
        s0 = time.perf_counter_ns();
        total += request(n, back);
        lat.append(time.perf_counter_ns() - s0);
    }
    t1 = time.perf_counter_ns();
    print("rgraph:" + str(total));
    lat.sort();
    print("m:drops=" + str(drops));
    print("m:p50=" + str(lat[reps // 2]));
    print("m:p99=" + str(lat[(reps * 99) // 100]));
    print("m:pmax=" + str(lat[reps - 1]));
    print("ns=" + str(t1 - t0));
}
