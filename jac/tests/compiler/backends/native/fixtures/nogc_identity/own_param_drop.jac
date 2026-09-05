"""An `own` local passed to an `own` parameter is consumed by the caller and
dropped by the callee after its last use; an `own` value returned from a helper
is dropped by the receiver. Both drops fire exactly once (#8984, found while
narrowing A1)."""

obj Job {
    has id: int = 0;

    def drop { print("drop job " + str(self.id)); }
}

def sink(p: own Job) -> int { return p.id; }

def make -> own Job {
    j: own Job = Job(id=7);
    return j;
}

def run -> int {
    j: own Job = Job(id=1);
    n = sink(j);
    k: own Job = make();
    return n + k.id;
}

with entry { print(run()); print("done"); }
