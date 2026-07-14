obj Buffer { has n: int = 0; }

obj Holder { has ref: Buffer = Buffer(); }

with entry {
    a: own Buffer = Buffer();
    v: &Buffer = &a;
    h = Holder();
    h.ref = v;
}
