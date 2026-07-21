obj Buffer { has n: int = 0; }

with entry {
    v: imm Buffer = Buffer();
    v.n = 5;
}
