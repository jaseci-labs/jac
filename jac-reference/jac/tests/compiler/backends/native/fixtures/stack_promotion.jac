"""Fixture: owned locals whose borrows stay frame-local are stack-promotable."""

obj Buffer {
    has n: int = 0;
}

def read_it(x: &Buffer) -> int {
    return x.n;
}

def bump_it(m: &mut Buffer) {
    m.n = m.n + 1;
}

def promoted_frame -> int {
    b: own Buffer = Buffer();
    bump_it(&mut b);
    t = read_it(&b);
    return t + b.n;
}

def escaping_frame -> own Buffer {
    e: own Buffer = Buffer();
    return e;
}

with entry {
    print(promoted_frame());
    x = escaping_frame();
    print(x.n);
}
