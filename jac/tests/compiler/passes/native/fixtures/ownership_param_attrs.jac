"""Fixture: one function per ownership contract position, plus a managed baseline."""

obj Buffer {
    has n: int = 0;
}

def attr_reader(b: &Buffer) -> int {
    return b.n;
}

def attr_writer(m: &mut Buffer) {
    m.n = 5;
}

def attr_taker(o: own Buffer) -> int {
    return o.n;
}

def attr_viewer(d: imm Buffer) -> int {
    return d.n;
}

def attr_plain(p: Buffer) -> int {
    return p.n;
}

with entry {
    a: own Buffer = Buffer();
    r = attr_reader(&a);
    attr_writer(&mut a);
    b: own Buffer = Buffer();
    t = attr_taker(b);
    c: imm Buffer = Buffer();
    v = attr_viewer(c);
    p = Buffer();
    w = attr_plain(p);
    print(r + t + v + w);
}
