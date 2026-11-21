"""A spawn's report list belongs to the walker it is delivered to: reading
it back works, and it is reclaimed with the walker (with everything it
holds) instead of outliving the program."""

glob dropped: int = 0;

obj Payload {
    has v: int = 0;

    def drop {
        dropped += 1;
    }
}

node Hub {
    has tag: int = 0;
}

walker Inner {
    can collect with Hub entry {
        report here.tag * 10;
    }
}

walker Reporter {
    can collect with Hub entry {
        report Payload(v=here.tag);
    }
}

walker Outer {
    can collect with Hub entry {
        report here.tag;
        here spawn Inner();
        visit [-->];
    }
}

def read_dropped -> int {
    return dropped;
}

def run(n: int) -> int {
    dropped = 0;
    h = Hub(tag=3);
    total = 0;
    i = 0;
    while i < n {
        w = h spawn Reporter();
        total += len(w.reports);
        i += 1;
    }
    return total;
}

def respawn -> int {
    dropped = 0;
    h = Hub(tag=4);
    w = Reporter();
    h spawn w;
    first = w.reports;
    h spawn w;
    return len(first) * 10 + len(w.reports);
}

def nested -> int {
    h = Hub(tag=1);
    h ++> Hub(tag=2);
    w = h spawn Outer();
    return 1 if str(w.reports) == "[1, 10, 2, 20]" else 0;
}
