obj Buffer { has n: int = 0; }

obj Holder { has ref: Buffer = Buffer(); }

with entry {
    a: own Buffer = Buffer();
    h = Holder();
    h.ref = a;
    print(a);
}
