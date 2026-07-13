obj Buffer { has n: int = 0; }

with entry {
    a: own Buffer = Buffer();
    v: &Buffer = &a;
    slots: list = [Buffer()];
    slots[0] = v;
}
