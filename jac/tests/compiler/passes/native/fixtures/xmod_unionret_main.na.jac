"""Native cross-module union-return consumer (issue #6659 Bug 3): consumes a
cross-module `Area | None`, narrows it with `is not None`, then exercises every
shape the real multi-module app needed -- read a field off the narrowed node,
pass it to a function typed `Area`, and spawn a walker on it -- plus the None
branch falling through to the default. With the imported node header / inherited
layout unsound these returned garbage, crashed, or failed type checking
(E1053 / E1115). The same program on the @sv pathway returns
{"present": 5, "taken": 5, "hits": 5, "absent": -1}."""

import from xmod_unionret_lib { Area, Probe, area_or_none, take }

def unionret_na() -> dict[str, any] {
    cur = area_or_none(True);
    present = cur.tag if cur is not None else -1;
    taken = -1;
    hits = -1;
    if cur is not None {
        taken = take(cur);
        w = Probe();
        w spawn cur;
        hits = w.hits;
    }
    gone = area_or_none(False);
    absent = gone.tag if gone is not None else -1;
    return {"present": present, "taken": taken, "hits": hits, "absent": absent};
}
