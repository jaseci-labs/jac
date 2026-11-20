"""writes through a frozen binding hit the existing imm rule (E1309)."""

obj Buffer {
    has n: int = 0;
}

with entry {
    a: own Buffer = Buffer(n=7);
    d: imm Buffer = imm a;
    d.n = 9;
    print(d.n);
}
