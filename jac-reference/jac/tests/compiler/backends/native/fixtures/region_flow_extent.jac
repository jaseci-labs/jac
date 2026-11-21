"""Dynamic extent is per thread (#8913): a flow body under an open runs on
worker threads that start with no current region, so its temporaries take
the managed path while the join still sees every element it mutated and the
open tears down exactly once."""

obj P {
    has x: int = 0;
}

obj Tmp {
    has v: int = 0;
}

def scenario -> int {
    total = 0;
    ps: list[P] = [P(x=1), P(x=2), P(x=3)];
    r: own Region = Region();
    in r {
        flow for m in &mut ps {
            m.x = Tmp(v=m.x * 10).v;
        }
        for p in ps {
            total = total + p.x;
        }
    }
    return total;
}
