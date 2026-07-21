import sys;
import time;

node Spot {
    has v: int = 0,
        stamp: int = 0;
}

walker Collect {
    has want: int = 0,
        vals: list[int] = [];

    can s with Spot entry {
        if here.stamp != self.want {
            here.stamp = self.want;
            self.vals.append(here.v);
            visit [-->];
        }
    }
}

def checksum_of(vals: list[int]) -> int {
    digest = 0;
    rank = 0;
    for v in vals {
        rank += 1;
        digest = (digest * 31 + v * rank) % 1000000007;
    }
    return digest;
}

def touch(r: Region) -> Region {
    in r {
        anchor = Spot(v=0, stamp=99);
    }
    return r;
}

def encode(vals: list[int]) -> str {
    parts: list[str] = [];
    for v in vals {
        parts.append(str(v));
    }
    return ",".join(parts);
}

def decode(blob: str) -> list[int] {
    vals: list[int] = [];
    for tok in blob.split(",") {
        vals.append(int(tok));
    }
    return vals;
}

def run_move(n: int, reps: int) -> tuple[int, int] {
    digest = 0;
    moved_ns = 0;
    for rep in range(reps) {
        r: own Region = Region();
        e: Spot | None = None;
        in r {
            first = Spot(v=1);
            prev = first;
            for i in range(2, n + 1) {
                b = Spot(v=i);
                prev ++> b;
                prev = b;
            }
            e = first;
        }
        vals: list[int] = [];
        if e is not None {
            in r {
                w = e spawn Collect(want=1);
                for v in w.vals {
                    vals.append(v);
                }
            }
        }
        digest = checksum_of(vals);
        s0 = time.perf_counter_ns();
        h = flow touch(r) ;
        r2 = wait h ;
        moved_ns += time.perf_counter_ns() - s0;
        in r2 {
            anchor2 = Spot(v=0, stamp=98);
        }
    }
    return (digest, moved_ns // reps);
}

def run_copy(n: int, reps: int) -> tuple[int, int] {
    digest = 0;
    copied_ns = 0;
    for rep in range(reps) {
        r: own Region = Region();
        e: Spot | None = None;
        in r {
            first = Spot(v=1);
            prev = first;
            for i in range(2, n + 1) {
                b = Spot(v=i);
                prev ++> b;
                prev = b;
            }
            e = first;
        }
        vals: list[int] = [];
        s0 = time.perf_counter_ns();
        if e is not None {
            in r {
                w = e spawn Collect(want=1);
                for v in w.vals {
                    vals.append(v);
                }
            }
        }
        r2: own Region = Region();
        in r2 {
            prev2 = Spot(v=vals[0]);
            for i in range(1, len(vals)) {
                b2 = Spot(v=vals[i]);
                prev2 ++> b2;
                prev2 = b2;
            }
        }
        copied_ns += time.perf_counter_ns() - s0;
        digest = checksum_of(vals);
    }
    return (digest, copied_ns // reps);
}

def run_serial(n: int, reps: int) -> tuple[int, int] {
    digest = 0;
    ser_ns = 0;
    for rep in range(reps) {
        r: own Region = Region();
        e: Spot | None = None;
        in r {
            first = Spot(v=1);
            prev = first;
            for i in range(2, n + 1) {
                b = Spot(v=i);
                prev ++> b;
                prev = b;
            }
            e = first;
        }
        vals: list[int] = [];
        s0 = time.perf_counter_ns();
        if e is not None {
            in r {
                w = e spawn Collect(want=1);
                for v in w.vals {
                    vals.append(v);
                }
            }
        }
        blob = encode(vals);
        vals2 = decode(blob);
        r2: own Region = Region();
        in r2 {
            prev2 = Spot(v=vals2[0]);
            for i in range(1, len(vals2)) {
                b2 = Spot(v=vals2[i]);
                prev2 ++> b2;
                prev2 = b2;
            }
        }
        ser_ns += time.perf_counter_ns() - s0;
        digest = checksum_of(vals2);
    }
    return (digest, ser_ns // reps);
}

with entry {
    strategy = "move";
    if len(sys.argv) > 1 {
        strategy = sys.argv[1];
    }
    n = 1000;
    if len(sys.argv) > 2 {
        n = int(sys.argv[2]);
    }
    reps = 20;
    if len(sys.argv) > 3 {
        reps = int(sys.argv[3]);
    }
    t0 = time.perf_counter_ns();
    result = (0, 0);
    if strategy == "move" {
        result = run_move(n, reps);
    } elif strategy == "copy" {
        result = run_copy(n, reps);
    } else {
        result = run_serial(n, reps);
    }
    t1 = time.perf_counter_ns();
    print("rtransfer:" + str(result[0]));
    print("m:transfer_ns=" + str(result[1]));
    print("ns=" + str(t1 - t0));
}
