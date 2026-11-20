"""Issue #6683 fixture (imported half): the Object-Spatial spawn lives HERE.
`run_probe` spawns a walker on a `Hub` node the ENTRY module constructed and
handed in. Because this imported module is the only one that uses OSP, the
entry module that constructs the node assigns it NO dispatch tag unless the
construction site writes the globally-stable tag unconditionally.

Expected: `run_probe(Hub(tag=7))` -> 7."""

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
