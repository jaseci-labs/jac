"""imm of a possibly-aliased managed binding is fenced (E1311)."""

obj Buffer {
    has n: int = 0;
}

with entry {
    m = Buffer(n=7);
    alias = m;
    d: imm Buffer = imm m;
    print(d.n + alias.n);
}
