"""Phase W (#7491): walkers are ordinary managed objects, not
RC_SENTINEL-immortal, so spawn-heavy workloads reclaim them. The walker's
drop hook observes reclamation."""

glob dropped: int = 0;

node Hub {
    has tag: int = 0;
}

walker Probe {
    has seen: int = 0;

    def drop {
        dropped += 1;
    }

    can visit_hub with Hub entry {
        self.seen += here.tag;
    }
}

def read_dropped -> int {
    return dropped;
}

def run(n: int) -> int {
    dropped = 0;
    total = 0;
    h = Hub(tag=3);
    i = 0;
    while i < n {
        r = h spawn Probe();
        total += r.seen;
        i += 1;
    }
    return total;
}
