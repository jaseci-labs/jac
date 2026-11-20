obj Buffer { has n: int = 0; }

with entry {
    v: &Buffer;
    if len("x") > 0 {
        a: own Buffer = Buffer();
        v = &a;
    }
}
