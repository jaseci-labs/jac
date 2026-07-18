"""Cross-backend OSP equivalence fixture: `report` collection across the walk.

The walker `report`s each location's value as it traverses a chain
`10 -> 20 -> 30`; the collected reports `[10, 20, 30]` are delivered at the
spawn boundary and read back off the walker.

Backend status: na and py agree. `report` lowers to the kernel's `osp_report`
(appending to the walk scope's reports), and the native `on_complete` delivers
`scope.reports` onto the walker's built-in `reports` field at the spawn boundary
(mirroring cl/sv), so `w.reports` reads back. cl is unwired here, so the
cross-backend assert is na vs py.
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

na {
    def report_na() -> dict[str, any] {
        n1 = N(val=10); n2 = N(val=20); n3 = N(val=30);
        n1 ++> n2; n2 ++> n3;
        w = Rep();
        w spawn n1;
        return {"reports": w.reports};
    }
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
