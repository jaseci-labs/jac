"""OSP stays legal in an enforced module: nodes/walkers are the third memory
world (statically immortal), so graph ops must not violate rc-free — their
retain/release sites are statically skipped, not dynamically no-op'd."""

node Hub {
    has tag: int = 0;
}

walker Probe {
    has seen: int = 0;

    can visit_hub with Hub entry {
        self.seen += here.tag;
    }
}

def run_probe(h: Hub) -> int {
    r = h spawn Probe();
    return r.seen;
}

glob h = Hub(tag=7);

with entry {
    print(run_probe(h));
}
