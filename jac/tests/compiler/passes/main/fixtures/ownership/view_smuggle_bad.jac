"""views smuggled through containers, bound `own`, or stored into
module globals are each E1315: storage is exactly what the derivation
bound fences until container storability lands."""

glob sink: own str = "";

def smuggle(s: &str) -> int {
    xs = [s[0:2]];
    p: own str = s[1:3];
    return len(xs) + len(p);
}

def leak_global(s: &str) {
    sink = s[0:2];
}
