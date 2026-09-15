"""Cross-backend OSP equivalence fixture: nested-walk report aggregation.

The outer walker reports, spawns an inner walker whose ability reports twice,
then reports again. Reports belong to the outermost walk: the kernel bubbles
a nested walk's reports into the enclosing scope when its spawn completes, so
the outer stream interleaves the inner reports at the nested-spawn point --
`[3, 40, 41, 300]` -- identically on every backend.
"""

node Item {
    has val: int;
}

walker InnerRep {
    can grab with Item entry {
        report here.val * 10;
        report here.val * 10 + 1;
    }
}

walker OuterRep {
    can run with Item entry {
        report here.val;
        inner = InnerRep();
        inner spawn Item(val=here.val + 1);
        report here.val * 100;
    }
}

def nested_report_py() -> dict[str, any] {
    o = OuterRep();
    o spawn Item(val=3);
    return {"reports": o.reports};
}


def nested_report_na() -> dict[str, any] {
    o = OuterRep();
    o spawn Item(val=3);
    return {"reports": o.reports};
}


def nested_report_cl() -> dict[str, any] {
    o = OuterRep();
    o spawn Item(val=3);
    return {"reports": o.reports};
}
