"""Cross-backend OSP equivalence fixture: `report` collection across the walk.

The walker `report`s each location's value as it traverses a chain
`10 -> 20 -> 30`; the collected reports `[10, 20, 30]` are delivered at the
spawn boundary and read back off the walker.

Backend status: `report` is E5090 on na and unwired on cl (also needs
visit/edges), so py-only today.
"""

node N { has val: int; }

walker Rep {
    can step with N entry {
        report here.val;
        visit [-->];
    }
}

def report_py() -> dict[str, any] {
    n1 = N(val=10); n2 = N(val=20); n3 = N(val=30);
    n1 ++> n2; n2 ++> n3;
    w = Rep();
    w spawn n1;
    return {"reports": w.reports};
}

cl {
    def report_cl() -> dict[str, any] {
        n1 = N(val=10); n2 = N(val=20); n3 = N(val=30);
        n1 ++> n2; n2 ++> n3;
        w = Rep();
        w spawn n1;
        return {"reports": w.reports};
    }
}
