"""imm of an owned binding: consumed source, deep-immutable result."""

obj Buffer {
    has n: int = 0;
}

with entry {
    a: own Buffer = Buffer(n=7);
    d: imm Buffer = imm a;
    print(d.n);
}
