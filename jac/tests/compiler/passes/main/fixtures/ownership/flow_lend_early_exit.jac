"""A side exit between the spawn and the wait: the early return path
skips the join while the task still borrows `a` -- the lend is rejected."""

obj Buffer {
    has n: int = 0;
}

def read_it(x: &Buffer) -> int {
    return x.n;
}

def risky(flag: bool) -> int {
    a: own Buffer = Buffer(n=5);
    h = flow read_it(&a) ;
    if flag {
        return 0;
    }
    r = wait h ;
    return r;
}
